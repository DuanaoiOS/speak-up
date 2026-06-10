import { NextRequest } from 'next/server';

export async function POST(req: NextRequest) {
  try {
    const { messages, systemPrompt, model: reqModel } = await req.json();

    if (!messages?.length || !systemPrompt) {
      return Response.json({ error: 'Missing messages or systemPrompt' }, { status: 400 });
    }

    const apiKey = req.headers.get('x-api-key') || process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return Response.json({ error: 'No API key configured. Please add your API key in Settings.' }, { status: 401 });
    }

    const provider = req.headers.get('x-provider') || 'claude';
    const model = reqModel || req.headers.get('x-model');
    const baseUrl = req.headers.get('x-base-url') || '';

    if (provider === 'openai') {
      return streamOpenAICompatible(apiKey, baseUrl, messages, systemPrompt, model);
    }

    return streamClaude(apiKey, messages, systemPrompt, model);
  } catch (err) {
    console.error('Chat API error:', err);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function streamClaude(
  apiKey: string,
  messages: { role: string; content: string }[],
  systemPrompt: string,
  model?: string
) {
  const Anthropic = await import('@anthropic-ai/sdk');
  const client = new Anthropic.default({ apiKey });

  const formattedMessages = messages.map((m) => ({
    role: m.role === 'assistant' ? ('assistant' as const) : ('user' as const),
    content: m.content,
  }));

  const stream = client.messages.stream({
    model: model || 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    system: systemPrompt,
    messages: formattedMessages,
  });

  const encoder = new TextEncoder();

  const readable = new ReadableStream({
    async start(controller) {
      try {
        for await (const event of stream) {
          if (event.type === 'content_block_delta' && 'text' in event.delta) {
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify({ type: 'text_delta', text: event.delta.text })}\n\n`)
            );
          }
        }
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'done' })}\n\n`));
        controller.close();
      } catch (err) {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ type: 'error', message: String(err) })}\n\n`)
        );
        controller.close();
      }
    },
  });

  return new Response(readable, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}

async function streamOpenAICompatible(
  apiKey: string,
  baseUrl: string,
  messages: { role: string; content: string }[],
  systemPrompt: string,
  model?: string
) {
  const apiBase = (baseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
  const endpoint = `${apiBase}/chat/completions`;

  const allMessages = [
    { role: 'system' as const, content: systemPrompt },
    ...messages.map((m) => ({
      role: (m.role === 'assistant' ? 'assistant' : 'user') as 'assistant' | 'user',
      content: m.content,
    })),
  ];

  const resp = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: model || 'gpt-4o',
      messages: allMessages,
      max_tokens: 1024,
      stream: true,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text().catch(() => 'Unknown error');
    return Response.json({ error: `API error (${resp.status}): ${err}` }, { status: resp.status });
  }

  const encoder = new TextEncoder();
  const reader = resp.body!.getReader();

  const readable = new ReadableStream({
    async start(controller) {
      try {
        let buffer = '';
        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'done' })}\n\n`));
            controller.close();
            break;
          }
          buffer += new TextDecoder().decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || ''; // keep incomplete line in buffer
          for (const line of lines) {
            if (!line.startsWith('data: ')) continue;
            const data = line.slice(6).trim();
            if (data === '[DONE]') continue;
            try {
              const parsed = JSON.parse(data);
              const content = parsed.choices?.[0]?.delta?.content;
              if (content) {
                controller.enqueue(
                  encoder.encode(`data: ${JSON.stringify({ type: 'text_delta', text: content })}\n\n`)
                );
              }
            } catch {
              // skip unparseable chunks
            }
          }
        }
      } catch (err) {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ type: 'error', message: String(err) })}\n\n`)
        );
        controller.close();
      }
    },
  });

  return new Response(readable, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}
