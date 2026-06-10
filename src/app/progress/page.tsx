'use client';

import { useEffect, useState } from 'react';
import { useProgressStore } from '@/stores/progressStore';
import { getAllSessions } from '@/lib/storage/db';
import { TrendingUp, Clock, Flame, Target, Calendar } from 'lucide-react';
import type { SessionRecord } from '@/types/progress';

export default function ProgressPage() {
  const { currentStreak, longestStreak, totalSessions, totalMinutes, topicsCovered, completedDates } =
    useProgressStore();
  const [recentSessions, setRecentSessions] = useState<SessionRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getAllSessions().then((sessions) => {
      setRecentSessions(sessions.slice(0, 10));
      setLoading(false);
    });
  }, []);

  // Generate heatmap data (last 12 weeks)
  const today = new Date();
  const heatmapDays: { date: string; count: number }[] = [];
  for (let i = 83; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const ds = d.toISOString().split('T')[0];
    heatmapDays.push({
      date: ds,
      count: completedDates.includes(ds) ? 1 : 0,
    });
  }

  function getIntensity(count: number): string {
    if (count === 0) return 'bg-slate-100 dark:bg-slate-800';
    if (count === 1) return 'bg-green-400 dark:bg-green-600';
    return 'bg-green-600 dark:bg-green-400';
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">学习数据</h1>

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          {
            label: '当前连续',
            value: `${currentStreak} 天`,
            icon: Flame,
            color: 'text-orange-500',
            bg: 'bg-orange-100 dark:bg-orange-900/30',
          },
          {
            label: '最长连续',
            value: `${longestStreak} 天`,
            icon: Target,
            color: 'text-red-500',
            bg: 'bg-red-100 dark:bg-red-900/30',
          },
          {
            label: '总训练',
            value: `${totalSessions} 次`,
            icon: TrendingUp,
            color: 'text-blue-500',
            bg: 'bg-blue-100 dark:bg-blue-900/30',
          },
          {
            label: '总时长',
            value: `${Math.round(totalMinutes / 60)}h`,
            icon: Clock,
            color: 'text-purple-500',
            bg: 'bg-purple-100 dark:bg-purple-900/30',
          },
        ].map((stat) => (
          <div
            key={stat.label}
            className="rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
          >
            <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${stat.bg} ${stat.color}`}>
              <stat.icon className="h-4 w-4" />
            </div>
            <div className="mt-2 text-2xl font-bold">{stat.value}</div>
            <div className="text-xs text-slate-500 dark:text-slate-400">{stat.label}</div>
          </div>
        ))}
      </div>

      {/* Heatmap */}
      <section>
        <h2 className="mb-3 font-semibold">训练热力图（近 12 周）</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800">
          <div className="flex flex-wrap gap-1">
            {heatmapDays.map((day) => (
              <div
                key={day.date}
                className={`h-3.5 w-3.5 rounded-sm ${getIntensity(day.count)}`}
                title={`${day.date}: ${day.count > 0 ? '已完成' : '未训练'}`}
              />
            ))}
          </div>
          <div className="mt-3 flex items-center gap-2 text-xs text-slate-400">
            <span>少</span>
            <div className="h-3 w-3 rounded-sm bg-slate-100 dark:bg-slate-800" />
            <div className="h-3 w-3 rounded-sm bg-green-400 dark:bg-green-600" />
            <div className="h-3 w-3 rounded-sm bg-green-600 dark:bg-green-400" />
            <span>多</span>
          </div>
        </div>
      </section>

      {/* Topics covered */}
      {topicsCovered.length > 0 && (
        <section>
          <h2 className="mb-3 font-semibold">已覆盖话题</h2>
          <div className="flex flex-wrap gap-2">
            {topicsCovered.map((topic) => (
              <span
                key={topic}
                className="rounded-full bg-primary-100 px-3 py-1 text-xs font-medium text-primary-700 dark:bg-primary-900/30 dark:text-primary-300"
              >
                {topic}
              </span>
            ))}
          </div>
        </section>
      )}

      {/* Recent sessions */}
      <section>
        <h2 className="mb-3 font-semibold">最近训练记录</h2>
        {recentSessions.length === 0 ? (
          <p className="text-sm text-slate-400">还没有训练记录。</p>
        ) : (
          <div className="space-y-2">
            {recentSessions.map((session) => (
              <div
                key={session.date}
                className="flex items-center justify-between rounded-lg border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-800"
              >
                <div className="flex items-center gap-3">
                  <Calendar className="h-4 w-4 text-slate-400" />
                  <div>
                    <div className="font-medium text-sm">
                      Week {session.week} Day {session.day}
                    </div>
                    <div className="text-xs text-slate-400">{session.date}</div>
                  </div>
                </div>
                <div className="text-sm text-slate-500">
                  {session.minutesSpent} 分钟 ·
                  {session.stepsCompleted.filter(Boolean).length}/5 步完成
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Export */}
      <section className="text-center">
        <button
          onClick={async () => {
            const { exportAllData } = await import('@/lib/storage/db');
            const json = await exportAllData();
            const blob = new Blob([json], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `speakup-backup-${new Date().toISOString().split('T')[0]}.json`;
            a.click();
            URL.revokeObjectURL(url);
          }}
          className="rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-600"
        >
          导出数据备份
        </button>
      </section>
    </div>
  );
}
