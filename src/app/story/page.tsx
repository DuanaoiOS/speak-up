import { Suspense } from 'react';
import { StorySession } from './client';

export default function StoryPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center py-20"><div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" /></div>}>
      <StorySession />
    </Suspense>
  );
}
