import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const apiKey = process.env.ANTHROPIC_API_KEY;

if (!apiKey) {
  console.error('Set ANTHROPIC_API_KEY environment variable');
  process.exit(1);
}

const HONY_PROMPT = `You are creating Humans of New York style stories for English learners.

Each story must be a COMPLETE JSON object with this EXACT structure:
{
  "id": "builtin-N",
  "title": "short descriptive title",
  "content": "the story, 150-300 words, first person, emotional, authentic",
  "vocabulary": [
    { "word": "word", "context": "sentence from story", "definition": "Chinese meaning", "exampleSentence": "another example" }
  ],
  "patterns": [
    { "pattern": "pattern text", "fromStory": "sentence from story", "explanation": "Chinese grammar/usage explanation", "practicePrompts": ["prompt 1", "prompt 2"] }
  ],
  "keywords": ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"],
  "quiz": [
    { "type": "comprehension", "question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 0, "explanation": "Chinese explanation" },
    { "type": "comprehension", "question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 1, "explanation": "Chinese explanation" },
    { "type": "vocabulary", "question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 2, "explanation": "Chinese explanation" },
    { "type": "fill-blank", "question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 0, "explanation": "Chinese explanation" },
    { "type": "vocabulary", "question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 1, "explanation": "Chinese explanation" }
  ]
}

CRITICAL RULES:
- Return ONLY valid JSON, no markdown, no extra text
- vocabulary: exactly 4-6 items
- patterns: exactly 2-3 items
- keywords: exactly 8 items
- quiz: exactly 5 questions (2 comprehension, 2 vocabulary, 1 fill-blank)
- Make stories genuinely moving — real human experiences
- Diverse topics: love, loss, family, career change, immigration, childhood, aging, unexpected kindness, regret, hope
- Every story in first person, colloquial spoken English`;

async function generateStory(index) {
  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      system: HONY_PROMPT,
      messages: [{ role: 'user', content: `Generate story #${index}. Make it unique and emotionally powerful.` }],
    }),
  });

  const data = await resp.json();
  const text = data.content?.filter((c) => c.type === 'text').map((c) => c.text).join('') || '';

  // Extract JSON
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error(`No JSON in response: ${text.slice(0, 200)}`);

  const story = JSON.parse(match[0]);
  story.id = `builtin-${index}`;
  story.source = 'Humans of New York';
  story.createdAt = Date.now() - (50 - index) * 1000;
  return story;
}

async function main() {
  const startIndex = 6;  // We already have 5 stories
  const count = 45;
  const stories = [];

  for (let i = startIndex; i < startIndex + count; i++) {
    console.log(`Generating story ${i}/${startIndex + count - 1}...`);
    try {
      const story = await generateStory(i);
      stories.push(story);
      console.log(`  ✓ ${story.title}`);
    } catch (err) {
      console.error(`  ✗ Failed: ${err.message}`);
    }
    // Rate limiting
    await new Promise((r) => setTimeout(r, 1000));
  }

  // Output as JSON for manual integration
  const outputPath = path.join(__dirname, '..', 'generated-stories.json');
  fs.writeFileSync(outputPath, JSON.stringify(stories, null, 2));
  console.log(`\nDone! Generated ${stories.length} stories to generated-stories.json`);
}

main().catch(console.error);
