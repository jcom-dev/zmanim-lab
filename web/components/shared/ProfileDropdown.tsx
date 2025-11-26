'use client';

import { useState, useEffect, useCallback } from 'react';
import { useUser, useClerk, useAuth } from '@clerk/nextjs';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface Publisher {
  id: string;
  name: string;
}

export function ProfileDropdown() {
  const { user, isLoaded } = useUser();
  const { signOut } = useClerk();
  const { getToken } = useAuth();
  const router = useRouter();
  const [publishers, setPublishers] = useState<Publisher[]>([]);
  const [isResettingPassword, setIsResettingPassword] = useState(false);

  const role = (user?.publicMetadata?.role as string) || 'user';
  const publisherAccessList = (user?.publicMetadata?.publisher_access_list as string[]) || [];

  const fetchPublisherNames = useCallback(async (ids: string[]) => {
    if (ids.length === 0) {
      setPublishers([]);
      return;
    }

    try {
      const response = await fetch(`${API_BASE}/api/v1/publishers/names?ids=${ids.join(',')}`);
      if (response.ok) {
        const data = await response.json();
        setPublishers(data.publishers || []);
      }
    } catch (error) {
      console.error('Failed to fetch publisher names:', error);
    }
  }, []);

  useEffect(() => {
    if (publisherAccessList.length > 0) {
      fetchPublisherNames(publisherAccessList);
    }
  }, [publisherAccessList, fetchPublisherNames]);

  const handlePasswordReset = async () => {
    if (!user?.primaryEmailAddress?.emailAddress) return;

    setIsResettingPassword(true);
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/user/request-password-reset`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` }),
        },
        body: JSON.stringify({ email: user.primaryEmailAddress.emailAddress }),
      });

      if (response.ok) {
        alert('Password reset email sent! Check your inbox.');
      } else {
        alert('Failed to send password reset email. Please try again.');
      }
    } catch (error) {
      console.error('Password reset error:', error);
      alert('Failed to send password reset email. Please try again.');
    } finally {
      setIsResettingPassword(false);
    }
  };

  const handleSignOut = () => {
    signOut(() => router.push('/'));
  };

  if (!isLoaded) return null;

  if (!user) {
    return (
      <Button variant="outline" onClick={() => router.push('/sign-in')}>
        Sign In
      </Button>
    );
  }

  const initials =
    user.firstName && user.lastName
      ? `${user.firstName[0]}${user.lastName[0]}`.toUpperCase()
      : user.primaryEmailAddress?.emailAddress?.[0]?.toUpperCase() || '?';

  const getRoleBadgeVariant = (role: string): 'default' | 'secondary' | 'outline' => {
    switch (role) {
      case 'admin':
        return 'default';
      case 'publisher':
        return 'secondary';
      default:
        return 'outline';
    }
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="relative h-10 w-10 rounded-full p-0">
          <Avatar className="h-10 w-10">
            <AvatarImage src={user.imageUrl} alt={user.fullName || ''} />
            <AvatarFallback>{initials}</AvatarFallback>
          </Avatar>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-64" align="end">
        <DropdownMenuLabel className="font-normal">
          <div className="flex flex-col space-y-1">
            <p className="text-sm font-medium leading-none">{user.fullName || 'User'}</p>
            <p className="text-xs leading-none text-gray-500">{user.primaryEmailAddress?.emailAddress}</p>
            <Badge variant={getRoleBadgeVariant(role)} className="mt-2 w-fit">
              {role.charAt(0).toUpperCase() + role.slice(1)}
            </Badge>
          </div>
        </DropdownMenuLabel>

        {publishers.length > 0 && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuLabel className="text-xs text-gray-500 font-normal">Publishers</DropdownMenuLabel>
            {publishers.map((pub) => (
              <DropdownMenuItem key={pub.id} onClick={() => router.push(`/publisher/dashboard?p=${pub.id}`)}>
                <svg
                  className="w-4 h-4 mr-2 text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                  />
                </svg>
                {pub.name}
              </DropdownMenuItem>
            ))}
          </>
        )}

        <DropdownMenuSeparator />

        <DropdownMenuItem onClick={handlePasswordReset} disabled={isResettingPassword}>
          <svg className="w-4 h-4 mr-2 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
            />
          </svg>
          {isResettingPassword ? 'Sending...' : 'Change Password'}
        </DropdownMenuItem>

        <DropdownMenuItem onClick={handleSignOut}>
          <svg className="w-4 h-4 mr-2 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
            />
          </svg>
          Sign Out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
