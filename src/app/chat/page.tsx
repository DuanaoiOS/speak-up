'use client';

import { useState, useRef, useEffect } from 'react';
import { Send, User, Bot, Trash2, Mic, Square } from 'lucide-react';
import { useChatStore } from '@/stores/chatStore';
import { useSettingsStore } from '@/stores/settingsStore';
import { saveChatConversation } from '@/lib/storage/db';
import { isSpeechRecognitionSupported, createSpeechRecognition } from '@/lib/speech/recognition';
import { CHAT_SYSTEM_PROMPTS } from '@/lib/ai/prompts';
import { streamChatDirect } from '@/lib/ai/direct';
import type { AIConfig } from '@/lib/ai/direct';
import type { ChatMessage, AIRole } from '@/types/chat';

const ROLES: { id: AIRole; name: string; icon: string }[] = [
  { id: 'interviewer', name: '面试官', icon: '💼' },
  { id: 'friend', name: '派对朋友', icon: '🎉' },
  { id: 'waiter', name: '餐厅服务员', icon: '🍽️' },
  { id: 'debate_partner', name: '辩论伙伴', icon: '💭' },
];

export default function ChatPage() {
  const { provider, getActiveApiKey, getActiveModel, getActiveBaseUrl } = useSettingsStore();
  const apiKey = getActiveApiKey();
  const model = getActiveModel();
  const baseUrl = getActiveBaseUrl();
  const { conversations, activeRole, setActiveRole, addMessage, isStreaming, setStreaming, loadConversations } =
    useChatStore();

  const [input, setInput] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [interimText, setInterimText] = useState('');
  const [error, setError] = useState('');

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const speechRef = useRef<ReturnType<typeof createSpeechRecognition> | null>(null);

  // Load conversations from storage on mount
  useEffect(() => {
    import('@/lib/storage/db').then(({ getAllChatConversations }) => {
      getAllChatConversations().then((convs) => {
        if (Object.keys(convs).length > 0) {
          loadConversations(convs);
        }
      });
    });
  }, []);

  // Auto-scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [conversations]);

  const messages = activeRole ? conversations[activeRole]?.messages || [] : [];

  function selectRole(role: AIRole) {
    setActiveRole(role);
    setError('');
  }

  async function sendMessage() {
    const text = (input + (interimText ? ' ' + interimText : '')).trim();
    if (!text || !activeRole || isStreaming) return;
    if (!apiKey) {
      setError('请先在设置中配置 API Key');
      return;
    }

    setInput('');
    setInterimText('');
    setError('');

    const userMsg: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      content: text,
      timestamp: Date.now(),
    };
    addMessage(activeRole, userMsg);
    setStreaming(true);

    try {
      const allMessages = [...(conversations[activeRole]?.messages || []), userMsg];
      const aiConfig: AIConfig = {
        provider,
        apiKey,
        baseUrl,
        model,
      };

      let fullContent = '';
      const assistantId = (Date.now() + 1).toString();
      addMessage(activeRole, {
        id: assistantId,
        role: 'assistant',
        content: '',
        timestamp: Date.now(),
      });

      for await (const chunk of streamChatDirect(
        allMessages.map((m) => ({ role: m.role, content: m.content })),
        CHAT_SYSTEM_PROMPTS[activeRole],
        aiConfig
      )) {
        if (chunk.type === 'text_delta') {
          fullContent += chunk.text!;
          const conv = useChatStore.getState().conversations[activeRole];
          if (conv) {
            const msgs = [...conv.messages];
            const lastIdx = msgs.length - 1;
            if (lastIdx >= 0 && msgs[lastIdx].id === assistantId) {
              msgs[lastIdx] = { ...msgs[lastIdx], content: fullContent };
              loadConversations({
                ...useChatStore.getState().conversations,
                [activeRole]: { ...conv, messages: msgs },
              });
            }
          }
        } else if (chunk.type === 'error') {
          setError(chunk.message || '请求失败');
        }
      }

      // Save to storage
      const finalConv = useChatStore.getState().conversations[activeRole];
      if (finalConv) {
        saveChatConversation(activeRole, finalConv);
      }
    } catch (err) {
      setError(String(err));
    }
    setStreaming(false);
  }

  function toggleListening() {
    if (isListening) {
      speechRef.current?.stop();
      setIsListening(false);
      return;
    }

    if (!isSpeechRecognitionSupported()) {
      setError('您的浏览器不支持语音识别。请使用 Chrome 或 Edge。');
      return;
    }

    const speech = createSpeechRecognition();
    speechRef.current = speech;

    speech.onResult((result) => {
      setInterimText(result.transcript);
      if (result.isFinal) {
        setInput((prev) => prev + ' ' + result.transcript);
        setInterimText('');
        setIsListening(false);
        speech.stop();
      }
    });

    speech.onError((err) => {
      setError(err);
      setIsListening(false);
    });

    speech.start();
    setIsListening(true);
  }

  function clearChat() {
    if (!activeRole) return;
    useChatStore.getState().clearConversation(activeRole);
  }

  if (!activeRole) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold">AI 对话陪练</h1>
        <p className="text-slate-500 dark:text-slate-400">选择一个场景，开始练习口语对话。</p>
        <div className="grid gap-3 sm:grid-cols-2">
          {ROLES.map((role) => (
            <button
              key={role.id}
              onClick={() => selectRole(role.id)}
              className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white p-5 text-left transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
            >
              <span className="text-3xl">{role.icon}</span>
              <div>
                <div className="font-semibold">{role.name}</div>
                <div className="text-sm text-slate-500 dark:text-slate-400">
                  {role.id === 'interviewer' && '练习面试英语'}
                  {role.id === 'friend' && '轻松社交聊天'}
                  {role.id === 'waiter' && '餐厅点餐场景'}
                  {role.id === 'debate_partner' && '表达和捍卫观点'}
                </div>
              </div>
            </button>
          ))}
        </div>
      </div>
    );
  }

  const role = ROLES.find((r) => r.id === activeRole);

  return (
    <div className="fixed inset-0 top-[3.5rem] bottom-16 z-0 flex flex-col bg-white pb-safe dark:bg-slate-900 md:bottom-0 md:static md:z-auto md:h-auto md:min-h-[70vh]" style={{ top: 'calc(3.5rem + env(safe-area-inset-top, 0px))', bottom: 'calc(4rem + env(safe-area-inset-bottom, 0px))' }}>
      {/* Chat header */}
      <div className="flex items-center justify-between border-b border-slate-200 px-1 pb-3 dark:border-slate-700 shrink-0">
        <div className="flex items-center gap-2">
          <button onClick={() => setActiveRole(null as any)} className="text-sm text-slate-500 hover:text-slate-700 dark:text-slate-400">← 返回</button>
          <span className="text-lg">{role?.icon}</span>
          <span className="font-semibold text-sm">{role?.name}</span>
        </div>
        <button onClick={clearChat} className="rounded p-1.5 text-slate-400 hover:text-red-500" title="清除对话"><Trash2 className="h-4 w-4" /></button>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto py-3 space-y-3">
        {messages.length === 0 && (
          <div className="text-center text-slate-400 py-12">
            <p>开始对话吧！AI 会以 {role?.name} 的身份跟你聊天。</p>
            <p className="text-sm mt-1">你可以打字，也可以按住麦克风说话。</p>
          </div>
        )}
        {messages.map((msg) => (
          <div key={msg.id} className={`flex gap-2 ${msg.role === 'user' ? 'justify-end' : ''}`}>
            {msg.role === 'assistant' && (
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-primary-100 text-primary-600 dark:bg-primary-900/30 shrink-0"><Bot className="h-3.5 w-3.5" /></div>
            )}
            <div className={`max-w-[80%] rounded-xl px-3.5 py-2.5 text-sm leading-relaxed ${msg.role === 'user' ? 'bg-primary-600 text-white' : 'bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-200'}`}>
              {msg.content || (msg.role === 'assistant' && isStreaming ? '...' : '')}
            </div>
            {msg.role === 'user' && (
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-slate-200 dark:bg-slate-700 shrink-0"><User className="h-3.5 w-3.5 text-slate-500" /></div>
            )}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Error */}
      {error && <div className="shrink-0 rounded-lg bg-red-50 px-3 py-1.5 text-xs text-red-600 dark:bg-red-900/20 dark:text-red-400">{error}</div>}

      {/* Input — fixed at bottom */}
      <div className="shrink-0 border-t border-slate-200 bg-white pt-2.5 pb-3 dark:border-slate-700 dark:bg-slate-900" style={{ paddingBottom: 'calc(0.75rem + env(safe-area-inset-bottom))' }}>
        {interimText && <div className="mb-1 text-xs italic text-slate-400">{interimText}</div>}
        <div className="flex items-center gap-1.5">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); } }}
            placeholder={isListening ? '正在聆听...' : '输入消息...'}
            rows={1}
            className="flex-1 rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm resize-none focus:border-primary-400 focus:outline-none dark:border-slate-600 dark:bg-slate-800"
          />
          <button
            onTouchStart={(e) => { e.preventDefault(); if (!isListening) toggleListening(); }}
            onTouchEnd={(e) => { e.preventDefault(); if (isListening) toggleListening(); }}
            onMouseDown={() => { if (!isListening) toggleListening(); }}
            onMouseUp={() => { if (isListening) toggleListening(); }}
            className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl select-none touch-none transition-colors ${isListening ? 'bg-red-500 text-white animate-pulse' : 'bg-slate-100 text-slate-600 active:bg-slate-200 dark:bg-slate-700 dark:text-slate-300'}`}
            style={{ WebkitTouchCallout: 'none', WebkitUserSelect: 'none', userSelect: 'none' }}
          >
            {isListening ? <Square className="h-4 w-4" /> : <Mic className="h-4 w-4" />}
          </button>
          <button
            onClick={sendMessage}
            disabled={!input.trim() || isStreaming}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-40"
          >
            <Send className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
