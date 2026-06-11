import { create } from 'zustand';
import type { Story, StoryProgress } from '@/types/story';

interface StoryStore {
  stories: Story[];
  currentStory: Story | null;
  currentStep: number;  // 0-4
  progress: Record<string, StoryProgress>;
  loading: boolean;

  setStories: (stories: Story[]) => void;
  addStory: (story: Story) => void;
  setCurrentStory: (story: Story | null) => void;
  setCurrentStep: (step: number) => void;
  updateProgress: (storyId: string, update: Partial<StoryProgress>) => void;
  getProgress: (storyId: string) => StoryProgress | undefined;
  setLoading: (loading: boolean) => void;
}

export const useStoryStore = create<StoryStore>()((set, get) => ({
  stories: [],
  currentStory: null,
  currentStep: 0,
  progress: {},
  loading: false,

  setStories: (stories) => set({ stories }),
  addStory: (story) => set((s) => ({ stories: [story, ...s.stories] })),
  setCurrentStory: (story) => set({ currentStory: story, currentStep: 0 }),
  setCurrentStep: (step) => set({ currentStep: step }),

  updateProgress: (storyId, update) =>
    set((s) => ({
      progress: {
        ...s.progress,
        [storyId]: { ...(s.progress[storyId] || { storyId, completedSteps: [false, false, false, false, false] }), ...update },
      },
    })),

  getProgress: (storyId) => get().progress[storyId],
  setLoading: (loading) => set({ loading }),
}));
