'use client';

import { useState, useRef } from 'react';
import { Timer, Eye } from 'lucide-react';
import type { Collocation } from '@/types/training';

interface Props {
  collocations: Collocation[];
  onComplete: () => void;
  completed: boolean;
  onMarkItems: (items: string[]) => void;
}

export function CollocationBurst({ collocations, onComplete, completed, onMarkItems }: Props) {
  const [revealed, setRevealed] = useState<Set<number>>(new Set());
  const [speedMode, setSpeedMode] = useState(false);
  const [current, setCurrent] = useState(0);
  const [marked, setMarked] = useState<Set<number>>(new Set());
  const timerRef = useRef<NodeJS.Timeout>();

  if (!collocations.length) {
    return (
      <div className="space-y-4 text-center">
        <p className="text-slate-500">该日暂无搭配数据。</p>
        <button onClick={onComplete} className="rounded-lg bg-primary-600 px-4 py-2 text-white">
          跳过此步
        </button>
      </div>
    );
  }

  function reveal(i: number) {
    const next = new Set(revealed);
    next.add(i);
    setRevealed(next);
  }

  function markSlow(i: number) {
    const next = new Set(marked);
    next.add(i);
    setMarked(next);
    onMarkItems(
      Array.from(next).map((idx) => collocations[idx]?.chinese || '')
    );
  }

  function startSpeedMode() {
    setSpeedMode(true);
    setCurrent(0);
    const revealedAll = new Set<number>();
    collocations.forEach((_, i) => revealedAll.add(i));
    setRevealed(revealedAll);

    // Auto-advance every 3 seconds
    timerRef.current = setInterval(() => {
      setCurrent((c) => {
        if (c >= collocations.length - 1) {
          clearInterval(timerRef.current);
          setSpeedMode(false);
          return c;
        }
        return c + 1;
      });
    }, 3000);
  }

  function stopSpeedMode() {
    if (timerRef.current) clearInterval(timerRef.current);
    setSpeedMode(false);
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-lg">搭配爆破</h2>
        <span className="text-sm text-slate-500">
          已揭晓 {revealed.size} / {collocations.length}
        </span>
      </div>

      {/* Speed mode toggle */}
      <div className="flex gap-2">
        {!speedMode ? (
          <button
            onClick={startSpeedMode}
            className="flex items-center gap-1.5 rounded-lg bg-amber-100 px-4 py-2 text-sm font-medium text-amber-700 hover:bg-amber-200 dark:bg-amber-900/30 dark:text-amber-400"
          >
            <Timer className="h-4 w-4" />
            3 秒速测模式
          </button>
        ) : (
          <button
            onClick={stopSpeedMode}
            className="flex items-center gap-1.5 rounded-lg bg-red-100 px-4 py-2 text-sm font-medium text-red-700 dark:bg-red-900/30 dark:text-red-400"
          >
            停止速测
          </button>
        )}
      </div>

      {/* Speed mode display */}
      {speedMode && collocations[current] && (
        <div className="rounded-xl border-2 border-amber-300 bg-amber-50 p-8 text-center dark:border-amber-700 dark:bg-amber-900/20">
          <div className="text-3xl font-bold text-slate-800 dark:text-slate-200">
            {collocations[current].chinese}
          </div>
          <div className="mt-2 text-lg text-amber-600 dark:text-amber-400">
            {collocations[current].english}
          </div>
          <div className="mt-4 text-sm text-slate-400">
            {current + 1} / {collocations.length} · 3 秒自动切换
          </div>
        </div>
      )}

      {/* Full list */}
      {!speedMode && (
        <div className="space-y-1.5">
          {collocations.map((c, i) => (
            <div
              key={i}
              className="flex items-center gap-3 rounded-lg border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-800"
            >
              <span className="w-6 text-xs text-slate-400">{i + 1}.</span>
              <span className="flex-1 font-medium">{c.chinese}</span>
              <div className="flex items-center gap-1">
                {revealed.has(i) ? (
                  <span className="text-sm text-primary-600 dark:text-primary-400">{c.english}</span>
                ) : (
                  <button
                    onClick={() => reveal(i)}
                    className="flex items-center gap-1 rounded px-2 py-1 text-xs text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-700"
                  >
                    <Eye className="h-3 w-3" />
                    显示
                  </button>
                )}
                {revealed.has(i) && !marked.has(i) && (
                  <button
                    onClick={() => markSlow(i)}
                    className="rounded px-1.5 py-0.5 text-xs text-red-500 hover:bg-red-50"
                    title="3秒内没说出来"
                  >
                    卡住了
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Complete button */}
      <div className="flex justify-center">
        <button
          onClick={onComplete}
          disabled={completed}
          className="rounded-lg bg-primary-600 px-6 py-2 text-white hover:bg-primary-700 disabled:opacity-50"
        >
          {completed ? '已完成' : '全部练完，进入下一步'}
        </button>
      </div>
    </div>
  );
}
