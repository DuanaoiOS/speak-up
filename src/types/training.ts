// Training content types

export interface SentenceFrame {
  pattern: string;
  usage: string;
  example: string;
  substitutions: string[];
}

export interface Collocation {
  chinese: string;
  english: string;
}

export interface ShadowingContent {
  youtubeSearchQuery: string;
  instructions: string;
  focusPhrases: string[];
}

export interface ImpromptuTopic {
  topic: string;
  cueWords: string[];
  sentenceFrameHints: string[];
}

export interface TrainingContent {
  sentenceFrames: SentenceFrame[];
  collocations: Collocation[];
  shadowing: ShadowingContent;
  impromptu: ImpromptuTopic;
}

export type TrainingStep = 'sentence_frames' | 'collocations' | 'shadowing' | 'impromptu' | 'review';

export interface StepState {
  completed: boolean;
  markedItems?: string[];
  struggleNotes?: string;
  audioBlobKey?: string;
}

export interface TrainingSession {
  date: string;
  week: number;
  day: number;
  steps: Record<TrainingStep, StepState>;
  minutesSpent: number;
  isComplete: boolean;
}

export interface GeneratedContent {
  date: string;
  contentType: TrainingStep;
  content: TrainingContent[keyof Pick<TrainingContent, 'sentenceFrames' | 'collocations'>] | ShadowingContent | ImpromptuTopic;
  generatedAt: number;
}
