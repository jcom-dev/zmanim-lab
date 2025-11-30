'use client';

import { ReactNode } from 'react';
import { UserButton } from '@clerk/nextjs';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Users, BarChart3, Settings, Sun, Clock, UserCog, Building2 } from 'lucide-react';
import { useUserRoles } from '@/lib/hooks';

interface AdminLayoutProps {
  children: ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  const pathname = usePathname();
  const { hasPublisherAccess, isLoaded } = useUserRoles();

  const navItems = [
    { href: '/admin', label: 'Overview', icon: Home, exact: true },
    { href: '/admin/users', label: 'Users', icon: UserCog },
    { href: '/admin/publishers', label: 'Publishers', icon: Users },
    { href: '/admin/zmanim/primitives', label: 'Primitives', icon: Sun },
    { href: '/admin/zmanim/registry', label: 'Zmanim Registry', icon: Clock },
    { href: '/admin/dashboard', label: 'Dashboard', icon: BarChart3 },
    { href: '/admin/settings', label: 'Settings', icon: Settings },
  ];

  const isActive = (href: string, exact?: boolean) => {
    if (exact) return pathname === href;
    return pathname.startsWith(href) && (href !== '/admin' || pathname === '/admin');
  };

  return (
    <div className="dark min-h-screen bg-background text-foreground">
      {/* Header */}
      <header className="bg-card border-b border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Left: Logo & Breadcrumb */}
            <div className="flex items-center gap-4">
              <Link
                href="/"
                className="text-muted-foreground hover:text-foreground transition-colors"
              >
                <Home className="w-5 h-5" />
              </Link>
              <span className="text-muted-foreground">/</span>
              <span className="text-xl font-bold">Admin Portal</span>
            </div>

            {/* Right: Publisher Link (if dual-role) & User Button */}
            <div className="flex items-center gap-4">
              {isLoaded && hasPublisherAccess && (
                <Link
                  href="/publisher"
                  className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950 rounded-md hover:bg-blue-100 dark:hover:bg-blue-900 transition-colors"
                >
                  <Building2 className="w-4 h-4" />
                  Publisher Portal
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
          <div className="flex space-x-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const active = isActive(item.href, item.exact);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center gap-2 py-3 px-4 text-sm font-medium transition-colors border-b-2 ${
                    active
                      ? 'border-primary text-primary'
                      : 'border-transparent text-muted-foreground hover:text-foreground hover:border-muted'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  {item.label}
                </Link>
              );
            })}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  );
}
