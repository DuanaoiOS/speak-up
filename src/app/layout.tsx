import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { BottomNav } from '@/components/layout/BottomNav';
import './globals.css';

export const metadata: Metadata = {
  title: 'SpeakUp — 英语口语训练',
  description: 'AI 驱动的英语口语训练应用，激活你的被动词汇',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    title: 'SpeakUp',
    statusBarStyle: 'black-translucent',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover, interactive-widget=resizes-content" />
        <link rel="apple-touch-icon" href="/icon-192.png" />
        <meta name="apple-mobile-web-app-title" content="SpeakUp" />
      </head>
      <body className="min-h-screen antialiased">
        <Header />
        <main className="mx-auto max-w-4xl px-4 pb-24 pt-6 md:pb-8">{children}</main>
        <BottomNav />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', () => {
                  navigator.serviceWorker.register('/sw.js').catch(() => {});
                });
              }
            `,
          }}
        />
      </body>
    </html>
  );
}
