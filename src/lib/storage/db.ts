import { get, set, del, keys } from 'idb-keyval';
import type { TrainingContent, GeneratedContent } from '@/types/training';
import type { ChatConversation } from '@/types/chat';
import type { ProgressData, SessionRecord } from '@/types/progress';

const STORAGE_PREFIX = {
  trainingContent: 'tc:',
  session: 'session:',
  chat: 'chat:',
  progress: 'progress',
  audio: 'audio:',
} as const;

// Training content
export async function saveTrainingContent(week: number, day: number, content: TrainingContent): Promise<void> {
  await set(`${STORAGE_PREFIX.trainingContent}${week}:${day}`, content);
}

export async function getTrainingContent(week: number, day: number): Promise<TrainingContent | undefined> {
  return get(`${STORAGE_PREFIX.trainingContent}${week}:${day}`);
}

// Session records
export async function saveSession(date: string, record: SessionRecord): Promise<void> {
  await set(`${STORAGE_PREFIX.session}${date}`, record);
}

export async function getSession(date: string): Promise<SessionRecord | undefined> {
  return get(`${STORAGE_PREFIX.session}${date}`);
}

export async function getAllSessions(): Promise<SessionRecord[]> {
  const allKeys = await keys();
  const sessionKeys = allKeys.filter((k) => String(k).startsWith(STORAGE_PREFIX.session));
  const records: SessionRecord[] = [];
  for (const key of sessionKeys) {
    const r = await get(key);
    if (r) records.push(r as SessionRecord);
  }
  return records.sort((a, b) => b.date.localeCompare(a.date));
}

// Chat conversations
export async function saveChatConversation(roleId: string, conv: ChatConversation): Promise<void> {
  await set(`${STORAGE_PREFIX.chat}${roleId}`, conv);
}

export async function getChatConversation(roleId: string): Promise<ChatConversation | undefined> {
  return get(`${STORAGE_PREFIX.chat}${roleId}`);
}

export async function getAllChatConversations(): Promise<Record<string, ChatConversation>> {
  const allKeys = await keys();
  const chatKeys = allKeys.filter((k) => String(k).startsWith(STORAGE_PREFIX.chat));
  const result: Record<string, ChatConversation> = {};
  for (const key of chatKeys) {
    const c = await get(key);
    if (c) {
      const roleId = String(key).replace(STORAGE_PREFIX.chat, '');
      result[roleId] = c as ChatConversation;
    }
  }
  return result;
}

// Progress
export async function saveProgress(data: ProgressData): Promise<void> {
  await set(STORAGE_PREFIX.progress, data);
}

export async function getProgress(): Promise<ProgressData | undefined> {
  return get(STORAGE_PREFIX.progress);
}

// Audio blobs
export async function saveAudio(date: string, blob: Blob): Promise<void> {
  await set(`${STORAGE_PREFIX.audio}${date}`, blob);
}

export async function getAudio(date: string): Promise<Blob | undefined> {
  return get(`${STORAGE_PREFIX.audio}${date}`);
}

// Data export/import
export async function exportAllData(): Promise<string> {
  const allKeys = await keys();
  const data: Record<string, unknown> = {};
  for (const key of allKeys) {
    data[String(key)] = await get(key);
  }
  return JSON.stringify(data, null, 2);
}

export async function importAllData(json: string): Promise<void> {
  const data = JSON.parse(json) as Record<string, unknown>;
  for (const [key, value] of Object.entries(data)) {
    await set(key, value);
  }
}

// ─── Story Storage ─────────────────────────────────────────────

import type { Story, StoryProgress } from '@/types/story';

const STORY_KEY = 'story:';
const STORY_LIST_KEY = 'story:list';

export async function saveStory(story: Story): Promise<void> {
  await set(`${STORY_KEY}${story.id}`, story);
  const list = (await get<string[]>(STORY_LIST_KEY)) || [];
  if (!list.includes(story.id)) {
    list.unshift(story.id);
    await set(STORY_LIST_KEY, list);
  }
}

export async function getStory(id: string): Promise<Story | undefined> {
  return get(`${STORY_KEY}${id}`);
}

export async function getAllStories(): Promise<Story[]> {
  const list = (await get<string[]>(STORY_LIST_KEY)) || [];
  const stories: Story[] = [];
  for (const id of list) {
    const story = await get(`${STORY_KEY}${id}`);
    if (story) stories.push(story as Story);
  }
  return stories.sort((a, b) => b.createdAt - a.createdAt);
}

export async function deleteStory(id: string): Promise<void> {
  await del(`${STORY_KEY}${id}`);
  const list = (await get<string[]>(STORY_LIST_KEY)) || [];
  await set(STORY_LIST_KEY, list.filter((lid) => lid !== id));
}

export async function saveStoryProgress(storyId: string, progress: StoryProgress): Promise<void> {
  await set(`story:progress:${storyId}`, progress);
}

export async function getStoryProgress(storyId: string): Promise<StoryProgress | undefined> {
  return get(`story:progress:${storyId}`);
}
