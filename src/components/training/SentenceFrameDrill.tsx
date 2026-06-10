'use client';

import { useState } from 'react';
import { Volume2, CheckCircle } from 'lucide-react';
import type { SentenceFrame } from '@/types/training';

interface Props {
  frames: SentenceFrame[];
  onComplete: () => void;
  completed: boolean;
}

export function SentenceFrameDrill({ frames, onComplete, completed }: Props) {
  const [currentFrame, setCurrentFrame] = useState(0);
  const [practiced, setPracticed] = useState<Set<number>>(new Set());

  if (!frames.length) {
    return (
      <div className="space-y-4 text-center">
        <p className="text-slate-500">该日暂无句型框架数据。</p>
        <button onClick={onComplete} className="rounded-lg bg-primary-600 px-4 py-2 text-white">
          跳过此步
        </button>
      </div>
    );
  }

  const frame = frames[currentFrame];

  function markPracticed() {
    const next = new Set(practiced);
    next.add(currentFrame);
    setPracticed(next);
    if (next.size >= frames.length && !completed) {
      onComplete();
    }
  }

  function speak(text: string) {
    if ('speechSynthesis' in window) {
      const u = new SpeechSynthesisUtterance(text);
      u.lang = 'en-US';
      u.rate = 0.85;
      speechSynthesis.speak(u);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-lg">句型框架</h2>
        <span className="text-sm text-slate-500">
          {practiced.size} / {frames.length} 个句型已练
        </span>
      </div>

      {/* Frame card */}
      <div className="rounded-xl border-2 border-primary-200 bg-primary-50 p-6 dark:border-primary-800 dark:bg-primary-900/20">
        <div className="mb-1 text-xs font-medium text-primary-600 dark:text-primary-400 uppercase">
          句型 {currentFrame + 1}
        </div>
        <div className="mb-2 text-2xl font-bold text-primary-900 dark:text-primary-100">
          {frame.pattern}
        </div>
        {frame.usage && (
          <p className="mb-1 text-sm text-primary-700 dark:text-primary-300">
            <span className="font-medium">用在哪：</span>{frame.usage}
          </p>
        )}
        {frame.example && (
          <div className="flex items-center gap-2">
            <p className="text-sm italic text-primary-600 dark:text-primary-400">
              "{frame.example}"
            </p>
            <button
              onClick={() => speak(frame.example)}
              className="rounded p-1 text-primary-500 hover:bg-primary-200 dark:hover:bg-primary-800"
            >
              <Volume2 className="h-3.5 w-3.5" />
            </button>
          </div>
        )}
      </div>

      {/* Substitution drill */}
      <div>
        <h3 className="mb-3 font-medium text-sm text-slate-600 dark:text-slate-400">
          替换练习 — 把划线部分换掉，每个变体<strong>大声说 3 遍</strong>
        </h3>
        <div className="space-y-2">
          {frame.substitutions.map((sub, i) => (
            <div
              key={i}
              className="flex items-center gap-3 rounded-lg border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-800"
            >
              <span className="text-xs font-medium text-slate-400">{i + 1}.</span>
              <span className="flex-1">{sub}</span>
              <button
                onClick={() => speak(sub)}
                className="rounded p-1.5 text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700"
              >
                <Volume2 className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Navigation */}
      <div className="flex items-center justify-between">
        <button
          onClick={() => setCurrentFrame(Math.max(0, currentFrame - 1))}
          disabled={currentFrame === 0}
          className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600"
        >
          上一个
        </button>

        <div className="flex gap-2">
          <button
            onClick={markPracticed}
            className="flex items-center gap-1 rounded-lg bg-green-600 px-4 py-1.5 text-sm text-white hover:bg-green-700"
          >
            <CheckCircle className="h-4 w-4" />
            已练习
          </button>
        </div>

        <button
          onClick={() => setCurrentFrame(Math.min(frames.length - 1, currentFrame + 1))}
          disabled={currentFrame >= frames.length - 1}
          className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600"
        >
          下一个
        </button>
      </div>

      {completed && (
        <div className="rounded-lg bg-green-50 p-3 text-center text-sm text-green-700 dark:bg-green-900/20 dark:text-green-400">
          本步骤已完成。你可以继续练习或进入下一步。
        </div>
      )}
    </div>
  );
}
