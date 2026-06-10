'use client';

import { Check } from 'lucide-react';
import { cn } from '@/lib/utils/cn';
import type { TrainingStep, StepState } from '@/types/training';

interface Props {
  steps: TrainingStep[];
  currentStep: TrainingStep;
  stepStates: Record<string, StepState>;
  onStepClick: (step: TrainingStep) => void;
  labels: Record<TrainingStep, string>;
}

export function StepNavigation({ steps, currentStep, stepStates, onStepClick, labels }: Props) {
  return (
    <div className="flex items-center gap-1 overflow-x-auto pb-2">
      {steps.map((step, i) => {
        const isActive = step === currentStep;
        const isCompleted = stepStates[step]?.completed;
        const isLast = i === steps.length - 1;

        return (
          <div key={step} className="flex items-center">
            <button
              onClick={() => onStepClick(step)}
              className={cn(
                'flex items-center gap-1.5 whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-medium transition-colors sm:px-4 sm:text-sm',
                isActive && 'bg-primary-600 text-white',
                isCompleted && !isActive && 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
                !isActive && !isCompleted && 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
              )}
            >
              {isCompleted ? <Check className="h-3 w-3" /> : <span className="text-xs">{i + 1}</span>}
              <span className="hidden sm:inline">{labels[step]}</span>
            </button>
            {!isLast && <div className="mx-1 h-px w-4 bg-slate-300 dark:bg-slate-600" />}
          </div>
        );
      })}
    </div>
  );
}
