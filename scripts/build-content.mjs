import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const publicContent = path.join(root, 'public', 'content');
fs.mkdirSync(publicContent, { recursive: true });

function parseDayFile(filePath) {
  const text = fs.readFileSync(filePath, 'utf-8');
  const titleMatch = text.match(/#\s+Week\s+(\d+)\s+Day\s+(\d+)[：:]\s*(.+)/i);
  if (!titleMatch) return null;
  const week = parseInt(titleMatch[1]);
  const day = parseInt(titleMatch[2]);
  const title = titleMatch[3].trim();

  // Sentence frames
  const framesSection = text.match(/##\s*一、句型框架[\s\S]*?(?=##\s*二、|$)/i);
  const frames = [];
  if (framesSection) {
    const blocks = framesSection[0].split(/###\s+句型\s*\d/).slice(1);
    for (const block of blocks) {
      const firstLine = block.split('\n')[0] || '';
      const patternMatch = firstLine.match(/^(?:#+\s*)?(?:句型\s*(?:\d+)?[：:]\s*)?(.+)$/);
      const usageMatch = block.match(/\*\*用在哪\*\*[：:]\s*(.+?)(?=\n|$)/);
      const exampleMatch = block.match(/\*\*例句\*\*[：:]\s*(.+?)(?=\n|$)/);
      if (!patternMatch || !patternMatch[1].trim()) continue;
      let pattern = patternMatch[1].trim();
      pattern = pattern.replace(/^#+\s*/, '').replace(/^句型\s*(?:\d+)?[：:]\s*/, '');
      const subs = [];
      const subRegex = /^\d+\.\s+(?:\*\*)?(.+?)(?:\*\*\s*)?$/gm;
      let m;
      while ((m = subRegex.exec(block)) !== null) {
        const item = m[1].trim();
        if (item && !item.startsWith('#') && !item.startsWith('**') && item.length > 5) subs.push(item);
      }
      frames.push({ pattern, usage: usageMatch?.[1]?.trim() || '', example: exampleMatch?.[1]?.trim() || '', substitutions: subs.slice(0, 5) });
    }
  }

  // Collocations
  const collocSection = text.match(/##\s*二、搭配爆破[\s\S]*?(?=##\s*三、|$)/i);
  const collocations = [];
  if (collocSection) {
    const rowRegex = /\|\s*(.+?)\s*\|\s*(.+?)\s*\|/g;
    let m;
    while ((m = rowRegex.exec(collocSection[0])) !== null) {
      const left = m[1].trim(), right = m[2].trim();
      if (left === '中文' || left === '英文' || left.startsWith('-') || left.startsWith('#') || !left || !right) continue;
      collocations.push({ chinese: left, english: right });
    }
  }

  const shadowMatch = text.match(/\*\*YouTube\s*搜索\*\*[：:]\s*(`.+?`|".+?"|.+?)(?=\n|$)/i);
  const topicMatch = text.match(/\*\*话题\*\*[：:]\s*(.+?)(?=\n|$)/i);
  const cueWords = [];
  const cueSection = text.match(/提示词[：:]\s*([\s\S]*?)(?=\*\*开始\*\*|\*\*准备\*\*|$)/i);
  if (cueSection) {
    const wordRegex = /[-•]\s+(.+?)(?=\n|$)/g;
    let m;
    while ((m = wordRegex.exec(cueSection[0])) !== null) cueWords.push(m[1].trim().replace(/\*\*/g, ''));
  }

  return {
    week, day, title,
    sentenceFrames: frames,
    collocations,
    shadowingTopic: shadowMatch ? shadowMatch[1].replace(/[`"]/g, '').trim() : '',
    impromptuTopic: topicMatch?.[1]?.trim() || '',
    impromptuCueWords: cueWords,
  };
}

const manifest = [];
const weekDirs = fs.readdirSync(root).filter(f => f.startsWith('week-'));
for (const dir of weekDirs) {
  const weekNum = parseInt(dir.replace('week-', ''));
  const dirPath = path.join(root, dir);
  const files = fs.readdirSync(dirPath).filter(f => f.endsWith('.md'));
  for (const file of files) {
    const dayMatch = file.match(/day-(\d+)/);
    if (!dayMatch) continue;
    const dayNum = parseInt(dayMatch[1]);
    const parsed = parseDayFile(path.join(dirPath, file));
    if (!parsed) continue;
    const filename = `week-${weekNum}-day-${dayNum}.json`;
    fs.writeFileSync(path.join(publicContent, filename), JSON.stringify(parsed, null, 2));
    manifest.push({ week: weekNum, day: dayNum, title: parsed.title, filename });
  }
}
fs.writeFileSync(path.join(publicContent, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`Built ${manifest.length} content files to public/content/`);
