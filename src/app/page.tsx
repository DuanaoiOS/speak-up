'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useProgressStore } from '@/stores/progressStore';
import { getAllSessions } from '@/lib/storage/db';
import { Dumbbell, MessageCircle, TrendingUp, Zap } from 'lucide-react';

export default function DashboardPage() {
  const { currentStreak, longestStreak, totalSessions, totalMinutes } = useProgressStore();
  const [todayCompleted, setTodayCompleted] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const today = new Date().toISOString().split('T')[0];
    getAllSessions().then((sessions) => {
      setTodayCompleted(sessions.some((s) => s.date === today));
      setLoading(false);
    });
  }, []);

  return (
    <div className="space-y-8">
      {/* Greeting + Streak */}
      <section className="rounded-2xl bg-gradient-to-br from-primary-500 to-primary-700 p-6 text-white">
        <h1 className="text-2xl font-bold">
          {loading ? '加载中...' : todayCompleted ? '今日训练已完成！' : '准备好今天的训练了吗？'}
        </h1>
        <p className="mt-1 text-primary-100">
          {currentStreak > 0
            ? `已连续打卡 ${currentStreak} 天，最长 ${longestStreak} 天`
            : '开始你的第一次训练吧'}
        </p>
        <div className="mt-4 flex gap-4">
          <div className="rounded-lg bg-white/20 px-4 py-2 backdrop-blur">
            <div className="text-2xl font-bold">{totalSessions}</div>
            <div className="text-xs text-primary-100">总训练次数</div>
          </div>
          <div className="rounded-lg bg-white/20 px-4 py-2 backdrop-blur">
            <div className="text-2xl font-bold">{Math.round(totalMinutes / 60)}h</div>
            <div className="text-xs text-primary-100">总时长</div>
          </div>
        </div>
      </section>

      {/* Quick Actions */}
      <section>
        <h2 className="mb-3 font-semibold text-lg">快速开始</h2>
        <div className="grid grid-cols-2 gap-3">
          <Link
            href="/train"
            className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary-100 text-primary-600 dark:bg-primary-900/30 dark:text-primary-400">
              <Dumbbell className="h-5 w-5" />
            </div>
            <div>
              <div className="font-medium">每日训练</div>
              <div className="text-xs text-slate-500 dark:text-slate-400">5步口语激活</div>
            </div>
          </Link>

          <Link
            href="/chat"
            className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400">
              <MessageCircle className="h-5 w-5" />
            </div>
            <div>
              <div className="font-medium">AI 对话</div>
              <div className="text-xs text-slate-500 dark:text-slate-400">情景陪练</div>
            </div>
          </Link>

          <Link
            href="/train?mode=review"
            className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-amber-100 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400">
              <Zap className="h-5 w-5" />
            </div>
            <div>
              <div className="font-medium">快速复习</div>
              <div className="text-xs text-slate-500 dark:text-slate-400">昨天的内容</div>
            </div>
          </Link>

          <Link
            href="/progress"
            className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400">
              <TrendingUp className="h-5 w-5" />
            </div>
            <div>
              <div className="font-medium">学习数据</div>
              <div className="text-xs text-slate-500 dark:text-slate-400">追踪进步</div>
            </div>
          </Link>
        </div>
      </section>

      {/* Prompt: Set API Key */}
      {!todayCompleted && (
        <section className="rounded-xl border border-dashed border-slate-300 bg-slate-50 p-4 text-center dark:border-slate-600 dark:bg-slate-800/50">
          <p className="text-sm text-slate-500 dark:text-slate-400">
            开始训练前，请先在
            <Link href="/settings" className="mx-1 font-medium text-primary-600 underline">
              设置
            </Link>
            中配置你的 API Key，以使用 AI 生成内容和对话陪练功能。
          </p>
        </section>
      )}
    </div>
  );
}
