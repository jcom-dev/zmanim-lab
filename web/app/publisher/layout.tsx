'use client';

import { ReactNode } from 'react';
import { PublisherProvider } from '@/providers/PublisherContext';
import { PublisherSwitcher } from '@/components/publisher/PublisherSwitcher';
import { ImpersonationBanner } from '@/components/admin/ImpersonationBanner';
import { UserButton } from '@clerk/nextjs';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

interface PublisherLayoutProps {
  children: ReactNode;
}

export default function PublisherLayout({ children }: PublisherLayoutProps) {
  const pathname = usePathname();

  const navItems = [
    { href: '/publisher/dashboard', label: 'Dashboard' },
    { href: '/publisher/profile', label: 'Profile' },
    { href: '/publisher/coverage', label: 'Coverage' },
    { href: '/publisher/algorithm', label: 'Zmanim' },
    { href: '/publisher/team', label: 'Team' },
    { href: '/publisher/analytics', label: 'Analytics' },
    { href: '/publisher/activity', label: 'Activity' },
  ];

  return (
    <PublisherProvider>
      <div className="min-h-screen bg-slate-900 text-white">
        {/* Impersonation Banner */}
        <ImpersonationBanner />

        {/* Header */}
        <header className="bg-slate-800 border-b border-slate-700">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-16">
              {/* Left: Logo & Publisher Switcher */}
              <div className="flex items-center gap-6">
                <Link href="/" className="text-xl font-bold text-white hover:text-blue-400 transition-colors">
                  Zmanim Lab
                </Link>
                <div className="h-6 w-px bg-slate-600" />
                <PublisherSwitcher />
              </div>

              {/* Right: User Button */}
              <div className="flex items-center gap-4">
                <UserButton afterSignOutUrl="/" />
              </div>
            </div>
          </div>
        </header>

        {/* Navigation */}
        <nav className="bg-slate-850 border-b border-slate-700">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex space-x-8">
              {navItems.map((item) => {
                const isActive = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`py-3 px-1 border-b-2 text-sm font-medium transition-colors ${
                      isActive
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-gray-400 hover:text-gray-300 hover:border-gray-500'
                    }`}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </div>
        </nav>

        {/* Main Content */}
        <main>{children}</main>
      </div>
    </PublisherProvider>
  );
}
