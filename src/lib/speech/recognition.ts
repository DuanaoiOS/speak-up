// Speech Recognition — custom native Capacitor plugin (iOS SFSpeechRecognizer)

export interface SpeechRecognitionResult {
  transcript: string;
  isFinal: boolean;
}

export function isSpeechRecognitionSupported(): boolean {
  return true;
}

export async function requestSpeechPermission(): Promise<boolean> {
  try {
    const { Capacitor } = await import('@capacitor/core');
    const plugins = (Capacitor as any).Plugins || {};
    const plugin = plugins.SpeechRecognition;
    if (!plugin) {
      console.log('SpeechRecognition plugin not found in Capacitor plugins');
      return false;
    }
    const result = await plugin.requestPermission();
    return result.granted === true;
  } catch (e) {
    console.error('requestPermission error:', e);
    return false;
  }
}

export function createSpeechRecognition(): {
  start: () => Promise<void>;
  stop: () => Promise<void>;
  onResult: (cb: (result: SpeechRecognitionResult) => void) => void;
  onError: (cb: (error: string) => void) => void;
} {
  let resultCallback: (result: SpeechRecognitionResult) => void = () => {};
  let errorCallback: (error: string) => void = () => {};

  return {
    start: async () => {
      // Try native Capacitor plugin first
      try {
        const { Capacitor } = await import('@capacitor/core');
        const plugins = (Capacitor as any).Plugins || {};
        const plugin = plugins.SpeechRecognition;

        if (plugin) {
          // Set up listener before starting
          const handleResult = (data: any) => {
            if (data?.matches?.length) {
              resultCallback({
                transcript: data.matches[0],
                isFinal: data.isFinal || false,
              });
            }
          };

          const handleError = (data: any) => {
            errorCallback(data?.message || '语音识别错误');
          };

          // Register listeners — Capacitor prefixes events with plugin name
          try {
            const cap = Capacitor as any;
            if (cap.addListener) {
              cap.addListener('SpeechRecognition:partialResults', handleResult);
              cap.addListener('SpeechRecognition:error', handleError);
            }
          } catch {}

          await plugin.start();
          return;
        }
      } catch (e) {
        console.log('Native plugin start failed, trying web:', e);
      }

      // Web Speech API fallback
      const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      if (!SR) {
        errorCallback('语音识别不可用');
        return;
      }
      const r = new SR();
      r.lang = 'en-US';
      r.interimResults = true;
      r.continuous = true;
      r.onresult = (e: any) => {
        let t = '';
        for (let i = e.resultIndex; i < e.results.length; i++) t += e.results[i][0].transcript;
        resultCallback({ transcript: t, isFinal: e.results[e.results.length - 1]?.isFinal || false });
      };
      r.onerror = (e: any) => {
        const msgs: Record<string, string> = {
          'not-allowed': '麦克风权限被拒绝。请在系统设置中允许麦克风访问。',
          aborted: '语音识别中断，请重试。',
        };
        errorCallback(msgs[e.error] || `语音识别错误: ${e.error}`);
      };
      r.start();
    },

    stop: async () => {
      try {
        const { Capacitor } = await import('@capacitor/core');
        const plugins = (Capacitor as any).Plugins || {};
        const plugin = plugins.SpeechRecognition;
        if (plugin) {
          await plugin.stop();
          return;
        }
      } catch {}
    },

    onResult: (cb) => { resultCallback = cb; },
    onError: (cb) => { errorCallback = cb; },
  };
}
