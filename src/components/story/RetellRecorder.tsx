'use client';

import { useState, useRef } from 'react';
import { useSettingsStore } from '@/stores/settingsStore';
import { RETELL_EVAL_PROMPT } from '@/lib/ai/prompts';
import { getFeedbackDirect } from '@/lib/ai/direct';
import { startAudioRecording } from '@/lib/speech/recognition';
import { saveAudio } from '@/lib/storage/db';
import type { AIConfig } from '@/lib/ai/direct';
import { Mic, Square, Play, Pause, Sparkles, RefreshCw } from 'lucide-react';

interface Props {
  keywords: string[];
  originalStory: string;
  onComplete: () => void;
  completed: boolean;
}

export function RetellRecorder({ keywords, originalStory, onComplete, completed }: Props) {
  const [phase, setPhase] = useState<'ready' | 'recording' | 'done'>('ready');
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [feedback, setFeedback] = useState<string>('');
  const [evaluating, setEvaluating] = useState(false);

  const recorderRef = useRef<{ stop: () => Promise<Blob>; stream: MediaStream } | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const timerRef = useRef<NodeJS.Timeout>();

  const { provider, getActiveApiKey, getActiveBaseUrl, getActiveModel } = useSettingsStore();

  async function startRecording() {
    try {
      const recorder = await startAudioRecording();
      recorderRef.current = recorder;
      setPhase('recording');
      setRecordingSeconds(0);
      timerRef.current = setInterval(() => setRecordingSeconds((s) => s + 1), 1000);
    } catch {
      alert('无法访问麦克风');
    }
  }

  async function stopRecording() {
    clearInterval(timerRef.current);
    if (!recorderRef.current) return;
    const blob = await recorderRef.current.stop();
    const url = URL.createObjectURL(blob);
    setAudioUrl(url);
    setPhase('done');

    const today = new Date().toISOString().split('T')[0];
    await saveAudio(`retell-${today}`, blob);
  }

  async function evaluate() {
    const apiKey = getActiveApiKey();
    if (!apiKey) {
      setFeedback('请先在设置中配置 API Key');
      return;
    }
    setEvaluating(true);
    try {
      const config: AIConfig = { provider, apiKey, baseUrl: getActiveBaseUrl(), model: getActiveModel() };
      const prompt = `Original story:\n"${originalStory}"\n\nKeywords used as prompts:\n${keywords.join(', ')}\n\nThe student recorded an oral retelling. (Audio recording ID exists but text transcription would need STT.) Evaluate based on the available information. Ask the student to self-assess: did they cover the main points? Use the original story to give specific feedback on what they might have missed.`;
      const result = await getFeedbackDirect(RETELL_EVAL_PROMPT, prompt, config);
      const match = result.match(/\{[\s\S]*\}/);
      if (match) {
        const data = JSON.parse(match[0]);
        setFeedback(data.feedback || result);
      } else {
        setFeedback(result);
      }
    } catch {
      setFeedback('评估失败，请重试');
    }
    setEvaluating(false);
  }

  function togglePlayback() {
    if (!audioRef.current || !audioUrl) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play();
      setIsPlaying(true);
      audioRef.current.onended = () => setIsPlaying(false);
    }
  }

  function retry() {
    setAudioUrl(null);
    setFeedback('');
    setPhase('ready');
  }

  return (
    <div className="space-y-4">
      {/* Keywords */}
      <div>
        <h3 className="mb-2 text-sm font-medium">关键词提示</h3>
        <div className="flex flex-wrap gap-2">
          {keywords.map((kw, i) => (
            <span key={i} className="rounded-full bg-amber-100 px-3 py-1 text-sm font-medium text-amber-700 dark:bg-amber-900/30 dark:text-amber-300">
              {kw}
            </span>
          ))}
        </div>
        <p className="mt-2 text-xs text-slate-400">看着这些关键词，用英文复述故事内容</p>
      </div>

      {/* Recording UI */}
      {phase === 'ready' && (
        <button onClick={startRecording} className="flex w-full items-center justify-center gap-2 rounded-xl bg-red-500 py-4 text-white shadow">
          <Mic className="h-5 w-5" />开始录音复述
        </button>
      )}

      {phase === 'recording' && (
        <div className="text-center space-y-3">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-red-100">
            <div className="h-8 w-8 animate-pulse rounded-full bg-red-500" />
          </div>
          <div className="text-2xl font-bold tabular-nums text-red-600">
            {Math.floor(recordingSeconds / 60)}:{(recordingSeconds % 60).toString().padStart(2, '0')}
          </div>
          <button onClick={stopRecording} className="rounded-lg bg-slate-800 px-4 py-2 text-sm text-white dark:bg-white dark:text-slate-800">
            <Square className="mr-1 inline h-4 w-4" />停止录音
          </button>
        </div>
      )}

      {phase === 'done' && audioUrl && (
        <div className="space-y-3">
          <audio ref={audioRef} src={audioUrl} className="hidden" />
          <div className="flex items-center justify-center gap-3">
            <button onClick={togglePlayback} className="flex h-10 w-10 items-center justify-center rounded-full bg-primary-600 text-white">
              {isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4 ml-0.5" />}
            </button>
            <span className="text-sm text-slate-500">{isPlaying ? '播放中...' : '点击回听'}</span>
            <button onClick={retry} className="flex items-center gap-1 rounded-lg border border-slate-300 px-2 py-1 text-xs dark:border-slate-600">
              <RefreshCw className="h-3 w-3" />重录
            </button>
          </div>

          <button onClick={evaluate} disabled={evaluating} className="flex w-full items-center justify-center gap-2 rounded-lg bg-amber-100 py-2 text-sm font-medium text-amber-700 hover:bg-amber-200 disabled:opacity-50 dark:bg-amber-900/30 dark:text-amber-400">
            <Sparkles className="h-4 w-4" />
            {evaluating ? 'AI 评估中...' : 'AI 评估复述'}
          </button>
        </div>
      )}

      {feedback && (
        <div className="rounded-xl bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-900/20 dark:text-blue-300">
          <strong>AI 反馈：</strong>
          <p className="mt-1">{feedback}</p>
        </div>
      )}

      <button onClick={onComplete} disabled={completed} className="w-full rounded-lg bg-primary-600 py-3 text-white hover:bg-primary-700 disabled:opacity-50">
        {completed ? '已完成' : '完成复述'}
      </button>
    </div>
  );
}
