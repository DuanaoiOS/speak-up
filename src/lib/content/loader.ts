import fs from 'fs';
import path from 'path';

// Simple markdown section parser for our .md training files

interface ParsedDay {
  week: number;
  day: number;
  title: string;
  topic: string;
  sentenceFrames: {
    pattern: string;
    usage: string;
    example: string;
    substitutions: string[];
  }[];
  collocations: { chinese: string; english: string }[];
  shadowingTopic: string;
  impromptuTopic: string;
  impromptuCueWords: string[];
}

function extractSection(text: string, heading: string): string {
  const regex = new RegExp(`###\\s+${heading}[\\s\\S]*?(?=###\\s+|##\\s+|$)`, 'i');
  const match = text.match(regex);
  return match ? match[0] : '';
}

function extractPattern(section: string): { pattern: string; usage: string; example: string; substitutions: string[] } | null {
  // Pattern is on the first line, after optional "句型 N：" prefix
  const firstLine = section.split('\n')[0] || '';
  const patternMatch = firstLine.match(/^(?:句型\s*\d[：:]\s*)?(.+)$/);
  const usageMatch = section.match(/\*\*用在哪\*\*[：:]\s*(.+?)(?=\n|$)/);
  const exampleMatch = section.match(/\*\*例句\*\*[：:]\s*(.+?)(?=\n|$)/);

  if (!patternMatch || !patternMatch[1].trim()) return null;

  const substitutions: string[] = [];
  // Match numbered list items, optionally with bold markers
  const subRegex = /^\d+\.\s+(?:\*\*)?(.+?)(?:\*\*\s*)?$/gm;
  let m: RegExpExecArray | null;
  while ((m = subRegex.exec(section)) !== null) {
    const item = m[1].trim();
    // Skip lines that are clearly not substitution items
    if (item && !item.startsWith('#') && !item.startsWith('**') && item.length > 5) {
      substitutions.push(item);
    }
  }

  // Clean up the pattern: remove markdown heading markers and "句型 N：" prefix
  let pattern = patternMatch[1].trim();
  pattern = pattern.replace(/^#+\s*/, '');
  pattern = pattern.replace(/^句型\s*(?:\d+)?[：:]\s*/, '');

  return {
    pattern,
    usage: usageMatch?.[1]?.trim() || '',
    example: exampleMatch?.[1]?.trim() || '',
    substitutions: substitutions.slice(0, 5),
  };
}

function extractCollocations(section: string): { chinese: string; english: string }[] {
  const result: { chinese: string; english: string }[] = [];
  const rowRegex = /\|\s*(.+?)\s*\|\s*(.+?)\s*\|/g;
  let m: RegExpExecArray | null;
  while ((m = rowRegex.exec(section)) !== null) {
    const left = m[1].trim();
    const right = m[2].trim();
    // Skip header rows
    if (left === '中文' || left === '英文' || left.startsWith('-') || left.startsWith('#')) continue;
    if (left && right) {
      result.push({ chinese: left, english: right });
    }
  }
  return result;
}

function findShadowingTopic(text: string): string {
  const match = text.match(/\*\*YouTube\s*搜索\*\*[：:]\s*(`.+?`|".+?"|.+?)(?=\n|$)/i);
  return match ? match[1].replace(/[`"]/g, '').trim() : '';
}

function findImpromptuTopic(text: string): { topic: string; cueWords: string[] } {
  const topicMatch = text.match(/\*\*话题\*\*[：:]\s*(.+?)(?=\n|$)/i);
  const topic = topicMatch?.[1]?.trim() || '';

  const cueWords: string[] = [];
  const cueSection = text.match(/提示词[：:]\s*([\s\S]*?)(?=\*\*开始\*\*|\*\*准备\*\*|$)/i);
  if (cueSection) {
    const wordRegex = /[-•]\s+(.+?)(?=\n|$)/g;
    let m: RegExpExecArray | null;
    while ((m = wordRegex.exec(cueSection[0])) !== null) {
      cueWords.push(m[1].trim().replace(/\*\*/g, ''));
    }
  }

  return { topic, cueWords };
}

export function parseDayFile(filePath: string): ParsedDay | null {
  try {
    const text = fs.readFileSync(filePath, 'utf-8');

    // Extract title
    const titleMatch = text.match(/#\s+Week\s+(\d+)\s+Day\s+(\d+)[：:]\s*(.+)/i);
    if (!titleMatch) return null;

    const week = parseInt(titleMatch[1]);
    const day = parseInt(titleMatch[2]);
    const title = titleMatch[3].trim();

    // Extract topic subtitle
    const topicMatch = text.match(/\*\*主题[：:]\s*(.+?)\*\*/i);
    const topic = topicMatch?.[1]?.trim() || '';

    // Extract sentence frames
    const framesSection = text.match(/##\s*一、句型框架[\s\S]*?(?=##\s*二、|$)/i);
    const sentenceFrames: ParsedDay['sentenceFrames'] = [];
    if (framesSection) {
      const frameBlocks = framesSection[0].split(/###\s+句型\s*\d/).slice(1);
      for (const block of frameBlocks) {
        const frame = extractPattern('### 句型' + block);
        if (frame) sentenceFrames.push(frame);
      }
    }

    // Extract collocations
    const collocSection = text.match(/##\s*二、搭配爆破[\s\S]*?(?=##\s*三、|$)/i);
    const collocations = collocSection ? extractCollocations(collocSection[0]) : [];

    // Shadowing topic
    const shadowingTopic = findShadowingTopic(text);

    // Impromptu topic
    const impromptu = findImpromptuTopic(text);

    return {
      week,
      day,
      title,
      topic,
      sentenceFrames,
      collocations,
      shadowingTopic,
      impromptuTopic: impromptu.topic,
      impromptuCueWords: impromptu.cueWords,
    };
  } catch {
    return null;
  }
}

export function listAvailableDays(): { week: number; day: number; title: string }[] {
  const result: { week: number; day: number; title: string }[] = [];
  const rootDir = process.cwd();

  const weekDirs = fs.readdirSync(rootDir).filter((f) => f.startsWith('week-'));
  for (const dir of weekDirs) {
    const weekNum = parseInt(dir.replace('week-', ''));
    const dirPath = path.join(rootDir, dir);
    const files = fs.readdirSync(dirPath).filter((f) => f.endsWith('.md'));
    for (const file of files) {
      const dayMatch = file.match(/day-(\d+)/);
      if (!dayMatch) continue;
      const dayNum = parseInt(dayMatch[1]);
      // Quick title extraction
      const content = fs.readFileSync(path.join(dirPath, file), 'utf-8');
      const titleMatch = content.match(/#\s+Week\s+\d+\s+Day\s+\d+[：:]\s*(.+)/i);
      result.push({
        week: weekNum,
        day: dayNum,
        title: titleMatch?.[1]?.trim() || `Day ${dayNum}`,
      });
    }
  }

  return result.sort((a, b) => a.week - b.week || a.day - b.day);
}
