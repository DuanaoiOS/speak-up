import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { TrainingStep, StepState, TrainingSession } from '@/types/training';

interface TrainingStore {
  currentDay: number | null;
  currentWeek: number | null;
  currentStep: TrainingStep;
  stepStates: Record<string, StepState>;
  timer: number;
  isActive: boolean;

  setDay: (week: number, day: number) => void;
  setStep: (step: TrainingStep) => void;
  updateStepState: (step: TrainingStep, update: Partial<StepState>) => void;
  completeStep: (step: TrainingStep) => void;
  setTimer: (seconds: number) => void;
  setActive: (active: boolean) => void;
  reset: () => void;
}

const initialStepStates: Record<TrainingStep, StepState> = {
  sentence_frames: { completed: false },
  collocations: { completed: false },
  shadowing: { completed: false },
  impromptu: { completed: false },
  review: { completed: false },
};

export const useTrainingStore = create<TrainingStore>()(
  persist(
    (set) => ({
      currentDay: null,
      currentWeek: null,
      currentStep: 'sentence_frames',
      stepStates: { ...initialStepStates },
      timer: 0,
      isActive: false,

      setDay: (week, day) =>
        set({ currentWeek: week, currentDay: day, currentStep: 'sentence_frames', stepStates: { ...initialStepStates }, timer: 0, isActive: false }),

      setStep: (step) => set({ currentStep: step }),

      updateStepState: (step, update) =>
        set((s) => ({
          stepStates: { ...s.stepStates, [step]: { ...s.stepStates[step], ...update } },
        })),

      completeStep: (step) =>
        set((s) => ({
          stepStates: { ...s.stepStates, [step]: { ...s.stepStates[step], completed: true } },
        })),

      setTimer: (seconds) => set({ timer: seconds }),
      setActive: (active) => set({ isActive: active }),

      reset: () =>
        set({
          currentDay: null,
          currentWeek: null,
          currentStep: 'sentence_frames',
          stepStates: { ...initialStepStates },
          timer: 0,
          isActive: false,
        }),
    }),
    { name: 'training-state' }
  )
);
