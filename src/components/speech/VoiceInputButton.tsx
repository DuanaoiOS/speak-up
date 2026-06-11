'use client';

import { useRef, useState } from 'react';
import { Mic, Square } from 'lucide-react';
import { createSpeechRecognition, requestSpeechPermission } from '@/lib/speech/recognition';

interface Props {
  onTranscript: (text: string) => void;
  className?: string;
}

export function VoiceInputButton({ onTranscript, className = '' }: Props) {
  const [isListening, setIsListening] = useState(false);
  const speechRef = useRef<ReturnType<typeof createSpeechRecognition> | null>(null);

  async function startListening() {
    try {
      const granted = await requestSpeechPermission();
      if (!granted) return;
    } catch {}

    const speech = createSpeechRecognition();
    speechRef.current = speech;

    speech.onResult((result) => {
      if (result.isFinal) {
        onTranscript(result.transcript);
        speech.stop();
        setIsListening(false);
      }
    });

    speech.onError(() => {
      setIsListening(false);
    });

    speech.start();
    setIsListening(true);
  }

  function stopListening() {
    speechRef.current?.stop();
    setIsListening(false);
  }

  return (
    <button
      onTouchStart={(e) => { e.preventDefault(); startListening(); }}
      onTouchEnd={(e) => { e.preventDefault(); stopListening(); }}
      onMouseDown={() => startListening()}
      onMouseUp={() => stopListening()}
      className={`rounded-full p-2 select-none touch-none transition-colors ${
        isListening
          ? 'bg-red-500 text-white animate-pulse'
          : 'bg-slate-100 text-slate-500 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-400'
      } ${className}`}
      style={{ WebkitTouchCallout: 'none', WebkitUserSelect: 'none', userSelect: 'none' }}
    >
      {isListening ? <Square className="h-4 w-4" /> : <Mic className="h-4 w-4" />}
    </button>
  );
}
