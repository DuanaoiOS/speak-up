'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useTrainingStore } from '@/stores/trainingStore';
import { useProgressStore } from '@/stores/progressStore';
import { SentenceFrameDrill } from '@/components/training/SentenceFrameDrill';
import { CollocationBurst } from '@/components/training/CollocationBurst';
import { ShadowingPractice } from '@/components/training/ShadowingPractice';
import { ImpromptuSpeaking } from '@/components/training/ImpromptuSpeaking';
import { ReviewReflection } from '@/components/training/ReviewReflection';
import { StepNavigation } from '@/components/training/StepNavigation';
import { getTrainingContent, saveTrainingContent, saveSession } from '@/lib/storage/db';
import type { TrainingStep, TrainingContent, SentenceFrame, Collocation } from '@/types/training';

interface ParsedContent {
  sentenceFrames: SentenceFrame[];
  collocations: Collocation[];
  shadowingTopic: string;
  impromptuTopic: string;
  impromptuCueWords: string[];
  week: number;
  day: number;
  title: string;
}

const STEP_LABELS: Record<TrainingStep, string> = {
  sentence_frames: '句型框架',
  collocations: '搭配爆破',
  shadowing: '影子跟读',
  impromptu: '即兴表达',
  review: '复盘',
};

export default function TrainingSessionPage() {
  const params = useParams();
  const router = useRouter();
  const dayId = params.dayId as string;
  const [week, day] = dayId.split('-').map(Number);

  const { currentStep, stepStates, setStep, updateStepState, completeStep } = useTrainingStore();
  const { completeSession } = useProgressStore();
  const [content, setContent] = useState<ParsedContent | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [timer, setTimer] = useState(0);
  const [timerActive, setTimerActive] = useState(false);
  const [totalMinutes, setTotalMinutes] = useState(0);

  useEffect(() => {
    loadContent();
  }, [week, day]);

  // Timer
  useEffect(() => {
    if (!timerActive) return;
    const interval = setInterval(() => {
      setTimer((t) => t + 1);
    }, 1000);
    return () => clearInterval(interval);
  }, [timerActive]);

  async function loadContent() {
    setLoading(true);
    setError('');

    try {
      // Try IndexedDB first
      const cached = await getTrainingContent(week, day);
      if (cached) {
        setContent(transformContent(cached, week, day));
        setLoading(false);
        return;
      }

      // Try API (static content)
      const resp = await fetch(`/api/content?week=${week}&day=${day}`);
      if (resp.ok) {
        const data = await resp.json();
        const tc: TrainingContent = {
          sentenceFrames: data.sentenceFrames || [],
          collocations: data.collocations || [],
          shadowing: { youtubeSearchQuery: data.shadowingTopic || '', instructions: '', focusPhrases: [] },
          impromptu: { topic: data.impromptuTopic || '', cueWords: data.impromptuCueWords || [], sentenceFrameHints: [] },
        };
        await saveTrainingContent(week, day, tc);
        setContent(transformContent(tc, week, day));
        setLoading(false);
        return;
      }

      // For week 5+, no static content - need AI generation
      if (week >= 5) {
        setError('AI 生成内容需要配置 API Key。请在设置中配置后重试。');
      } else {
        setError('内容加载失败');
      }
    } catch {
      setError('加载失败，请检查网络连接');
    }
    setLoading(false);
  }

  function transformContent(tc: TrainingContent, week: number, day: number): ParsedContent {
    return {
      sentenceFrames: tc.sentenceFrames || [],
      collocations: tc.collocations || [],
      shadowingTopic: tc.shadowing?.youtubeSearchQuery || '',
      impromptuTopic: tc.impromptu?.topic || '',
      impromptuCueWords: tc.impromptu?.cueWords || [],
      week,
      day,
      title: '',
    };
  }

  async function handleCompleteStep() {
    completeStep(currentStep);
    const allSteps: TrainingStep[] = ['sentence_frames', 'collocations', 'shadowing', 'impromptu', 'review'];
    const allComplete = allSteps.every((s) => stepStates[s]?.completed || s === currentStep);

    if (allComplete && currentStep === 'review') {
      setTimerActive(false);
      const mins = Math.round(timer / 60);
      const today = new Date().toISOString().split('T')[0];
      const topics = [content?.title || '', `week-${week}`];

      await saveSession(today, {
        date: today,
        week,
        day,
        stepsCompleted: allSteps.map((s) => true),
        struggleNotes: stepStates.review?.struggleNotes || '',
        minutesSpent: mins,
      });

      completeSession(today, mins, topics);
      setTotalMinutes(mins);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-4 py-12 text-center">
        <p className="text-slate-500">{error}</p>
        <button
          onClick={loadContent}
          className="rounded-lg bg-primary-600 px-4 py-2 text-white hover:bg-primary-700"
        >
          重试
        </button>
        <button
          onClick={() => router.push('/train')}
          className="ml-2 rounded-lg border border-slate-300 px-4 py-2 dark:border-slate-600"
        >
          返回列表
        </button>
      </div>
    );
  }

  if (stepStates.review?.completed) {
    return (
      <div className="space-y-6 py-12 text-center">
        <div className="text-4xl">🎉</div>
        <h2 className="text-2xl font-bold">训练完成！</h2>
        <p className="text-slate-500 dark:text-slate-400">
          完成了 Week {week} Day {day} 的训练，用时 {totalMinutes || Math.round(timer / 60)} 分钟。
        </p>
        <div className="flex justify-center gap-3">
          <button
            onClick={() => router.push('/train')}
            className="rounded-lg bg-primary-600 px-4 py-2 text-white hover:bg-primary-700"
          >
            继续训练
          </button>
          <button
            onClick={() => router.push('/')}
            className="rounded-lg border border-slate-300 px-4 py-2 dark:border-slate-600"
          >
            返回首页
          </button>
        </div>
      </div>
    );
  }

  const steps: TrainingStep[] = ['sentence_frames', 'collocations', 'shadowing', 'impromptu', 'review'];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold">
            Week {week} Day {day}: {content?.title}
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">
            {STEP_LABELS[currentStep]} · {Math.floor(timer / 60)}:{(timer % 60).toString().padStart(2, '0')}
          </p>
        </div>
        {!timerActive && timer === 0 && (
          <button
            onClick={() => setTimerActive(true)}
            className="rounded-lg bg-primary-600 px-4 py-2 text-sm font-medium text-white hover:bg-primary-700"
          >
            开始计时
          </button>
        )}
      </div>

      <StepNavigation
        steps={steps}
        currentStep={currentStep}
        stepStates={stepStates}
        onStepClick={(s) => setStep(s)}
        labels={STEP_LABELS}
      />

      <div className="min-h-[400px] rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        {currentStep === 'sentence_frames' && content && (
          <SentenceFrameDrill
            frames={content.sentenceFrames}
            onComplete={() => handleCompleteStep()}
            completed={stepStates.sentence_frames?.completed || false}
          />
        )}

        {currentStep === 'collocations' && content && (
          <CollocationBurst
            collocations={content.collocations}
            onComplete={() => handleCompleteStep()}
            completed={stepStates.collocations?.completed || false}
            onMarkItems={(items) => updateStepState('collocations', { markedItems: items })}
          />
        )}

        {currentStep === 'shadowing' && content && (
          <ShadowingPractice
            youtubeSearch={content.shadowingTopic}
            onComplete={() => handleCompleteStep()}
            completed={stepStates.shadowing?.completed || false}
          />
        )}

        {currentStep === 'impromptu' && content && (
          <ImpromptuSpeaking
            topic={content.impromptuTopic}
            cueWords={content.impromptuCueWords}
            onComplete={() => handleCompleteStep()}
            completed={stepStates.impromptu?.completed || false}
            onAudioSaved={(key) => updateStepState('impromptu', { audioBlobKey: key })}
          />
        )}

        {currentStep === 'review' && (
          <ReviewReflection
            onComplete={() => handleCompleteStep()}
            completed={stepStates.review?.completed || false}
            onSaveNotes={(notes) => updateStepState('review', { struggleNotes: notes })}
          />
        )}
      </div>
    </div>
  );
}
