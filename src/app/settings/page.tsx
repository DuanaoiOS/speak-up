'use client';

import { useState } from 'react';
import { useSettingsStore, OPENAI_COMPATIBLE_PRESETS } from '@/stores/settingsStore';
import { importAllData } from '@/lib/storage/db';
import { Save, Upload, Eye, EyeOff, Check } from 'lucide-react';

export default function SettingsPage() {
  const {
    provider,
    anthropicApiKey,
    anthropicModel,
    openaiApiKey,
    openaiBaseUrl,
    openaiModel,
    ttsEnabled,
    theme,
    setProvider,
    setAnthropicApiKey,
    setAnthropicModel,
    setOpenaiApiKey,
    setOpenaiBaseUrl,
    setOpenaiModel,
    setTtsEnabled,
    setTheme,
  } = useSettingsStore();

  const [showAnthropicKey, setShowAnthropicKey] = useState(false);
  const [showOpenaiKey, setShowOpenaiKey] = useState(false);
  const [openaiPreset, setOpenaiPreset] = useState(-1);
  const [saved, setSaved] = useState(false);

  function handleSave() {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  function applyPreset(index: number) {
    setOpenaiPreset(index);
    const preset = OPENAI_COMPATIBLE_PRESETS[index];
    if (preset.baseUrl) setOpenaiBaseUrl(preset.baseUrl);
    if (preset.model) setOpenaiModel(preset.model);
  }

  async function handleImport() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const text = await file.text();
      await importAllData(text);
      alert('数据导入成功！请刷新页面以加载数据。');
      window.location.reload();
    };
    input.click();
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">设置</h1>

      {/* Provider Selection */}
      <section className="rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        <h2 className="mb-4 font-semibold text-lg">AI 服务商</h2>
        <div className="flex gap-3">
          <button
            onClick={() => setProvider('claude')}
            className={`flex-1 rounded-xl border-2 p-4 text-left transition-colors ${
              provider === 'claude'
                ? 'border-primary-500 bg-primary-50 dark:border-primary-400 dark:bg-primary-900/20'
                : 'border-slate-200 hover:border-slate-300 dark:border-slate-600'
            }`}
          >
            <div className="font-semibold">Anthropic Claude</div>
            <div className="text-xs text-slate-500 mt-1">官方 Claude API</div>
            {provider === 'claude' && <Check className="h-4 w-4 text-primary-600 mt-2" />}
          </button>
          <button
            onClick={() => setProvider('openai')}
            className={`flex-1 rounded-xl border-2 p-4 text-left transition-colors ${
              provider === 'openai'
                ? 'border-primary-500 bg-primary-50 dark:border-primary-400 dark:bg-primary-900/20'
                : 'border-slate-200 hover:border-slate-300 dark:border-slate-600'
            }`}
          >
            <div className="font-semibold">OpenAI 兼容</div>
            <div className="text-xs text-slate-500 mt-1">OpenAI / DeepSeek / Ollama 等</div>
            {provider === 'openai' && <Check className="h-4 w-4 text-primary-600 mt-2" />}
          </button>
        </div>
      </section>

      {/* Anthropic Settings */}
      {provider === 'claude' && (
        <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
          <h2 className="font-semibold text-lg">Anthropic Claude 配置</h2>
          <div>
            <label className="mb-1.5 block text-sm font-medium">API Key</label>
            <div className="relative">
              <input
                type={showAnthropicKey ? 'text' : 'password'}
                value={anthropicApiKey}
                onChange={(e) => setAnthropicApiKey(e.target.value)}
                placeholder="sk-ant-api03-..."
                className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 pr-10 text-sm dark:border-slate-600 dark:bg-slate-700"
              />
              <button
                onClick={() => setShowAnthropicKey(!showAnthropicKey)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400"
              >
                {showAnthropicKey ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>
          <div>
            <label className="mb-1.5 block text-sm font-medium">模型</label>
            <select
              value={anthropicModel}
              onChange={(e) => setAnthropicModel(e.target.value)}
              className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm dark:border-slate-600 dark:bg-slate-700"
            >
              <option value="claude-sonnet-4-20250514">Claude Sonnet 4 (推荐)</option>
              <option value="claude-haiku-4-20250514">Claude Haiku 4 (更快)</option>
              <option value="claude-opus-4-20250514">Claude Opus 4 (最强)</option>
            </select>
          </div>
        </section>
      )}

      {/* OpenAI Compatible Settings */}
      {provider === 'openai' && (
        <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
          <h2 className="font-semibold text-lg">OpenAI 兼容接口配置</h2>

          {/* Presets */}
          <div>
            <label className="mb-1.5 block text-sm font-medium">快速选择服务商</label>
            <div className="grid grid-cols-4 sm:grid-cols-7 gap-1.5">
              {OPENAI_COMPATIBLE_PRESETS.map((preset, i) => (
                <button
                  key={preset.name}
                  onClick={() => applyPreset(i)}
                  className={`rounded-lg border px-2 py-1.5 text-xs transition-colors ${
                    openaiPreset === i
                      ? 'border-primary-500 bg-primary-50 text-primary-700 dark:bg-primary-900/30 dark:text-primary-300'
                      : 'border-slate-200 hover:border-slate-300 dark:border-slate-600'
                  }`}
                >
                  {preset.name}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-sm font-medium">Base URL</label>
            <input
              type="text"
              value={openaiBaseUrl}
              onChange={(e) => {
                setOpenaiBaseUrl(e.target.value);
                setOpenaiPreset(-1);
              }}
              placeholder="https://api.openai.com/v1"
              className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-mono dark:border-slate-600 dark:bg-slate-700"
            />
            <p className="mt-1 text-xs text-slate-400">
              OpenAI 兼容接口的地址。会自动补全 /chat/completions。
            </p>
          </div>

          <div>
            <label className="mb-1.5 block text-sm font-medium">API Key</label>
            <div className="relative">
              <input
                type={showOpenaiKey ? 'text' : 'password'}
                value={openaiApiKey}
                onChange={(e) => setOpenaiApiKey(e.target.value)}
                placeholder="sk-... 或 ollama 留空"
                className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 pr-10 text-sm dark:border-slate-600 dark:bg-slate-700"
              />
              <button
                onClick={() => setShowOpenaiKey(!showOpenaiKey)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400"
              >
                {showOpenaiKey ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-sm font-medium">模型名称</label>
            <input
              type="text"
              value={openaiModel}
              onChange={(e) => {
                setOpenaiModel(e.target.value);
                setOpenaiPreset(-1);
              }}
              placeholder="gpt-4o"
              className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm dark:border-slate-600 dark:bg-slate-700"
            />
            <p className="mt-1 text-xs text-slate-400">
              填写该服务商支持的模型 ID。如 gpt-4o, deepseek-chat, llama3 等。
            </p>
          </div>
        </section>
      )}

      <div className="flex gap-2">
        <button
          onClick={handleSave}
          className="flex items-center gap-2 rounded-lg bg-primary-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-primary-700"
        >
          <Save className="h-4 w-4" />
          {saved ? '已保存！' : '保存配置'}
        </button>
        <p className="text-xs text-slate-400 self-center">
          配置自动保存到浏览器本地
        </p>
      </div>

      {/* Preferences */}
      <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        <h2 className="font-semibold text-lg">偏好设置</h2>

        <div className="flex items-center justify-between">
          <div>
            <div className="font-medium text-sm">语音合成 (TTS)</div>
            <div className="text-xs text-slate-400">在跟读和对话中启用语音朗读</div>
          </div>
          <button
            onClick={() => setTtsEnabled(!ttsEnabled)}
            className={`relative h-6 w-11 rounded-full transition-colors ${
              ttsEnabled ? 'bg-primary-600' : 'bg-slate-300 dark:bg-slate-600'
            }`}
          >
            <div
              className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${
                ttsEnabled ? 'left-6' : 'left-0.5'
              }`}
            />
          </button>
        </div>

        <div className="flex items-center justify-between">
          <div>
            <div className="font-medium text-sm">暗色模式</div>
            <div className="text-xs text-slate-400">切换深色/浅色主题</div>
          </div>
          <button
            onClick={() => {
              const newTheme = theme === 'dark' ? 'light' : 'dark';
              setTheme(newTheme);
              document.documentElement.classList.toggle('dark', newTheme === 'dark');
            }}
            className={`relative h-6 w-11 rounded-full transition-colors ${
              theme === 'dark' ? 'bg-primary-600' : 'bg-slate-300 dark:bg-slate-600'
            }`}
          >
            <div
              className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${
                theme === 'dark' ? 'left-6' : 'left-0.5'
              }`}
            />
          </button>
        </div>
      </section>

      {/* Data management */}
      <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
        <h2 className="font-semibold text-lg">数据管理</h2>
        <p className="text-sm text-slate-500">
          所有训练数据和对话记录都存储在浏览器本地。你可以导出备份或导入恢复。
        </p>
        <div className="flex gap-3">
          <button
            onClick={async () => {
              const { exportAllData } = await import('@/lib/storage/db');
              const json = await exportAllData();
              const blob = new Blob([json], { type: 'application/json' });
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = `speakup-backup-${new Date().toISOString().split('T')[0]}.json`;
              a.click();
              URL.revokeObjectURL(url);
            }}
            className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-600"
          >
            <Save className="h-4 w-4" />
            导出备份
          </button>
          <button
            onClick={handleImport}
            className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-600"
          >
            <Upload className="h-4 w-4" />
            导入备份
          </button>
        </div>
      </section>

      {/* Supported providers info */}
      <section className="rounded-lg bg-slate-50 p-4 text-xs text-slate-500 dark:bg-slate-800/50 dark:text-slate-400">
        <p className="font-medium mb-1">已测试兼容的服务商：</p>
        <p>OpenAI · DeepSeek · Moonshot (Kimi) · Groq · Together AI · Ollama (本地) · 以及所有兼容 /v1/chat/completions 的接口</p>
      </section>
    </div>
  );
}
