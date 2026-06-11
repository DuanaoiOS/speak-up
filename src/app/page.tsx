'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useStoryStore } from '@/stores/storyStore';
import { useSettingsStore } from '@/stores/settingsStore';
import { HONY_STORY_PROMPT } from '@/lib/ai/prompts';
import { saveStory, getAllStories } from '@/lib/storage/db';
import type { Story } from '@/types/story';
import { BookOpen, Sparkles, ChevronRight, Languages, Brain, Library } from 'lucide-react';
import type { AIConfig } from '@/lib/ai/direct';

export default function HomePage() {
  const { stories, addStory, loading, setLoading } = useStoryStore();
  const { provider, getActiveApiKey, getActiveBaseUrl, getActiveModel } = useSettingsStore();
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    loadStories();
  }, []);

  async function loadStories() {
    setLoading(true);
    try {
      const saved = await getAllStories();
      if (saved.length > 0) {
        useStoryStore.getState().setStories(saved);
        setLoading(false);
        return;
      }
      // First launch: import built-in stories
      const { BUILTIN_STORIES } = await import('@/data/builtin-stories');
      for (const story of BUILTIN_STORIES) {
        await saveStory(story);
        useStoryStore.getState().addStory(story);
      }
    } catch {}
    setLoading(false);
  }

  async function generateStory() {
    const apiKey = getActiveApiKey();
    if (!apiKey) {
      setError('请先在设置中配置 API Key');
      return;
    }

    setGenerating(true);
    setError('');

    try {
      const config: AIConfig = {
        provider,
        apiKey,
        baseUrl: getActiveBaseUrl(),
        model: getActiveModel(),
      };

      const { generateContentDirect } = await import('@/lib/ai/direct');
      const raw = await generateContentDirect(HONY_STORY_PROMPT, 'Generate a new HONY-style story.', config);

      // Extract JSON
      const match = raw.match(/\{[\s\S]*\}/);
      const data = match ? JSON.parse(match[0]) : null;
      if (!data) throw new Error('Failed to parse story');

      const story: Story = {
        id: Date.now().toString(),
        title: data.title || 'Untitled Story',
        content: data.content || '',
        source: data.source || 'AI-generated HONY style',
        vocabulary: data.vocabulary || [],
        patterns: data.patterns || [],
        keywords: data.keywords || [],
        quiz: data.quiz || [],
        createdAt: Date.now(),
      };

      await saveStory(story);
      addStory(story);
    } catch (err) {
      setError('生成失败，请重试');
      console.error(err);
    }
    setGenerating(false);
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">SpeakUp</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">Humans of New York 故事学英语</p>
        </div>
      </div>

      {/* Generate button */}
      <button
        onClick={generateStory}
        disabled={generating}
        className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-primary-500 to-primary-600 p-4 text-white shadow-sm transition-transform active:scale-95 disabled:opacity-60"
      >
        {generating ? (
          <>
            <div className="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent" />
            AI 正在生成故事...
          </>
        ) : (
          <>
            <Sparkles className="h-5 w-5" />
            获取新故事
          </>
        )}
      </button>

      {error && (
        <div className="rounded-lg bg-red-50 px-4 py-2 text-sm text-red-600 dark:bg-red-900/20 dark:text-red-400">
          {error}
        </div>
      )}

      {/* Story list */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" />
        </div>
      ) : stories.length === 0 ? (
        <div className="py-16 text-center">
          <Library className="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600" />
          <p className="mt-4 text-slate-500 dark:text-slate-400">还没有故事</p>
          <p className="text-sm text-slate-400 dark:text-slate-500">点击上方按钮，AI 为你生成第一个故事</p>
        </div>
      ) : (
        <div className="space-y-3">
          {stories.map((story) => (
            <Link
              key={story.id}
              href={`/story?id=${story.id}`}
              className="block rounded-xl border border-slate-200 bg-white p-5 transition-shadow hover:shadow-md dark:border-slate-700 dark:bg-slate-800"
            >
              <h3 className="font-semibold text-lg">{story.title}</h3>
              <p className="mt-1 line-clamp-2 text-sm text-slate-500 dark:text-slate-400">
                {story.content.slice(0, 120)}...
              </p>
              <div className="mt-3 flex items-center gap-3 text-xs text-slate-400 dark:text-slate-500">
                <span className="flex items-center gap-1">
                  <BookOpen className="h-3 w-3" />
                  {story.vocabulary.length} 词
                </span>
                <span className="flex items-center gap-1">
                  <Languages className="h-3 w-3" />
                  {story.patterns.length} 句型
                </span>
                <span className="flex items-center gap-1">
                  <Brain className="h-3 w-3" />
                  {story.quiz.length} 题
                </span>
                <span className="ml-auto flex items-center gap-1 text-primary-500">
                  开始 <ChevronRight className="h-3 w-3" />
                </span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
