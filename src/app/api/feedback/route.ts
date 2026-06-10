import { NextRequest } from 'next/server';
import { FEEDBACK_PROMPT } from '@/lib/ai/prompts';

export async function POST(req: NextRequest) {
  try {
    const { transcript, context } = await req.json();

    if (!transcript) {
      return Response.json({ error: 'Missing transcript' }, { status: 400 });
    }

    const apiKey = req.headers.get('x-api-key') || process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return Response.json({ error: 'No API key configured' }, { status: 401 });
    }

    const provider = req.headers.get('x-provider') || 'claude';
    const model = req.headers.get('x-model') || undefined;
    const baseUrl = req.headers.get('x-base-url') || '';

    const userPrompt = buildFeedbackPrompt(transcript, context);

    let text: string;
    if (provider === 'openai') {
      text = await feedbackWithOpenAI(apiKey, baseUrl, userPrompt, model);
    } else {
      text = await feedbackWithClaude(apiKey, userPrompt, model);
    }

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const data = jsonMatch
      ? JSON.parse(jsonMatch[0])
      : { feedback: text, corrections: [], fluencyAssessment: { level: 'developing', strengths: [], areasToWorkOn: [] }, vocabularySuggestions: [], nextFocus: '' };

    return Response.json(data);
  } catch (err) {
    console.error('Feedback API error:', err);
    return Response.json({ error: 'Failed to generate feedback' }, { status: 500 });
  }
}

function buildFeedbackPrompt(transcript: string, context: { topic: string; targetFrames: string[] }): string {
  return `The student was practicing: ${context.topic}
Target sentence frames: ${context.targetFrames.join(', ')}

Student's transcript: "${transcript}"

Provide feedback as a JSON object with this structure:
{
  "feedback": "overall encouraging feedback paragraph in Chinese",
  "corrections": [
    {
      "original": "what the student said",
      "suggestion": "more natural way to say it",
      "explanation": "why this is better (in Chinese)"
    }
  ],
  "fluencyAssessment": {
    "level": "beginner|developing|confident",
    "strengths": ["strength 1", "strength 2"],
    "areasToWorkOn": ["area 1", "area 2"]
  },
  "vocabularySuggestions": [
    { "word": "useful word", "context": "how to use it" }
  ],
  "nextFocus": "specific suggestion for next practice"
}`;
}

async function feedbackWithClaude(apiKey: string, userPrompt: string, model?: string): Promise<string> {
  const Anthropic = await import('@anthropic-ai/sdk');
  const client = new Anthropic.default({ apiKey });

  const response = await client.messages.create({
    model: model || 'claude-haiku-4-20250514',
    max_tokens: 1024,
    system: FEEDBACK_PROMPT,
    messages: [{ role: 'user', content: userPrompt }],
  });

  return response.content
    .filter((block) => block.type === 'text')
    .map((block) => (block as { type: 'text'; text: string }).text)
    .join('');
}

async function feedbackWithOpenAI(
  apiKey: string,
  baseUrl: string,
  userPrompt: string,
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
      model: model || 'gpt-4o-mini',
      messages: [
        { role: 'system', content: FEEDBACK_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      max_tokens: 1024,
      temperature: 0.7,
    }),
  });

  if (!resp.ok) {
    throw new Error(`OpenAI API error (${resp.status})`);
  }

  const data = await resp.json();
  return data.choices?.[0]?.message?.content || '';
}
