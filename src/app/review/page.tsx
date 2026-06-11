'use client';

import { useState, useEffect } from 'react';
import { useReviewStore } from '@/stores/reviewStore';
import { SpeakButton } from '@/components/speech/SpeakButton';
import type { ReviewItem } from '@/stores/reviewStore';
import { Brain, CheckCircle, RefreshCw, BookOpen, ChevronLeft, ChevronRight } from 'lucide-react';

export default function ReviewPage() {
  const { items, markReviewed, toggleMastered, getStats } = useReviewStore();
  const [filter, setFilter] = useState<'all' | 'vocabulary' | 'pattern' | 'due'>('due');
  const [current, setCurrent] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const stats = getStats();

  const filtered = (() => {
    if (filter === 'vocabulary') return items.filter((i) => i.type === 'vocabulary');
    if (filter === 'pattern') return items.filter((i) => i.type === 'pattern');
    if (filter === 'due') {
      const now = Date.now();
      return items.filter((i) => {
        if (i.mastered) return false;
        if (!i.lastReviewed) return true;
        return (now - i.lastReviewed) / 3600000 > 24 || i.reviewCount < 3;
      });
    }
    return items;
  })();

  const currentItem = filtered[current];

  function handleReviewed() {
    if (currentItem) {
      markReviewed(currentItem.id);
      setShowAnswer(false);
      if (current < filtered.length - 1) setCurrent(current + 1);
    }
  }

  function handleMastered() {
    if (currentItem) {
      toggleMastered(currentItem.id);
      markReviewed(currentItem.id);
      setShowAnswer(false);
      if (current < filtered.length - 1) setCurrent(current + 1);
    }
  }

  const typeLabel = (type: string) =>
    type === 'vocabulary' ? '词汇' : '句型';

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">复习</h1>

      {/* Stats bar */}
      <div className="grid grid-cols-3 gap-3">
        <div className="rounded-xl border border-slate-200 bg-white p-3 text-center dark:border-slate-700 dark:bg-slate-800">
          <div className="text-xl font-bold text-primary-600">{stats.total}</div>
          <div className="text-xs text-slate-400">总计</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-3 text-center dark:border-slate-700 dark:bg-slate-800">
          <div className="text-xl font-bold text-green-600">{stats.mastered}</div>
          <div className="text-xs text-slate-400">已掌握</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-3 text-center dark:border-slate-700 dark:bg-slate-800">
          <div className="text-xl font-bold text-amber-600">{stats.reviewedToday}</div>
          <div className="text-xs text-slate-400">今日复习</div>
        </div>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1 rounded-lg bg-slate-100 p-1 dark:bg-slate-800">
        {[
          { key: 'due' as const, label: '待复习' },
          { key: 'vocabulary' as const, label: '词汇' },
          { key: 'pattern' as const, label: '句型' },
          { key: 'all' as const, label: '全部' },
        ].map((f) => (
          <button
            key={f.key}
            onClick={() => { setFilter(f.key); setCurrent(0); setShowAnswer(false); }}
            className={`flex-1 rounded-md py-1.5 text-xs font-medium transition-colors ${
              filter === f.key ? 'bg-white text-primary-600 shadow-sm dark:bg-slate-700 dark:text-primary-400' : 'text-slate-500'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <div className="py-16 text-center">
          <Brain className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600" />
          <p className="mt-4 text-slate-500">暂无复习内容</p>
          <p className="text-sm text-slate-400">完成故事学习后，练习过的词汇和句型会自动加入复习</p>
        </div>
      ) : (
        <>
          {/* Progress */}
          <div className="text-center text-sm text-slate-400">
            {current + 1} / {filtered.length}
          </div>

          {/* Flashcard */}
          <div
            className="cursor-pointer rounded-xl border-2 border-primary-200 bg-primary-50 p-6 min-h-[200px] dark:border-primary-800 dark:bg-primary-900/20"
            onClick={() => setShowAnswer(!showAnswer)}
          >
            <div className="mb-2 text-xs font-medium text-primary-600 dark:text-primary-400">
              {typeLabel(currentItem.type)} · {currentItem.storyTitle}
            </div>
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl font-bold">{currentItem.content}</span>
              <SpeakButton text={currentItem.content.replace(/\(.*?\)/g, '').trim()} className="h-5 w-5" />
            </div>

            {showAnswer && (
              <div className="mt-4 space-y-3 border-t border-primary-200 pt-4 dark:border-primary-700">
                <div>
                  <div className="text-xs text-slate-400">释义</div>
                  <div className="text-sm">{currentItem.definition}</div>
                </div>
                {currentItem.exampleSentence && (
                  <div>
                    <div className="text-xs text-slate-400">例句</div>
                    <div className="flex items-start gap-1">
                      <span className="text-sm italic">"{currentItem.exampleSentence}"</span>
                      <SpeakButton text={currentItem.exampleSentence} />
                    </div>
                  </div>
                )}
                <div className="flex gap-2 text-xs text-slate-400">
                  <span>复习 {currentItem.reviewCount} 次</span>
                  {currentItem.mastered && <span className="text-green-600">· 已掌握</span>}
                </div>
              </div>
            )}
          </div>

          <p className="text-center text-xs text-slate-400">点击卡片翻转查看释义</p>

          {/* Actions */}
          <div className="flex justify-center gap-3">
            <button onClick={() => { setCurrent(Math.max(0, current - 1)); setShowAnswer(false); }} disabled={current === 0}
              className="flex items-center gap-1 rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-30 dark:border-slate-600">
              <ChevronLeft className="h-4 w-4" />上一个
            </button>
            <button onClick={handleReviewed}
              className="flex items-center gap-1 rounded-lg bg-amber-100 px-4 py-2 text-sm font-medium text-amber-700 hover:bg-amber-200 dark:bg-amber-900/30 dark:text-amber-400">
              <RefreshCw className="h-4 w-4" />复习过了
            </button>
            <button onClick={handleMastered}
              className="flex items-center gap-1 rounded-lg bg-green-100 px-4 py-2 text-sm font-medium text-green-700 hover:bg-green-200 dark:bg-green-900/30 dark:text-green-400">
              <CheckCircle className="h-4 w-4" />已掌握
            </button>
            <button onClick={() => { setCurrent(Math.min(filtered.length - 1, current + 1)); setShowAnswer(false); }} disabled={current >= filtered.length - 1}
              className="flex items-center gap-1 rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-30 dark:border-slate-600">
              下一个<ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </>
      )}
    </div>
  );
}
