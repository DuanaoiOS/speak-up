'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { MessageCircle, Dumbbell, BarChart3, Settings, Brain } from 'lucide-react';
import { cn } from '@/lib/utils/cn';

const navItems = [
  { href: '/', label: '训练', icon: Dumbbell },
  { href: '/chat', label: '对话', icon: MessageCircle },
  { href: '/review', label: '复习', icon: Brain },
  { href: '/progress', label: '数据', icon: BarChart3 },
  { href: '/settings', label: '设置', icon: Settings },
];

export function Header() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-50 border-b border-slate-200 bg-white dark:border-slate-700 dark:bg-slate-900" style={{ paddingTop: 'env(safe-area-inset-top, 0px)' }}>
      <div className="mx-auto flex h-12 max-w-4xl items-center justify-between px-4">
        <Link href="/" className="flex items-center gap-2 font-bold text-lg text-primary-600">
          <span className="text-xl">🗣️</span>
          <span className="hidden sm:inline">SpeakUp</span>
        </Link>

        <nav className="flex items-center gap-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-primary-50 text-primary-700 dark:bg-primary-900/30 dark:text-primary-300'
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-200'
                )}
              >
                <item.icon className="h-4 w-4" />
                <span className="hidden sm:inline">{item.label}</span>
              </Link>
            );
          })}
        </nav>
      </div>
    </header>
  );
}
