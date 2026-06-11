# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev       # Start Next.js dev server
npm run build     # Static export build (outputs to out/)
npm run lint      # ESLint via next lint
npx cap sync      # Sync web assets to iOS Capacitor project
npx cap open ios  # Open iOS project in Xcode
```

## Architecture

SpeakUp is an AI-powered English speaking practice app for Chinese CET-6 learners. It uses Next.js 14 App Router with **static export** (`next.config.js` → `output: 'export'`), wrapped by Capacitor for iOS native deployment (WKWebView).

### AI: Dual-call pattern

There are **two paths** to call AI APIs, chosen based on runtime context:

- **Web (dev server / Vercel)**: uses API routes (`/api/chat`, `/api/generate`, `/api/feedback`) as server-side proxies. Client code calls `src/lib/ai/client.ts` which forwards API keys via headers.
- **Capacitor/iOS (WKWebView)**: calls Anthropic/OpenAI APIs directly from the browser since WKWebView has no CORS. Uses `src/lib/ai/direct.ts` (`streamChatDirect`, `generateContentDirect`, `getFeedbackDirect`).

Both providers (Claude and OpenAI-compatible) are supported. Provider config, API keys, and model selection are managed in `src/stores/settingsStore.ts` with Zustand + localStorage persistence.

### Data flow

All user data lives in **IndexedDB** via `idb-keyval` (`src/lib/storage/db.ts`). Zustand stores (`src/stores/`) hold in-memory state; some stores persist to localStorage via Zustand middleware. The stores:

- `settingsStore` — AI provider, API keys, model, TTS toggle, theme. Persisted.
- `storyStore` — Story list, current story, current training step (0-4). In-memory, loaded from DB.
- `chatStore` — Role-play conversations per AI role.
- `trainingStore` — Legacy training session state. Persisted.
- `progressStore` — Streaks, session counts, completed dates. Persisted.
- `reviewStore` — Spaced repetition items (vocab + patterns). Persisted.

### Story learning flow (5 steps)

The core feature: user reads an AI-generated HONY-style story, then progresses through 5 sequential training steps defined in `src/app/story/client.tsx`:

1. **StoryReader** — Text + Web Speech API TTS, sentence-by-sentence highlight
2. **VocabTrainer** — Use each vocab word in a sentence, get AI feedback (`VOCAB_EVAL_PROMPT`)
3. **PatternTrainer** — Practice sentence patterns/idioms, get AI feedback (`PATTERN_EVAL_PROMPT`)
4. **RetellRecorder** — Record oral retelling from keywords, AI evaluates completeness/accuracy
5. **QuizPlayer** — 5-question quiz (comprehension, vocabulary, fill-blank)

Stories can be AI-generated on the home page (calls `generateContentDirect` with `HONY_STORY_PROMPT`) or imported from `src/data/builtin-stories.ts` (10 preloaded stories).

### Speech recognition

`src/lib/speech/recognition.ts` tries the native Capacitor SpeechRecognition plugin (iOS SFSpeechRecognizer) first, then falls back to the Web Speech API. The Capacitor plugin is custom and registered at runtime via `(Capacitor as any).Plugins.SpeechRecognition`.

### Routing

All routes are static-export compatible (no SSR/streaming in the exported build). The app uses `useSearchParams` for query params (e.g., `/story?id=xxx`). Key pages:

- `/` — Home: story list + AI story generation
- `/story` — 5-step story training session
- `/chat` — Role-play AI conversation (interviewer, friend, waiter, debate partner)
- `/review` — Spaced repetition flashcards
- `/progress` — Stats dashboard with heatmap
- `/settings` — AI provider config, TTS, theme, data export/import

### UI patterns

- Tailwind CSS with `primary` color palette (blue), dark mode via `class` strategy
- Mobile-first with bottom tab navigation (`BottomNav.tsx`, hidden on `md+` via CSS)
- Desktop: top header nav (`Header.tsx`). Safe area insets for iOS notch.
- `cn()` utility from `src/lib/utils/cn.ts` merges Tailwind classes with `clsx` + `tailwind-merge`
- Story content uses a serif font stack (`.story-text` in globals.css)

### Content generation (external script)

`scripts/generate-stories.mjs` batch-generates HONY-style stories via the Anthropic API and outputs JSON for manual integration into `builtin-stories.ts`. Run with `ANTHROPIC_API_KEY` env var.

### Capacitor/iOS

Capacitor wraps the static export (`out/` directory). Native iOS code is in `ios/`. The app uses a custom SpeechRecognition Capacitor plugin for native iOS speech-to-text.
