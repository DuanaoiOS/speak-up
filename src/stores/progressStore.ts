import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { ProgressData } from '@/types/progress';

interface ProgressStore extends ProgressData {
  completeSession: (date: string, minutesSpent: number, topics: string[]) => void;
  loadProgress: (data: ProgressData) => void;
  reset: () => void;
}

const defaultProgress: ProgressData = {
  currentStreak: 0,
  longestStreak: 0,
  completedDates: [],
  totalSessions: 0,
  totalMinutes: 0,
  topicsCovered: [],
};

export const useProgressStore = create<ProgressStore>()(
  persist(
    (set, get) => ({
      ...defaultProgress,

      completeSession: (date, minutesSpent, topics) => {
        const s = get();
        const dates = s.completedDates.includes(date)
          ? s.completedDates
          : [...s.completedDates, date];

        // Calculate streak
        const sorted = Array.from(dates).sort().reverse();
        let streak = 1;
        for (let i = 1; i < sorted.length; i++) {
          const d = new Date(sorted[i]);
          const prev = new Date(sorted[i - 1]);
          const diff = (prev.getTime() - d.getTime()) / (1000 * 60 * 60 * 24);
          if (diff === 1) streak++;
          else break;
        }

        const newTopics = Array.from(new Set([...s.topicsCovered, ...topics]));

        set({
          completedDates: dates,
          currentStreak: streak,
          longestStreak: Math.max(s.longestStreak, streak),
          totalSessions: s.totalSessions + 1,
          totalMinutes: s.totalMinutes + minutesSpent,
          topicsCovered: newTopics,
        });
      },

      loadProgress: (data) => set(data),
      reset: () => set(defaultProgress),
    }),
    { name: 'progress-data' }
  )
);
