'use client';

import { useState, useEffect } from 'react';
import { useSettingsStore } from '@/stores/settingsStore';
import { useStoryStore } from '@/stores/storyStore';
import { useReviewStore } from '@/stores/reviewStore';
import { PATTERN_EVAL_PROMPT } from '@/lib/ai/prompts';
import { getFeedbackDirect } from '@/lib/ai/direct';
import type { AIConfig } from '@/lib/ai/direct';
import type { SentencePattern } from '@/types/story';
import { ChevronLeft, ChevronRight, Sparkles, Lightbulb } from 'lucide-react';
import { SpeakButton } from '@/components/speech/SpeakButton';

interface Props {
  patterns: SentencePattern[];
  storyId: string;
  onComplete: () => void;
  completed: boolean;
}

export function PatternTrainer({ patterns, storyId, onComplete, completed }: Props) {
  const [current, setCurrent] = useState(0);
  const [sentences, setSentences] = useState<Record<number, string>>({});
  const [feedback, setFeedback] = useState<Record<number, string>>({});
  const [evaluating, setEvaluating] = useState(false);
  const [showExplanation, setShowExplanation] = useState(false);
  const [savedPatterns, setSavedPatterns] = useState<Set<number>>(new Set());
  const { provider, getActiveApiKey, getActiveBaseUrl, getActiveModel } = useSettingsStore();
  const addReviewItem = useReviewStore((s) => s.addItem);
  const storyTitle = useStoryStore((s) => s.currentStory?.title || '');

  useEffect(() => {
    if (!patterns[current] || savedPatterns.has(current)) return;
    const p = patterns[current];
    addReviewItem({
      type: 'pattern',
      content: p.pattern,
      definition: p.explanation,
      exampleSentence: p.fromStory,
      storyTitle: storyTitle,
      storyId: storyId,
    });
    setSavedPatterns((s) => new Set(s).add(current));
  }, [current, patterns, storyTitle, storyId]);

  if (!patterns.length) {
    return <p className="text-slate-500 text-center py-8">AI 暂未提取句型，跳至下一步。</p>;
  }

  const pattern = patterns[current];

  async function evaluate() {
    const userSentence = sentences[current]?.trim();
    if (!userSentence) return;
    const apiKey = getActiveApiKey();
    if (!apiKey) {
      setFeedback((f) => ({ ...f, [current]: '请先在设置中配置 API Key' }));
      return;
    }
    setEvaluating(true);
    try {
      const config: AIConfig = { provider, apiKey, baseUrl: getActiveBaseUrl(), model: getActiveModel() };
      const prompt = `Pattern: "${pattern.pattern}". Original story sentence: "${pattern.fromStory}". Student's sentence: "${userSentence}"`;
      const result = await getFeedbackDirect(PATTERN_EVAL_PROMPT, prompt, config);
      setFeedback((f) => ({ ...f, [current]: result || '很好！' }));
    } catch {
      setFeedback((f) => ({ ...f, [current]: '评估失败，请重试' }));
    }
    setEvaluating(false);
  }

  return (
    <div className="space-y-4">
      <div className="text-center text-sm text-slate-400">{current + 1} / {patterns.length}</div>

      {/* Pattern card */}
      <div className="rounded-xl border-2 border-purple-200 bg-purple-50 p-6 dark:border-purple-800 dark:bg-purple-900/20">
        <div className="mb-1 text-lg font-bold text-purple-700 dark:text-purple-300">{pattern.pattern}</div>
        <div className="mb-3 flex items-start gap-1 rounded-lg bg-white/60 p-3 text-sm italic dark:bg-slate-800/60">
          <span className="flex-1">"{pattern.fromStory}"</span>
          <SpeakButton text={pattern.fromStory} />
        </div>

        {!showExplanation ? (
          <button
            onClick={() => setShowExplanation(true)}
            className="flex items-center gap-1 text-sm text-purple-600 hover:text-purple-700 dark:text-purple-400"
          >
            <Lightbulb className="h-4 w-4" />查看详解
          </button>
        ) : (
          <div className="rounded-lg bg-white/60 p-3 text-sm text-purple-800 dark:bg-slate-800/60 dark:text-purple-300">
            {pattern.explanation}
          </div>
        )}

        {pattern.practicePrompts.length > 0 && (
          <div className="mt-3 space-y-1">
            <p className="text-xs font-medium text-purple-600 dark:text-purple-400">造句提示：</p>
            {pattern.practicePrompts.map((p, i) => (
              <p key={i} className="text-xs text-slate-500">· {p}</p>
            ))}
          </div>
        )}
      </div>

      {/* Practice */}
      <textarea
        value={sentences[current] || ''}
        onChange={(e) => setSentences((s) => ({ ...s, [current]: e.target.value }))}
        placeholder={`用 "${pattern.pattern}" 造一个句子...`}
        rows={2}
        className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm dark:border-slate-600 dark:bg-slate-800"
      />
      <div className="flex gap-2">
        <button
          onClick={evaluate}
          disabled={!sentences[current]?.trim() || evaluating}
          className="flex items-center gap-1 rounded-lg bg-amber-100 px-3 py-1.5 text-xs font-medium text-amber-700 hover:bg-amber-200 disabled:opacity-50 dark:bg-amber-900/30 dark:text-amber-400"
        >
          <Sparkles className="h-3.5 w-3.5" />
          {evaluating ? '评估中...' : 'AI 评估'}
        </button>
      </div>
      {feedback[current] && (
        <div className="rounded-lg bg-blue-50 p-3 text-sm text-blue-800 dark:bg-blue-900/20 dark:text-blue-300">
          {feedback[current]}
        </div>
      )}

      <div className="flex items-center justify-between">
        <button onClick={() => { setCurrent(Math.max(0, current - 1)); setShowExplanation(false); }} disabled={current === 0} className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600">
          <ChevronLeft className="h-4 w-4" />上一个
        </button>
        <button onClick={() => { setCurrent(Math.min(patterns.length - 1, current + 1)); setShowExplanation(false); }} disabled={current >= patterns.length - 1} className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600">
          下一个<ChevronRight className="h-4 w-4" />
        </button>
      </div>

      <button onClick={onComplete} disabled={completed} className="w-full rounded-lg bg-primary-600 py-3 text-white hover:bg-primary-700 disabled:opacity-50">
        {completed ? '已完成' : '完成句型练习'}
      </button>
    </div>
  );
}
