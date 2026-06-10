import { NextRequest } from 'next/server';
import { CONTENT_GENERATION_PROMPT } from '@/lib/ai/prompts';

export async function POST(req: NextRequest) {
  try {
    const { systemPrompt, userPrompt, model: reqModel } = await req.json();

    if (!userPrompt) {
      return Response.json({ error: 'Missing userPrompt' }, { status: 400 });
    }

    const apiKey = req.headers.get('x-api-key') || process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return Response.json({ error: 'No API key configured' }, { status: 401 });
    }

    const provider = req.headers.get('x-provider') || 'claude';
    const model = reqModel || req.headers.get('x-model') || undefined;
    const baseUrl = req.headers.get('x-base-url') || '';
    const finalPrompt = `${systemPrompt || CONTENT_GENERATION_PROMPT}\n\n${userPrompt}`;

    let text: string;
    if (provider === 'openai') {
      text = await generateWithOpenAI(apiKey, baseUrl, finalPrompt, model);
    } else {
      text = await generateWithClaude(apiKey, finalPrompt, model);
    }

    // Extract JSON from response
    let jsonStr = text;
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      jsonStr = jsonMatch[0];
    }

    const data = JSON.parse(jsonStr);
    return Response.json(data);
  } catch (err) {
    console.error('Generate API error:', err);
    return Response.json({ error: 'Failed to generate content' }, { status: 500 });
  }
}

async function generateWithClaude(apiKey: string, systemPrompt: string, model?: string): Promise<string> {
  const Anthropic = await import('@anthropic-ai/sdk');
  const client = new Anthropic.default({ apiKey });

  const response = await client.messages.create({
    model: model || 'claude-sonnet-4-20250514',
    max_tokens: 4096,
    system: systemPrompt,
    messages: [
      {
        role: 'user',
        content: 'Generate the requested content as valid JSON. Only output the JSON object, no other text.',
      },
    ],
  });

  return response.content
    .filter((block) => block.type === 'text')
    .map((block) => (block as { type: 'text'; text: string }).text)
    .join('');
}

async function generateWithOpenAI(
  apiKey: string,
  baseUrl: string,
  systemPrompt: string,
  model?: string
): Promise<string> {
  const apiBase = (baseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
  const endpoint = `${apiBase}/chat/completions`;

  const resp = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: model || 'gpt-4o',
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: 'Generate the requested content as valid JSON. Only output the JSON object, no other text.',
        },
      ],
      max_tokens: 4096,
      temperature: 0.7,
    }),
  });

  if (!resp.ok) {
    throw new Error(`OpenAI API error (${resp.status})`);
  }

  const data = await resp.json();
  return data.choices?.[0]?.message?.content || '';
}
