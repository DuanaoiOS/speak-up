export interface ProgressData {
  currentStreak: number;
  longestStreak: number;
  completedDates: string[];
  totalSessions: number;
  totalMinutes: number;
  topicsCovered: string[];
}

export interface SessionRecord {
  date: string;
  week: number;
  day: number;
  stepsCompleted: boolean[];
  struggleNotes: string;
  minutesSpent: number;
  audioRecordingBlobKey?: string;
}
