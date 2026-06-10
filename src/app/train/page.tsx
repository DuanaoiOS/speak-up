'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';

interface DayInfo {
  week: number;
  day: number;
  title: string;
}

export default function TrainHubPage() {
  const [days, setDays] = useState<DayInfo[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/content')
      .then((r) => r.json())
      .then((data) => {
        setDays(data.days || []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" />
      </div>
    );
  }

  // Group by week
  const weeks = new Map<number, DayInfo[]>();
  for (const day of days) {
    const w = weeks.get(day.week) || [];
    w.push(day);
    weeks.set(day.week, w);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">每日训练</h1>
        <p className="mt-1 text-slate-500 dark:text-slate-400">
          选择一天开始训练。Week 1-4 是静态内容，Week 5+ 由 AI 生成。
        </p>
      </div>

      {Array.from(weeks.entries()).map(([week, weekDays]) => (
        <section key={week}>
          <h2 className="mb-3 font-semibold text-lg text-slate-700 dark:text-slate-300">
            第 {week} 周
          </h2>
          <div className="grid gap-2 sm:grid-cols-2">
            {weekDays
              .filter((d) => d.day !== 7) // Skip rest days in listing? No, include all
              .map((d) => (
                <Link
                  key={`${d.week}-${d.day}`}
                  href={`/train/${d.week}-${d.day}`}
                  className="flex items-center justify-between rounded-lg border border-slate-200 bg-white px-4 py-3 transition-shadow hover:shadow-sm dark:border-slate-700 dark:bg-slate-800"
                >
                  <div>
                    <span className="font-medium">Day {d.day}</span>
                    <span className="ml-2 text-sm text-slate-500 dark:text-slate-400">
                      {d.title}
                    </span>
                  </div>
                  {d.day === 7 && (
                    <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-500 dark:bg-slate-700 dark:text-slate-400">
                      休息
                    </span>
                  )}
                </Link>
              ))}
          </div>
        </section>
      ))}

      {/* AI generation for Week 5+ */}
      <section className="rounded-xl border border-dashed border-primary-300 bg-primary-50 p-6 text-center dark:border-primary-700 dark:bg-primary-900/20">
        <h3 className="font-semibold text-primary-700 dark:text-primary-300">
          需要更多训练内容？
        </h3>
        <p className="mt-1 text-sm text-primary-600 dark:text-primary-400">
          Week 5+ 的训练内容由 AI 自动生成，根据你的水平和练习历史定制。
        </p>
        <p className="mt-1 text-xs text-primary-500 dark:text-primary-500">
          请先在设置中配置 API Key，然后选择 Week 5 Day 1 开始。
        </p>
      </section>
    </div>
  );
}
