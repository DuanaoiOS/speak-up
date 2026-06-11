'use client';

import { useState, useRef, useEffect } from 'react';
import { Play, Pause, SkipBack, Volume2 } from 'lucide-react';

interface Props {
  content: string;
  title: string;
  onComplete: () => void;
  completed: boolean;
}

export function StoryReader({ content, title, onComplete, completed }: Props) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentSentence, setCurrentSentence] = useState(0);
  const sentences = content.match(/[^.!?\n]+[.!?]*/g) || [content];

  // Stop audio when navigating away or switching steps
  useEffect(() => {
    return () => {
      window.speechSynthesis.cancel();
    };
  }, []);

  function speakSentence(index: number) {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(sentences[index]);
    u.lang = 'en-US';
    u.rate = 0.85;
    u.onend = () => {
      if (index < sentences.length - 1) {
        setCurrentSentence(index + 1);
        speakSentence(index + 1);
      } else {
        setIsPlaying(false);
      }
    };
    speechSynthesis.speak(u);
    setCurrentSentence(index);
  }

  function togglePlay() {
    if (isPlaying) {
      window.speechSynthesis.cancel();
      setIsPlaying(false);
    } else {
      setIsPlaying(true);
      speakSentence(currentSentence);
    }
  }

  function replaySentence() {
    window.speechSynthesis.cancel();
    speakSentence(currentSentence);
  }

  return (
    <div className="space-y-4">
      {/* Playback controls */}
      <div className="flex items-center justify-center gap-4">
        <button onClick={togglePlay} className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-600 text-white shadow">
          {isPlaying ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5 ml-0.5" />}
        </button>
        <button onClick={replaySentence} className="rounded-full p-2 text-slate-400 hover:text-slate-600">
          <SkipBack className="h-5 w-5" />
        </button>
      </div>
      <p className="text-center text-xs text-slate-400">
        {isPlaying ? '正在朗读...' : '点击播放，逐句跟读。点击句子可跳转。'}
      </p>

      {/* Story text */}
      <div className="rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        <h3 className="mb-4 text-lg font-bold">{title}</h3>
        <div className="story-text leading-loose">
          {sentences.map((sentence, i) => (
            <span
              key={i}
              onClick={() => {
                window.speechSynthesis.cancel();
                setIsPlaying(false);
                setCurrentSentence(i);
                setTimeout(() => speakSentence(i), 100);
              }}
              className={`cursor-pointer rounded px-1 py-0.5 transition-colors ${
                i === currentSentence && isPlaying
                  ? 'bg-primary-100 text-primary-900 dark:bg-primary-900/30 dark:text-primary-200'
                  : i === currentSentence
                  ? 'bg-amber-50 text-amber-900 dark:bg-amber-900/20 dark:text-amber-200'
                  : 'hover:bg-slate-50 dark:hover:bg-slate-700/50'
              }`}
            >
              {sentence}{' '}
            </span>
          ))}
        </div>
      </div>

      <button
        onClick={onComplete}
        disabled={completed}
        className="w-full rounded-lg bg-primary-600 py-3 text-white hover:bg-primary-700 disabled:opacity-50"
      >
        {completed ? '已完成跟读' : '完成跟读'}
      </button>
    </div>
  );
}
