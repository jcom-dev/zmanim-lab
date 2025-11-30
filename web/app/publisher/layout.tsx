'use client';

import { ReactNode } from 'react';
import { PublisherProvider } from '@/providers/PublisherContext';
import { PublisherSwitcher } from '@/components/publisher/PublisherSwitcher';
import { ImpersonationBanner } from '@/components/admin/ImpersonationBanner';
import { UserButton } from '@clerk/nextjs';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useUserRoles } from '@/lib/hooks';
import { Shield } from 'lucide-react';

interface PublisherLayoutProps {
  children: ReactNode;
}

export default function PublisherLayout({ children }: PublisherLayoutProps) {
  const pathname = usePathname();
  const { isAdmin, isLoaded } = useUserRoles();

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
      <div className="min-h-screen bg-background text-foreground">
        {/* Impersonation Banner */}
        <ImpersonationBanner />

        {/* Header */}
        <header className="bg-card border-b border-border">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-16">
              {/* Left: Logo & Publisher Switcher */}
              <div className="flex items-center gap-6">
                <Link href="/" className="text-xl font-bold text-foreground hover:text-primary transition-colors">
                  Zmanim Lab
                </Link>
                <div className="h-6 w-px bg-border" />
                <PublisherSwitcher />
              </div>

              {/* Right: Admin Link (if dual-role) & User Button */}
              <div className="flex items-center gap-4">
                {isLoaded && isAdmin && (
                  <Link
                    href="/admin"
                    className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-purple-600 dark:text-purple-400 bg-purple-50 dark:bg-purple-950 rounded-md hover:bg-purple-100 dark:hover:bg-purple-900 transition-colors"
                  >
                    <Shield className="w-4 h-4" />
                    Admin Portal
                  </Link>
                )}
                <UserButton afterSignOutUrl="/" />
              </div>
            </div>
          </div>
        </header>

        {/* Navigation */}
        <nav className="bg-card/50 border-b border-border">
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
                        ? 'border-primary text-primary'
                        : 'border-transparent text-muted-foreground hover:text-foreground hover:border-muted'
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
