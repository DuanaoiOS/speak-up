'use client';

import { useState } from 'react';
import { BookOpen, Send } from 'lucide-react';

interface Props {
  onComplete: () => void;
  completed: boolean;
  onSaveNotes: (notes: string) => void;
}

export function ReviewReflection({ onComplete, completed, onSaveNotes }: Props) {
  const [notes, setNotes] = useState('');
  const [saved, setSaved] = useState(false);

  function handleSave() {
    onSaveNotes(notes);
    setSaved(true);
  }

  function handleComplete() {
    if (!saved && notes.trim()) {
      handleSave();
    }
    onComplete();
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-lg">今日复盘</h2>
        <span className="text-sm text-slate-500">5 分钟</span>
      </div>

      {/* Struggle notes */}
      <div>
        <h3 className="mb-2 flex items-center gap-2 font-medium text-sm">
          <BookOpen className="h-4 w-4 text-primary-500" />
          今天"想说但说不出来"的词/表达
        </h3>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="例如：想表达'加班费'但不知道怎么用英文说"
          rows={5}
          className="w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-sm placeholder:text-slate-400 dark:border-slate-600 dark:bg-slate-800"
        />
        {!saved && (
          <button
            onClick={handleSave}
            disabled={!notes.trim()}
            className="mt-2 flex items-center gap-1.5 rounded-lg bg-slate-100 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 disabled:opacity-50 dark:bg-slate-700 dark:text-slate-300 dark:hover:bg-slate-600"
          >
            <Send className="h-3.5 w-3.5" />
            保存
          </button>
        )}
        {saved && (
          <p className="mt-2 text-sm text-green-600 dark:text-green-400">
            复盘笔记已保存。这些内容将影响明天的 AI 训练内容生成。
          </p>
        )}
      </div>

      {/* Reflection prompts */}
      <div className="rounded-lg bg-slate-50 p-4 dark:bg-slate-800/50">
        <h3 className="mb-3 font-medium text-sm">反思提示</h3>
        <ul className="space-y-2 text-sm text-slate-600 dark:text-slate-400">
          <li>• 今天哪个句型最顺手？哪个最不习惯？</li>
          <li>• 即兴表达时，脑子里的第一反应是中文还是英文？</li>
          <li>• 今天的你跟一个月前的你相比，哪个部分进步最大？</li>
        </ul>
      </div>

      {/* Weather-like daily check */}
      <div className="rounded-xl border border-slate-200 p-4 dark:border-slate-700">
        <p className="mb-3 text-sm font-medium">今天的口语感觉像什么天气？</p>
        <div className="flex gap-2 text-2xl">
          {['🌧️', '☁️', '⛅', '☀️', '🔥'].map((emoji, i) => (
            <button
              key={i}
              className="rounded-lg p-2 transition-transform hover:scale-125"
              title={['暴雨（很不顺）', '阴天（不太顺）', '多云（还行）', '晴天（很顺）', '火力全开'][i]}
            >
              {emoji}
            </button>
          ))}
        </div>
      </div>

      {/* Complete training */}
      <div className="flex justify-center pt-4">
        <button
          onClick={handleComplete}
          disabled={completed}
          className="rounded-lg bg-primary-600 px-8 py-3 font-medium text-white hover:bg-primary-700 disabled:opacity-50"
        >
          {completed ? '训练已完成！' : '完成训练'}
        </button>
      </div>
    </div>
  );
}
