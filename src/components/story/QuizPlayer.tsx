'use client';

import { useState } from 'react';
import type { QuizQuestion } from '@/types/story';
import { Check, X, Trophy } from 'lucide-react';

interface Props {
  quiz: QuizQuestion[];
  onComplete: () => void;
  completed: boolean;
}

export function QuizPlayer({ quiz, onComplete, completed }: Props) {
  const [current, setCurrent] = useState(0);
  const [answers, setAnswers] = useState<Record<number, number>>({});
  const [submitted, setSubmitted] = useState(false);
  const [showResults, setShowResults] = useState(false);

  if (!quiz.length) {
    return <p className="text-slate-500 text-center py-8">暂无测试题。</p>;
  }

  function selectAnswer(qIndex: number, aIndex: number) {
    if (submitted) return;
    setAnswers((a) => ({ ...a, [qIndex]: aIndex }));
  }

  function handleSubmit() {
    setSubmitted(true);
    setShowResults(true);
  }

  const score = quiz.filter((q, i) => answers[i] === q.correctIndex).length;
  const typeLabels: Record<string, string> = { comprehension: '阅读理解', vocabulary: '词汇', 'fill-blank': '填空' };

  if (showResults) {
    return (
      <div className="space-y-4">
        <div className="rounded-xl bg-green-50 p-6 text-center dark:bg-green-900/20">
          <Trophy className="mx-auto h-12 w-12 text-green-500" />
          <div className="mt-2 text-3xl font-bold text-green-700 dark:text-green-300">
            {score} / {quiz.length}
          </div>
          <p className="text-sm text-green-600 dark:text-green-400">
            {score === quiz.length ? '全部正确！' : score >= quiz.length * 0.6 ? '不错！继续加油' : '多读几遍故事再来试试'}
          </p>
        </div>

        {/* Review answers */}
        <div className="space-y-3">
          {quiz.map((q, i) => {
            const isCorrect = answers[i] === q.correctIndex;
            return (
              <div key={i} className={`rounded-lg border p-4 ${isCorrect ? 'border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20' : 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-900/20'}`}>
                <div className="flex items-start gap-2">
                  {isCorrect ? <Check className="mt-0.5 h-4 w-4 text-green-600" /> : <X className="mt-0.5 h-4 w-4 text-red-600" />}
                  <div>
                    <div className="text-xs text-slate-400">{typeLabels[q.type]}</div>
                    <div className="font-medium text-sm">{q.question}</div>
                    {!isCorrect && (
                      <div className="mt-1 text-xs text-red-600 dark:text-red-400">
                        正确答案：{q.options[q.correctIndex]}
                      </div>
                    )}
                    {q.explanation && (
                      <div className="mt-1 text-xs text-slate-500">{q.explanation}</div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        <button onClick={onComplete} disabled={completed} className="w-full rounded-lg bg-primary-600 py-3 text-white hover:bg-primary-700 disabled:opacity-50">
          {completed ? '已完成' : '完成测试'}
        </button>
      </div>
    );
  }

  const q = quiz[current];

  return (
    <div className="space-y-4">
      <div className="text-center text-sm text-slate-400">{current + 1} / {quiz.length}</div>

      <div className="rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        <div className="mb-1 text-xs font-medium text-primary-600">{typeLabels[q.type]}</div>
        <div className="text-lg font-medium">{q.question}</div>
      </div>

      <div className="space-y-2">
        {q.options.map((opt, i) => (
          <button
            key={i}
            onClick={() => selectAnswer(current, i)}
            className={`w-full rounded-lg border px-4 py-3 text-left text-sm transition-colors ${
              answers[current] === i
                ? 'border-primary-500 bg-primary-50 text-primary-700 dark:bg-primary-900/30 dark:text-primary-300'
                : 'border-slate-200 hover:border-slate-300 dark:border-slate-700'
            }`}
          >
            <span className="mr-2 font-medium">{String.fromCharCode(65 + i)}.</span>
            {opt}
          </button>
        ))}
      </div>

      <div className="flex justify-between">
        <button onClick={() => setCurrent(Math.max(0, current - 1))} disabled={current === 0} className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-30 dark:border-slate-600">
          上一题
        </button>
        {current < quiz.length - 1 ? (
          <button onClick={() => setCurrent(current + 1)} className="rounded-lg bg-primary-600 px-4 py-1.5 text-sm text-white">下一题</button>
        ) : (
          <button onClick={handleSubmit} disabled={Object.keys(answers).length < quiz.length} className="rounded-lg bg-green-600 px-6 py-1.5 text-sm text-white disabled:opacity-50">
            提交
          </button>
        )}
      </div>
    </div>
  );
}
