import { UserButton } from '@clerk/nextjs';
import Link from 'next/link';
import { Users, BarChart3, Settings, UserPlus } from 'lucide-react';

export default function AdminPage() {
  const adminSections = [
    {
      title: 'Publisher Management',
      description: 'View and manage publisher accounts',
      href: '/admin/publishers',
      icon: Users,
    },
    {
      title: 'Create Publisher',
      description: 'Add a new publisher to the platform',
      href: '/admin/publishers/new',
      icon: UserPlus,
    },
    {
      title: 'Dashboard',
      description: 'View platform statistics and metrics',
      href: '/admin/dashboard',
      icon: BarChart3,
    },
    {
      title: 'System Settings',
      description: 'Configure rate limits, cache TTL, and feature flags',
      href: '/admin/settings',
      icon: Settings,
    },
  ];

  return (
    <div className="min-h-screen bg-slate-900 text-white p-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Admin Portal</h1>
          <UserButton afterSignOutUrl="/" />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {adminSections.map((section) => {
            const Icon = section.icon;
            return (
              <Link
                key={section.href}
                href={section.href}
                className="bg-slate-800 rounded-lg p-6 border border-slate-700 hover:border-slate-600 transition-colors"
              >
                <div className="flex items-start gap-4">
                  <div className="bg-slate-700 rounded-lg p-3">
                    <Icon className="w-6 h-6 text-slate-300" />
                  </div>
                  <div>
                    <h2 className="text-xl font-semibold mb-2">{section.title}</h2>
                    <p className="text-slate-400 text-sm">{section.description}</p>
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      </div>
    </div>
  );
}
