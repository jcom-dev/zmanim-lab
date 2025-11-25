import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Zmanim Lab - Multi-Publisher Prayer Times Platform',
  description:
    'Calculate Jewish prayer times (zmanim) according to multiple halachic authorities and calculation methods worldwide. Choose your preferred publisher for accurate times.',
  keywords: [
    'zmanim',
    'Jewish prayer times',
    'halachic times',
    'kosher times',
    'prayer times',
    'sunrise',
    'sunset',
    'alos hashachar',
    'tzeis hakochavim',
    'multi-publisher',
    'halachic authorities',
  ],
  authors: [{ name: 'Zmanim Lab' }],
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#3b82f6',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🕍</text></svg>" />
      </head>
      <body className={inter.className}>
        <div className="min-h-screen">
          {children}
        </div>
      </body>
    </html>
  );
}
