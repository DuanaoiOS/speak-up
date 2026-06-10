'use client';

import { useState } from 'react';
import { Youtube, CheckCircle, Plus, Trash2 } from 'lucide-react';

interface Props {
  youtubeSearch: string;
  onComplete: () => void;
  completed: boolean;
}

export function ShadowingPractice({ youtubeSearch, onComplete, completed }: Props) {
  const [phrases, setPhrases] = useState<string[]>([]);
  const [newPhrase, setNewPhrase] = useState('');
  const [practiced, setPracticed] = useState<Set<number>>(new Set());

  function addPhrase() {
    if (newPhrase.trim()) {
      setPhrases([...phrases, newPhrase.trim()]);
      setNewPhrase('');
    }
  }

  function removePhrase(i: number) {
    setPhrases(phrases.filter((_, idx) => idx !== i));
  }

  function togglePracticed(i: number) {
    const next = new Set(practiced);
    if (next.has(i)) next.delete(i);
    else next.add(i);
    setPracticed(next);
  }

  const youtubeUrl = youtubeSearch
    ? `https://www.youtube.com/results?search_query=${encodeURIComponent(youtubeSearch)}`
    : 'https://www.youtube.com/results?search_query=english+speaking+practice+intermediate';

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-lg">影子跟读</h2>
        <span className="text-sm text-slate-500">15 分钟</span>
      </div>

      {/* YouTube link */}
      <a
        href={youtubeUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-3 rounded-xl border-2 border-red-200 bg-red-50 p-4 transition-colors hover:bg-red-100 dark:border-red-800 dark:bg-red-900/20 dark:hover:bg-red-900/30"
      >
        <Youtube className="h-8 w-8 text-red-500" />
        <div>
          <div className="font-medium text-red-700 dark:text-red-400">在 YouTube 打开跟读视频</div>
          <div className="text-sm text-red-600 dark:text-red-500">
            {youtubeSearch || '搜索英语口语练习视频'}
          </div>
        </div>
      </a>

      {/* Instructions */}
      <div className="rounded-lg bg-slate-50 p-4 text-sm dark:bg-slate-800/50">
        <h4 className="mb-2 font-medium">跟读方法</h4>
        <ol className="ml-4 list-decimal space-y-1 text-slate-600 dark:text-slate-400">
          <li>听一句 → 暂停 → 跟读（模仿语调、重音、停顿）</li>
          <li>同一句跟读 3 遍再往下走</li>
          <li>最后一遍：不停顿，跟视频同步说</li>
        </ol>
      </div>

      {/* Key phrases capture */}
      <div>
        <h3 className="mb-2 font-medium text-sm">重点句收集</h3>
        <p className="mb-3 text-xs text-slate-500">
          从视频中找 2-3 句你觉得"这个表达好，我以后也要用"的句子，各跟读 10 遍。
        </p>

        <div className="flex gap-2">
          <input
            type="text"
            value={newPhrase}
            onChange={(e) => setNewPhrase(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addPhrase()}
            placeholder="输入视频中的好句子..."
            className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
          />
          <button
            onClick={addPhrase}
            className="flex items-center gap-1 rounded-lg bg-primary-600 px-3 py-2 text-sm text-white hover:bg-primary-700"
          >
            <Plus className="h-4 w-4" />
            添加
          </button>
        </div>

        {phrases.length > 0 && (
          <div className="mt-3 space-y-2">
            {phrases.map((p, i) => (
              <div
                key={i}
                className={`flex items-center gap-2 rounded-lg border p-3 ${
                  practiced.has(i)
                    ? 'border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20'
                    : 'border-slate-200 dark:border-slate-700'
                }`}
              >
                <span className="flex-1 text-sm">{p}</span>
                <button
                  onClick={() => togglePracticed(i)}
                  className={`rounded p-1 ${
                    practiced.has(i)
                      ? 'text-green-600'
                      : 'text-slate-400 hover:text-green-600'
                  }`}
                  title={practiced.has(i) ? '已练习10遍' : '标记为已练习'}
                >
                  <CheckCircle className="h-4 w-4" />
                </button>
                <button
                  onClick={() => removePhrase(i)}
                  className="rounded p-1 text-slate-400 hover:text-red-500"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="flex justify-center">
        <button
          onClick={onComplete}
          disabled={completed}
          className="rounded-lg bg-primary-600 px-6 py-2 text-white hover:bg-primary-700 disabled:opacity-50"
        >
          {completed ? '已完成' : '完成跟读，进入下一步'}
        </button>
      </div>
    </div>
  );
}
