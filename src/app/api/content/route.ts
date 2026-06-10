import { NextRequest, NextResponse } from 'next/server';
import { listAvailableDays, parseDayFile } from '@/lib/content/loader';
import path from 'path';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const week = searchParams.get('week');
    const day = searchParams.get('day');

    if (week && day) {
      const filePath = path.join(process.cwd(), `week-${week.padStart(2, '0')}`, `day-${day.padStart(2, '0')}.md`);
      const content = parseDayFile(filePath);
      if (!content) {
        return NextResponse.json({ error: 'Content not found' }, { status: 404 });
      }
      return NextResponse.json(content);
    }

    // List all available days
    const days = listAvailableDays();
    return NextResponse.json({ days });
  } catch (err) {
    console.error('Content API error:', err);
    return NextResponse.json({ error: 'Failed to load content' }, { status: 500 });
  }
}
