import Link from 'next/link';
import { Users, BarChart3, Settings, UserPlus, FileCheck, AlertCircle } from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

export default function AdminPage() {
  const adminSections = [
    {
      title: 'Publisher Management',
      description: 'View, approve, and manage publisher accounts. Review pending applications.',
      href: '/admin/publishers',
      icon: Users,
      highlight: true,
    },
    {
      title: 'Create Publisher',
      description: 'Manually add a new publisher to the platform.',
      href: '/admin/publishers/new',
      icon: UserPlus,
    },
    {
      title: 'Dashboard',
      description: 'View platform statistics and metrics.',
      href: '/admin/dashboard',
      icon: BarChart3,
    },
    {
      title: 'System Settings',
      description: 'Configure rate limits, cache TTL, and feature flags.',
      href: '/admin/settings',
      icon: Settings,
    },
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Welcome to Admin Portal</h1>
        <p className="text-muted-foreground mt-1">
          Manage publishers, view statistics, and configure platform settings.
        </p>
      </div>

      {/* Quick Actions Banner */}
      <Card className="border-yellow-500/50 bg-yellow-500/10">
        <CardHeader className="pb-3">
          <CardTitle className="flex items-center gap-2 text-yellow-500">
            <FileCheck className="w-5 h-5" />
            Pending Publisher Requests
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">
            Go to{' '}
            <Link href="/admin/publishers" className="text-primary underline hover:no-underline">
              Publisher Management
            </Link>{' '}
            to review and approve new publisher applications.
          </p>
        </CardContent>
      </Card>

      {/* Admin Sections Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {adminSections.map((section) => {
          const Icon = section.icon;
          return (
            <Link key={section.href} href={section.href}>
              <Card className={`h-full transition-colors hover:bg-accent/50 cursor-pointer ${
                section.highlight ? 'border-primary/50' : ''
              }`}>
                <CardHeader>
                  <CardTitle className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${section.highlight ? 'bg-primary/20' : 'bg-muted'}`}>
                      <Icon className={`w-5 h-5 ${section.highlight ? 'text-primary' : 'text-muted-foreground'}`} />
                    </div>
                    {section.title}
                  </CardTitle>
                  <CardDescription>{section.description}</CardDescription>
                </CardHeader>
              </Card>
            </Link>
          );
        })}
      </div>

      {/* Help Section */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertCircle className="w-5 h-5 text-muted-foreground" />
            Quick Help
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-muted-foreground">
          <p>
            <strong>Approving Publishers:</strong> When a user submits a publisher request via &quot;Become a Publisher&quot;,
            it appears in the Publisher Management page. Click to review details and approve or reject.
          </p>
          <p>
            <strong>Managing Users:</strong> Click on any publisher to view their details, invite users to their team,
            or remove existing users.
          </p>
          <p>
            <strong>Impersonation:</strong> Use the &quot;Impersonate Publisher&quot; button on a publisher&apos;s detail page
            to view the dashboard as that publisher for troubleshooting.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
