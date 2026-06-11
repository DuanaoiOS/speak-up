'use client';

import { useState, useEffect } from 'react';
import { useSettingsStore } from '@/stores/settingsStore';
import { useStoryStore } from '@/stores/storyStore';
import { useReviewStore } from '@/stores/reviewStore';
import { VOCAB_EVAL_PROMPT } from '@/lib/ai/prompts';
import { getFeedbackDirect } from '@/lib/ai/direct';
import type { AIConfig } from '@/lib/ai/direct';
import type { VocabWord } from '@/types/story';
import { ChevronLeft, ChevronRight, Sparkles } from 'lucide-react';
import { SpeakButton } from '@/components/speech/SpeakButton';

interface Props {
  vocabulary: VocabWord[];
  storyId: string;
  onComplete: () => void;
  completed: boolean;
}

export function VocabTrainer({ vocabulary, storyId, onComplete, completed }: Props) {
  const [current, setCurrent] = useState(0);
  const [sentences, setSentences] = useState<Record<number, string>>({});
  const [feedback, setFeedback] = useState<Record<number, string>>({});
  const [evaluating, setEvaluating] = useState(false);
  const [saved, setSaved] = useState<Set<number>>(new Set());
  const { provider, getActiveApiKey, getActiveBaseUrl, getActiveModel } = useSettingsStore();
  const addReviewItem = useReviewStore((s) => s.addItem);
  const storyTitle = useStoryStore((s) => s.currentStory?.title || '');

  // Auto-save each word to review store as user navigates to it
  useEffect(() => {
    if (!vocabulary[current] || saved.has(current)) return;
    const w = vocabulary[current];
    addReviewItem({
      type: 'vocabulary',
      content: w.word,
      definition: w.definition,
      exampleSentence: w.context,
      storyTitle: storyTitle,
      storyId: storyId,
    });
    setSaved((s) => new Set(s).add(current));
  }, [current, vocabulary, storyTitle, storyId]);

  if (!vocabulary.length) {
    return <p className="text-slate-500 text-center py-8">AI 暂未提取词汇，跳至下一步。</p>;
  }

  const word = vocabulary[current];

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
      const prompt = `The student is practicing: "${word.word}" (meaning: ${word.definition}). Original context: "${word.context}". Student's sentence: "${userSentence}"`;
      const result = await getFeedbackDirect(VOCAB_EVAL_PROMPT, prompt, config);
      setFeedback((f) => ({ ...f, [current]: result || '很好！' }));
    } catch {
      setFeedback((f) => ({ ...f, [current]: '评估失败，请重试' }));
    }
    setEvaluating(false);
  }

  const allDone = vocabulary.every((_, i) => sentences[i]?.trim());

  return (
    <div className="space-y-4">
      <div className="text-center text-sm text-slate-400">{current + 1} / {vocabulary.length}</div>

      {/* Word card */}
      <div className="rounded-xl border-2 border-primary-200 bg-primary-50 p-6 dark:border-primary-800 dark:bg-primary-900/20">
        <div className="mb-1 flex items-center gap-1 text-sm font-bold text-primary-700 dark:text-primary-300">
          <span>{word.word}</span>
          <SpeakButton text={word.word.replace(/\(.*?\)/g, '').trim()} />
        </div>
        <div className="mb-2 text-sm text-primary-600 dark:text-primary-400">{word.definition}</div>
        <div className="flex items-start gap-1 rounded-lg bg-white/60 p-3 text-sm italic dark:bg-slate-800/60">
          <span className="flex-1">"{word.context}"</span>
          <SpeakButton text={word.context} />
        </div>
        {word.exampleSentence && (
          <div className="mt-2 flex items-start gap-1 text-xs text-slate-500">
            <span className="flex-1">例句：{word.exampleSentence}</span>
            <SpeakButton text={word.exampleSentence} />
          </div>
        )}
      </div>

      {/* Sentence input */}
      <div>
        <label className="mb-1.5 block text-sm font-medium">用 <strong>{word.word}</strong> 造一个句子</label>
        <textarea
          value={sentences[current] || ''}
          onChange={(e) => setSentences((s) => ({ ...s, [current]: e.target.value }))}
          placeholder="输入你的句子..."
          rows={2}
          className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm dark:border-slate-600 dark:bg-slate-800"
        />
        <div className="mt-2 flex gap-2">
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
          <div className="mt-2 rounded-lg bg-blue-50 p-3 text-sm text-blue-800 dark:bg-blue-900/20 dark:text-blue-300">
            {feedback[current]}
          </div>
        )}
      </div>

      {/* Navigation */}
      <div className="flex items-center justify-between">
        <button
          onClick={() => setCurrent(Math.max(0, current - 1))}
          disabled={current === 0}
          className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600"
        >
          <ChevronLeft className="h-4 w-4" />上一个
        </button>
        <button
          onClick={() => setCurrent(Math.min(vocabulary.length - 1, current + 1))}
          disabled={current >= vocabulary.length - 1}
          className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600"
        >
          下一个<ChevronRight className="h-4 w-4" />
        </button>
      </div>

      <button
        onClick={onComplete}
        disabled={completed}
        className="w-full rounded-lg bg-primary-600 py-3 text-white hover:bg-primary-700 disabled:opacity-50"
      >
        {completed ? '已完成' : allDone ? '完成造句' : '跳过，完成此步'}
      </button>
    </div>
  );
}
