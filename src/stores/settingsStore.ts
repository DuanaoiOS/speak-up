import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type AIProvider = 'claude' | 'openai';

export interface ProviderConfig {
  id: string;
  name: string;
  provider: AIProvider;
  baseUrl: string;
  apiKey: string;
  model: string;
}

interface SettingsStore {
  // Current active provider
  provider: AIProvider;
  // For Anthropic
  anthropicApiKey: string;
  anthropicModel: string;
  // For OpenAI-compatible (includes official OpenAI, DeepSeek, Moonshot, Ollama, etc.)
  openaiApiKey: string;
  openaiBaseUrl: string;
  openaiModel: string;
  // Preferences
  ttsEnabled: boolean;
  theme: 'light' | 'dark';

  // Actions
  setProvider: (provider: AIProvider) => void;
  setAnthropicApiKey: (key: string) => void;
  setAnthropicModel: (model: string) => void;
  setOpenaiApiKey: (key: string) => void;
  setOpenaiBaseUrl: (url: string) => void;
  setOpenaiModel: (model: string) => void;
  setTtsEnabled: (enabled: boolean) => void;
  setTheme: (theme: 'light' | 'dark') => void;

  // Derived: get current config
  getActiveApiKey: () => string;
  getActiveBaseUrl: () => string;
  getActiveModel: () => string;
}

export const OPENAI_COMPATIBLE_PRESETS = [
  { name: 'OpenAI', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o' },
  { name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', model: 'deepseek-chat' },
  { name: 'Moonshot (Kimi)', baseUrl: 'https://api.moonshot.cn/v1', model: 'moonshot-v1-8k' },
  { name: 'Groq', baseUrl: 'https://api.groq.com/openai/v1', model: 'llama-3.1-8b-instant' },
  { name: 'Together AI', baseUrl: 'https://api.together.xyz/v1', model: 'meta-llama/Llama-3-8b-chat-hf' },
  { name: 'Agnes AI', baseUrl: 'https://apihub.agnes-ai.com/v1', model: 'agnes-2.0-flash' },
  { name: 'Ollama (本地)', baseUrl: 'http://localhost:11434/v1', model: 'llama3' },
  { name: '自定义', baseUrl: '', model: '' },
];

export const useSettingsStore = create<SettingsStore>()(
  persist(
    (set, get) => ({
      provider: 'claude' as AIProvider,
      anthropicApiKey: '',
      anthropicModel: 'claude-sonnet-4-20250514',
      openaiApiKey: '',
      openaiBaseUrl: 'https://api.openai.com/v1',
      openaiModel: 'gpt-4o',
      ttsEnabled: true,
      theme: 'light' as const,

      setProvider: (provider) => set({ provider }),
      setAnthropicApiKey: (key) => set({ anthropicApiKey: key }),
      setAnthropicModel: (model) => set({ anthropicModel: model }),
      setOpenaiApiKey: (key) => set({ openaiApiKey: key }),
      setOpenaiBaseUrl: (url) => set({ openaiBaseUrl: url }),
      setOpenaiModel: (model) => set({ openaiModel: model }),
      setTtsEnabled: (ttsEnabled) => set({ ttsEnabled }),
      setTheme: (theme) => set({ theme }),

      getActiveApiKey: () => {
        const s = get();
        return s.provider === 'claude' ? s.anthropicApiKey : s.openaiApiKey;
      },
      getActiveBaseUrl: () => {
        const s = get();
        return s.provider === 'claude' ? '' : s.openaiBaseUrl;
      },
      getActiveModel: () => {
        const s = get();
        return s.provider === 'claude' ? s.anthropicModel : s.openaiModel;
      },
    }),
    { name: 'speakup-settings' }
  )
);
