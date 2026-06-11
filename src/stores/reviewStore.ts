import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface ReviewItem {
  id: string;
  type: 'vocabulary' | 'pattern';
  content: string;        // word or pattern
  definition: string;     // Chinese meaning or explanation
  exampleSentence: string;
  storyTitle: string;
  storyId: string;
  addedAt: number;
  reviewCount: number;
  lastReviewed: number | null;
  mastered: boolean;
}

interface ReviewStore {
  items: ReviewItem[];
  addItem: (item: Omit<ReviewItem, 'id' | 'addedAt' | 'reviewCount' | 'lastReviewed' | 'mastered'>) => void;
  markReviewed: (id: string) => void;
  toggleMastered: (id: string) => void;
  removeItem: (id: string) => void;
  getDueItems: () => ReviewItem[];
  getStats: () => { total: number; mastered: number; reviewedToday: number };
}

export const useReviewStore = create<ReviewStore>()(
  persist(
    (set, get) => ({
      items: [],

      addItem: (item) => {
        const existing = get().items.find(
          (i) => i.content === item.content && i.storyId === item.storyId
        );
        if (existing) return; // don't duplicate
        set((s) => ({
          items: [
            ...s.items,
            {
              ...item,
              id: Date.now().toString(),
              addedAt: Date.now(),
              reviewCount: 0,
              lastReviewed: null,
              mastered: false,
            },
          ],
        }));
      },

      markReviewed: (id) =>
        set((s) => ({
          items: s.items.map((i) =>
            i.id === id ? { ...i, reviewCount: i.reviewCount + 1, lastReviewed: Date.now() } : i
          ),
        })),

      toggleMastered: (id) =>
        set((s) => ({
          items: s.items.map((i) =>
            i.id === id ? { ...i, mastered: !i.mastered } : i
          ),
        })),

      removeItem: (id) =>
        set((s) => ({ items: s.items.filter((i) => i.id !== id) })),

      getDueItems: () => {
        const now = Date.now();
        return get().items.filter((i) => {
          if (i.mastered) return false;
          if (!i.lastReviewed) return true;
          // Due if not reviewed in last 24 hours, or if reviewCount < 3
          const hoursSince = (now - i.lastReviewed) / (1000 * 60 * 60);
          return hoursSince > 24 || i.reviewCount < 3;
        });
      },

      getStats: () => {
        const items = get().items;
        const today = new Date().toISOString().split('T')[0];
        return {
          total: items.length,
          mastered: items.filter((i) => i.mastered).length,
          reviewedToday: items.filter((i) => {
            if (!i.lastReviewed) return false;
            return new Date(i.lastReviewed).toISOString().split('T')[0] === today;
          }).length,
        };
      },
    }),
    { name: 'review-data' }
  )
);
