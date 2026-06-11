'use client';

import { Volume2 } from 'lucide-react';

interface Props {
  text: string;
  className?: string;
}

export function SpeakButton({ text, className = '' }: Props) {
  function speak() {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = 'en-US';
    u.rate = 0.85;
    speechSynthesis.speak(u);
  }

  return (
    <button
      onClick={(e) => { e.stopPropagation(); speak(); }}
      className={`inline-flex items-center justify-center rounded-full p-1 text-slate-400 hover:bg-slate-100 hover:text-primary-600 active:scale-90 transition-all dark:hover:bg-slate-700 dark:hover:text-primary-400 ${className}`}
      title="点击朗读"
    >
      <Volume2 className="h-3.5 w-3.5" />
    </button>
  );
}
