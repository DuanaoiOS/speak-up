'use client';

import { useState, useRef, useCallback } from 'react';
import { Mic, Square, Play, Pause, RefreshCw, Volume2 } from 'lucide-react';
import { startAudioRecording } from '@/lib/speech/recognition';
import { saveAudio } from '@/lib/storage/db';

interface Props {
  topic: string;
  cueWords: string[];
  onComplete: () => void;
  completed: boolean;
  onAudioSaved: (key: string) => void;
}

export function ImpromptuSpeaking({ topic, cueWords, onComplete, completed, onAudioSaved }: Props) {
  const [phase, setPhase] = useState<'prep' | 'recording' | 'reviewing'>('prep');
  const [prepSeconds, setPrepSeconds] = useState(60);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [selfReview, setSelfReview] = useState({ hesitation: false, repetition: false, monotone: false });

  const prepTimer = useRef<NodeJS.Timeout>();
  const recTimer = useRef<NodeJS.Timeout>();
  const audioRecorder = useRef<{ stop: () => Promise<Blob>; stream: MediaStream } | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  function startPrep() {
    setPhase('prep');
    setPrepSeconds(60);
    prepTimer.current = setInterval(() => {
      setPrepSeconds((s) => {
        if (s <= 1) {
          clearInterval(prepTimer.current);
          return 0;
        }
        return s - 1;
      });
    }, 1000);
  }

  async function startRecording() {
    clearInterval(prepTimer.current);
    setPhase('recording');
    setRecordingSeconds(0);

    try {
      const recorder = await startAudioRecording();
      audioRecorder.current = recorder;

      recTimer.current = setInterval(() => {
        setRecordingSeconds((s) => s + 1);
      }, 1000);
    } catch {
      alert('无法访问麦克风。请检查浏览器权限设置。');
      setPhase('prep');
    }
  }

  async function stopRecording() {
    clearInterval(recTimer.current);
    if (!audioRecorder.current) return;

    const blob = await audioRecorder.current.stop();
    const url = URL.createObjectURL(blob);
    setAudioUrl(url);
    setPhase('reviewing');

    // Save to IndexedDB
    const today = new Date().toISOString().split('T')[0];
    await saveAudio(today, blob);
    onAudioSaved(`audio:${today}`);
  }

  function togglePlayback() {
    if (!audioRef.current || !audioUrl) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play();
      setIsPlaying(true);
      audioRef.current.onended = () => setIsPlaying(false);
    }
  }

  function retry() {
    setAudioUrl(null);
    setPhase('prep');
    setSelfReview({ hesitation: false, repetition: false, monotone: false });
    if (audioRecorder.current) {
      audioRecorder.current.stream.getTracks().forEach((t) => t.stop());
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-lg">即兴表达</h2>
        <span className="text-sm text-slate-500">15 分钟</span>
      </div>

      {/* Topic card */}
      <div className="rounded-xl border-2 border-purple-200 bg-purple-50 p-6 dark:border-purple-800 dark:bg-purple-900/20">
        <div className="mb-1 text-xs font-medium text-purple-600 dark:text-purple-400 uppercase">
          话题
        </div>
        <p className="text-xl font-semibold text-purple-900 dark:text-purple-100">
          {topic || 'Introduce yourself naturally'}
        </p>
        {cueWords.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-1.5">
            {cueWords.map((w, i) => (
              <span
                key={i}
                className="rounded-full bg-purple-200 px-3 py-0.5 text-xs text-purple-700 dark:bg-purple-800 dark:text-purple-300"
              >
                {w}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Prep phase */}
      {phase === 'prep' && (
        <div className="text-center space-y-4">
          <div className="text-6xl font-bold text-primary-600">{prepSeconds}</div>
          <p className="text-slate-500">秒准备时间（只看提示词，不要写稿）</p>
          {prepSeconds === 60 ? (
            <button
              onClick={startPrep}
              className="rounded-lg bg-primary-600 px-6 py-3 font-medium text-white hover:bg-primary-700"
            >
              开始准备
            </button>
          ) : prepSeconds === 0 ? (
            <button
              onClick={startRecording}
              className="flex items-center gap-2 rounded-lg bg-red-600 px-6 py-3 font-medium text-white hover:bg-red-700 mx-auto"
            >
              <Mic className="h-5 w-5" />
              开始录音（说 1-2 分钟）
            </button>
          ) : (
            <button
              onClick={startRecording}
              className="flex items-center gap-2 rounded-lg bg-red-600 px-6 py-3 font-medium text-white hover:bg-red-700 mx-auto"
            >
              <Mic className="h-5 w-5" />
              准备好了，开始录音
            </button>
          )}
        </div>
      )}

      {/* Recording phase */}
      {phase === 'recording' && (
        <div className="text-center space-y-4">
          <div className="relative mx-auto flex h-24 w-24 items-center justify-center">
            <div className="absolute h-full w-full animate-ping rounded-full bg-red-400 opacity-30" />
            <Mic className="relative h-10 w-10 text-red-500" />
          </div>
          <div className="text-3xl font-bold tabular-nums text-red-600">
            {Math.floor(recordingSeconds / 60)}:{(recordingSeconds % 60).toString().padStart(2, '0')}
          </div>
          <p className="text-slate-500">正在录音... 不要停，用最简单的词继续说</p>
          <button
            onClick={stopRecording}
            className="flex items-center gap-2 rounded-lg bg-slate-800 px-6 py-3 font-medium text-white hover:bg-slate-900 mx-auto dark:bg-slate-200 dark:text-slate-800"
          >
            <Square className="h-5 w-5" />
            停止录音
          </button>
        </div>
      )}

      {/* Reviewing phase */}
      {phase === 'reviewing' && audioUrl && (
        <div className="space-y-6">
          {/* Playback */}
          <div className="rounded-xl border border-slate-200 bg-slate-50 p-6 dark:border-slate-700 dark:bg-slate-800">
            <audio ref={audioRef} src={audioUrl} className="hidden" />
            <div className="flex items-center justify-center gap-4">
              <button
                onClick={togglePlayback}
                className="flex h-14 w-14 items-center justify-center rounded-full bg-primary-600 text-white hover:bg-primary-700"
              >
                {isPlaying ? <Pause className="h-6 w-6" /> : <Play className="h-6 w-6 ml-0.5" />}
              </button>
              <div className="text-sm text-slate-500">
                {isPlaying ? '播放中...' : '点击播放回听'}
              </div>
            </div>
          </div>

          {/* Self review */}
          <div>
            <h3 className="mb-3 font-medium">回听自评</h3>
            <div className="space-y-2">
              {[
                { key: 'hesitation' as const, label: '有没有卡壳超过 3 秒的地方？' },
                { key: 'repetition' as const, label: '有没有反复用同一个词（like / very / stuff）？' },
                { key: 'monotone' as const, label: '语调是自然的还是像在背书？' },
              ].map((item) => (
                <label
                  key={item.key}
                  className={`flex items-center gap-3 rounded-lg border p-3 cursor-pointer ${
                    selfReview[item.key]
                      ? 'border-amber-300 bg-amber-50 dark:border-amber-700 dark:bg-amber-900/20'
                      : 'border-slate-200 dark:border-slate-700'
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={selfReview[item.key]}
                    onChange={(e) =>
                      setSelfReview((r) => ({ ...r, [item.key]: e.target.checked }))
                    }
                    className="h-4 w-4"
                  />
                  <span className="text-sm">{item.label}</span>
                </label>
              ))}
            </div>
          </div>

          {/* Actions */}
          <div className="flex justify-center gap-3">
            <button
              onClick={retry}
              className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-600"
            >
              <RefreshCw className="h-4 w-4" />
              再录一次
            </button>
            <button
              onClick={onComplete}
              disabled={completed}
              className="rounded-lg bg-primary-600 px-6 py-2 text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {completed ? '已完成' : '完成，进入复盘'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
