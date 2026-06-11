'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useStoryStore } from '@/stores/storyStore';
import { useProgressStore } from '@/stores/progressStore';
import { getStory, saveStoryProgress } from '@/lib/storage/db';
import { StoryReader } from '@/components/story/StoryReader';
import { VocabTrainer } from '@/components/story/VocabTrainer';
import { PatternTrainer } from '@/components/story/PatternTrainer';
import { RetellRecorder } from '@/components/story/RetellRecorder';
import { QuizPlayer } from '@/components/story/QuizPlayer';
import type { Story } from '@/types/story';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const STEP_LABELS = ['文章跟读', '单词造句', '句型语法', '关键词复述', '测试'];

export function StorySession() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const storyId = searchParams.get('id') || '';

  const { currentStep, setCurrentStep, updateProgress, setCurrentStory } = useStoryStore();
  const { completeSession } = useProgressStore();
  const [story, setStory] = useState<Story | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [completedSteps, setCompletedSteps] = useState<boolean[]>([false, false, false, false, false]);

  useEffect(() => {
    if (!storyId) { router.push('/'); return; }
    loadStory();
  }, [storyId]);

  async function loadStory() {
    setLoading(true);
    try {
      const s = await getStory(storyId);
      if (s) { setStory(s); setCurrentStory(s); }
      else setError('故事未找到');
    } catch { setError('加载失败'); }
    setLoading(false);
  }

  function handleStepComplete(stepIndex: number) {
    const updated = [...completedSteps];
    updated[stepIndex] = true;
    setCompletedSteps(updated);
    if (story) {
      updateProgress(story.id, { completedSteps: updated });
      if (updated.every(Boolean)) {
        const today = new Date().toISOString().split('T')[0];
        completeSession(today, 20, ['story', story.title]);
        saveStoryProgress(story.id, { storyId: story.id, completedSteps: updated, completedAt: Date.now() });
      }
    }
  }

  if (loading) return <div className="flex items-center justify-center py-20"><div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" /></div>;
  if (error || !story) return <div className="space-y-4 py-12 text-center"><p className="text-slate-500">{error || '故事未找到'}</p><button onClick={() => router.push('/')} className="rounded-lg bg-primary-600 px-4 py-2 text-white">返回首页</button></div>;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-1">
        <button onClick={() => router.push('/')} className="mr-2 rounded p-1 text-slate-400 hover:text-slate-600"><ChevronLeft className="h-5 w-5" /></button>
        <div className="flex flex-1 gap-1">
          {STEP_LABELS.map((_, i) => (
            <button key={i} onClick={() => setCurrentStep(i)}
              className={`flex-1 rounded-full py-1 text-xs font-medium transition-colors ${i === currentStep ? 'bg-primary-600 text-white' : completedSteps[i] ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-slate-100 text-slate-400 dark:bg-slate-800'}`}>{i + 1}</button>
          ))}
        </div>
      </div>
      <h2 className="text-sm font-medium text-slate-500">{STEP_LABELS[currentStep]}</h2>

      {currentStep === 0 && <StoryReader content={story.content} title={story.title} onComplete={() => handleStepComplete(0)} completed={completedSteps[0]} />}
      {currentStep === 1 && <VocabTrainer vocabulary={story.vocabulary} storyId={story.id} onComplete={() => handleStepComplete(1)} completed={completedSteps[1]} />}
      {currentStep === 2 && <PatternTrainer patterns={story.patterns} storyId={story.id} onComplete={() => handleStepComplete(2)} completed={completedSteps[2]} />}
      {currentStep === 3 && <RetellRecorder keywords={story.keywords} originalStory={story.content} onComplete={() => handleStepComplete(3)} completed={completedSteps[3]} />}
      {currentStep === 4 && <QuizPlayer quiz={story.quiz} onComplete={() => handleStepComplete(4)} completed={completedSteps[4]} />}

      <div className="flex justify-between pt-2">
        <button onClick={() => setCurrentStep(Math.max(0, currentStep - 1))} disabled={currentStep === 0} className="flex items-center gap-1 rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-30 dark:border-slate-600"><ChevronLeft className="h-4 w-4" />上一步</button>
        {currentStep < 4 && <button onClick={() => setCurrentStep(currentStep + 1)} className="flex items-center gap-1 rounded-lg bg-primary-600 px-4 py-2 text-sm text-white">下一步<ChevronRight className="h-4 w-4" /></button>}
        {currentStep === 4 && completedSteps[4] && <button onClick={() => router.push('/')} className="flex items-center gap-1 rounded-lg bg-green-600 px-4 py-2 text-sm text-white">完成，返回首页</button>}
      </div>
    </div>
  );
}
