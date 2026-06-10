// Web Speech API wrapper for Speech Recognition (STT)

export interface SpeechRecognitionResult {
  transcript: string;
  isFinal: boolean;
}

export function isSpeechRecognitionSupported(): boolean {
  return 'SpeechRecognition' in window || 'webkitSpeechRecognition' in window;
}

export function createSpeechRecognition(): {
  start: () => void;
  stop: () => void;
  onResult: (cb: (result: SpeechRecognitionResult) => void) => void;
  onError: (cb: (error: string) => void) => void;
} {
  const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
  const recognition = new SpeechRecognition();

  recognition.lang = 'en-US';
  recognition.interimResults = true;
  recognition.continuous = true;
  recognition.maxAlternatives = 1;

  let resultCallback: (result: SpeechRecognitionResult) => void = () => {};
  let errorCallback: (error: string) => void = () => {};

  recognition.onresult = (event: any) => {
    let transcript = '';
    let isFinal = false;
    for (let i = event.resultIndex; i < event.results.length; i++) {
      transcript += event.results[i][0].transcript;
      if (event.results[i].isFinal) isFinal = true;
    }
    resultCallback({ transcript, isFinal });
  };

  recognition.onerror = (event: any) => {
    const messages: Record<string, string> = {
      'not-allowed': '麦克风权限被拒绝，请在浏览器设置中允许麦克风访问。',
      'no-speech': '未检测到语音。请再试一次。',
      'audio-capture': '未找到麦克风设备。',
      'network': '语音识别需要网络连接。',
    };
    errorCallback(messages[event.error] || `语音识别错误: ${event.error}`);
  };

  return {
    start: () => {
      try {
        recognition.start();
      } catch {
        // Already started
      }
    },
    stop: () => {
      try {
        recognition.stop();
      } catch {
        // Already stopped
      }
    },
    onResult: (cb) => {
      resultCallback = cb;
    },
    onError: (cb) => {
      errorCallback = cb;
    },
  };
}

// Audio recording via MediaRecorder
export function startAudioRecording(): Promise<{
  stop: () => Promise<Blob>;
  stream: MediaStream;
}> {
  return navigator.mediaDevices.getUserMedia({ audio: true }).then((stream) => {
    const mediaRecorder = new MediaRecorder(stream, {
      mimeType: 'audio/webm;codecs=opus',
    });
    const chunks: Blob[] = [];

    mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) chunks.push(e.data);
    };

    mediaRecorder.start();

    return {
      stream,
      stop: () =>
        new Promise((resolve) => {
          mediaRecorder.onstop = () => {
            stream.getTracks().forEach((t) => t.stop());
            resolve(new Blob(chunks, { type: 'audio/webm' }));
          };
          mediaRecorder.stop();
        }),
    };
  });
}

// TTS using Web Speech API
export function speakText(text: string, rate: number = 0.9): void {
  if (!('speechSynthesis' in window)) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'en-US';
  utterance.rate = rate;
  utterance.pitch = 1;
  // Prefer a good English voice
  const voices = speechSynthesis.getVoices();
  const enVoice = voices.find((v) => v.lang.startsWith('en') && v.name.includes('Google'))
    || voices.find((v) => v.lang.startsWith('en-US'))
    || voices[0];
  if (enVoice) utterance.voice = enVoice;
  speechSynthesis.speak(utterance);
}
