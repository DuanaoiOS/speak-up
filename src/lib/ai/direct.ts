/**
 * Client-side AI direct calls — for Capacitor/static export mode.
 * WKWebView has no CORS restrictions, so we can call AI APIs directly.
 */
import Anthropic from '@anthropic-ai/sdk';

export interface AIConfig {
  provider: 'claude' | 'openai';
  apiKey: string;
  baseUrl?: string;
  model?: string;
}

export interface StreamChunk {
  type: 'text_delta' | 'error' | 'done';
  text?: string;
  message?: string;
}

// ─── Streaming Chat ────────────────────────────────────────────

export async function* streamChatDirect(
  messages: { role: string; content: string }[],
  systemPrompt: string,
  config: AIConfig
): AsyncGenerator<StreamChunk> {
  if (config.provider === 'openai') {
    yield* streamOpenAIDirect(messages, systemPrompt, config);
  } else {
    yield* streamClaudeDirect(messages, systemPrompt, config);
  }
}

async function* streamClaudeDirect(
  messages: { role: string; content: string }[],
  systemPrompt: string,
  config: AIConfig
): AsyncGenerator<StreamChunk> {
  try {
    const client = new Anthropic({ apiKey: config.apiKey, dangerouslyAllowBrowser: true });

    const stream = client.messages.stream({
      model: config.model || 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: systemPrompt,
      messages: messages.map((m) => ({
        role: m.role === 'assistant' ? 'assistant' as const : 'user' as const,
        content: m.content,
      })),
    });

    for await (const event of stream) {
      if (event.type === 'content_block_delta' && 'text' in event.delta) {
        yield { type: 'text_delta', text: event.delta.text };
      }
    }
    yield { type: 'done' };
  } catch (err) {
    yield { type: 'error', message: String(err) };
  }
}

async function* streamOpenAIDirect(
  messages: { role: string; content: string }[],
  systemPrompt: string,
  config: AIConfig
): AsyncGenerator<StreamChunk> {
  const baseUrl = (config.baseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
  const endpoint = `${baseUrl}/chat/completions`;

  try {
    const resp = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({
        model: config.model || 'gpt-4o',
        messages: [
          { role: 'system', content: systemPrompt },
          ...messages.map((m) => ({
            role: m.role === 'assistant' ? 'assistant' : 'user',
            content: m.content,
          })),
        ],
        max_tokens: 1024,
        stream: true,
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => 'Unknown error');
      yield { type: 'error', message: `API error (${resp.status}): ${errText}` };
      return;
    }

    const reader = resp.body!.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const data = line.slice(6).trim();
        if (data === '[DONE]') continue;
        try {
          const parsed = JSON.parse(data);
          const content = parsed.choices?.[0]?.delta?.content;
          if (content) yield { type: 'text_delta', text: content };
        } catch {}
      }
    }
    yield { type: 'done' };
  } catch (err) {
    yield { type: 'error', message: String(err) };
  }
}

// ─── Generate Content ──────────────────────────────────────────

export async function generateContentDirect(
  systemPrompt: string,
  userPrompt: string,
  config: AIConfig
): Promise<string> {
  if (config.provider === 'openai') {
    const baseUrl = (config.baseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
    const resp = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({
        model: config.model || 'gpt-4o',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        max_tokens: 4096,
      }),
    });
    if (!resp.ok) throw new Error(`API error (${resp.status})`);
    const data = await resp.json();
    return data.choices?.[0]?.message?.content || '';
  }

  // Claude
  const client = new Anthropic({ apiKey: config.apiKey, dangerouslyAllowBrowser: true });
  const resp = await client.messages.create({
    model: config.model || 'claude-sonnet-4-20250514',
    max_tokens: 4096,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });
  return resp.content
    .filter((block) => block.type === 'text')
    .map((block) => (block as { type: 'text'; text: string }).text)
    .join('');
}

// ─── Feedback ──────────────────────────────────────────────────

export async function getFeedbackDirect(
  systemPrompt: string,
  userPrompt: string,
  config: AIConfig
): Promise<string> {
  if (config.provider === 'openai') {
    const baseUrl = (config.baseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
    const resp = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({
        model: config.model || 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        max_tokens: 1024,
      }),
    });
    if (!resp.ok) throw new Error(`API error (${resp.status})`);
    const data = await resp.json();
    return data.choices?.[0]?.message?.content || '';
  }

  const client = new Anthropic({ apiKey: config.apiKey, dangerouslyAllowBrowser: true });
  const resp = await client.messages.create({
    model: config.model || 'claude-haiku-4-20250514',
    max_tokens: 1024,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });
  return resp.content
    .filter((block) => block.type === 'text')
    .map((block) => (block as { type: 'text'; text: string }).text)
    .join('');
}
