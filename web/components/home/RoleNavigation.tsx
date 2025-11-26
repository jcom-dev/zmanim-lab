'use client';

import { useUser } from '@clerk/nextjs';
import Link from 'next/link';
import { Settings, Building2 } from 'lucide-react';

export function RoleNavigation() {
  const { user, isLoaded } = useUser();

  if (!isLoaded || !user) return null;

  const metadata = user.publicMetadata as {
    role?: string;
    publisher_access_list?: string[];
  };

  const isAdmin = metadata.role === 'admin';
  const hasPublisherAccess = (metadata.publisher_access_list?.length || 0) > 0;

  if (!isAdmin && !hasPublisherAccess) return null;

  return (
    <div className="flex gap-3">
      {hasPublisherAccess && (
        <Link
          href="/publisher/dashboard"
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
        >
          <Building2 className="w-4 h-4" />
          Publisher Dashboard
        </Link>
      )}
      {isAdmin && (
        <Link
          href="/admin"
          className="flex items-center gap-2 px-4 py-2 bg-slate-600 hover:bg-slate-500 text-white rounded-lg font-medium transition-colors"
        >
          <Settings className="w-4 h-4" />
          Admin Portal
        </Link>
      )}
    </div>
  );
}
