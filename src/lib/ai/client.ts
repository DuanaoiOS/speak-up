import type { ZodSchema } from 'zod';

export type AIProvider = 'claude' | 'openai';

export interface AIConfig {
  apiKey: string;
  provider: AIProvider;
  baseUrl?: string;
  model?: string;
}

export interface ChatOptions {
  systemPrompt: string;
  model?: string;
  maxTokens?: number;
}

export interface GenerateOptions {
  systemPrompt: string;
  schema: ZodSchema;
  model?: string;
  maxTokens?: number;
}

export interface StreamChunk {
  type: 'text_delta' | 'error' | 'done';
  text?: string;
  message?: string;
}

function getHeaders(config: AIConfig): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    'x-api-key': config.apiKey,
    'x-provider': config.provider,
    'x-base-url': config.baseUrl || '',
    'x-model': config.model || '',
  };
}

// Client-side: call our own API routes (protects API key)
// Server-side: call AI APIs directly

export async function streamChat(
  messages: { role: string; content: string }[],
  options: ChatOptions,
  config: AIConfig
): Promise<ReadableStream<Uint8Array>> {
  const response = await fetch('/api/chat', {
    method: 'POST',
    headers: getHeaders(config),
    body: JSON.stringify({
      messages,
      systemPrompt: options.systemPrompt,
      model: options.model,
      maxTokens: options.maxTokens,
    }),
  });

  if (!response.ok) {
    const err = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(err.error || `API error: ${response.status}`);
  }

  return response.body!;
}

export async function generateContent<T>(
  contentType: string,
  options: GenerateOptions & { userPrompt: string },
  config: AIConfig
): Promise<T> {
  const response = await fetch('/api/generate', {
    method: 'POST',
    headers: getHeaders(config),
    body: JSON.stringify({
      contentType,
      systemPrompt: options.systemPrompt,
      userPrompt: options.userPrompt,
      model: options.model,
      maxTokens: options.maxTokens,
    }),
  });

  if (!response.ok) {
    const err = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(err.error || `API error: ${response.status}`);
  }

  const data = await response.json();
  return options.schema.parse(data) as T;
}

export async function getFeedback(
  transcript: string,
  context: { topic: string; targetFrames: string[] },
  config: AIConfig
): Promise<{
  feedback: string;
  corrections: { original: string; suggestion: string; explanation: string }[];
  fluencyAssessment: { level: string; strengths: string[]; areasToWorkOn: string[] };
  vocabularySuggestions: { word: string; context: string }[];
  nextFocus: string;
}> {
  const response = await fetch('/api/feedback', {
    method: 'POST',
    headers: getHeaders(config),
    body: JSON.stringify({ transcript, context }),
  });

  if (!response.ok) {
    const err = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(err.error || `API error: ${response.status}`);
  }

  return response.json();
}
