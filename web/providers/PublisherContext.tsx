'use client';

import { createContext, useContext, useState, useEffect, ReactNode, useCallback, Suspense } from 'react';
import { useUser, useAuth } from '@clerk/nextjs';
import { useSearchParams, useRouter, usePathname } from 'next/navigation';
import { API_BASE } from '@/lib/api';
import type { ClerkPublicMetadata } from '@/types/clerk';

interface Publisher {
  id: string;
  name: string;
  organization: string;
  status: string;
}

interface PublisherContextType {
  selectedPublisherId: string | null;
  setSelectedPublisherId: (id: string) => void;
  publishers: Publisher[];
  selectedPublisher: Publisher | null;
  isLoading: boolean;
  error: string | null;
  refreshPublishers: () => Promise<void>;
  // Impersonation state
  isImpersonating: boolean;
  impersonatedPublisher: Publisher | null;
  startImpersonation: (publisherId: string, publisher: Publisher) => void;
  exitImpersonation: () => void;
}

const PublisherContext = createContext<PublisherContextType | null>(null);

function PublisherProviderInner({ children }: { children: ReactNode }) {
  const { user, isLoaded: userLoaded } = useUser();
  const { getToken } = useAuth();
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const [publishers, setPublishers] = useState<Publisher[]>([]);
  const [selectedPublisherId, setSelectedPublisherIdState] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Impersonation state
  const [isImpersonating, setIsImpersonating] = useState(false);
  const [impersonatedPublisher, setImpersonatedPublisher] = useState<Publisher | null>(null);

  // Extract publisher IDs from Clerk metadata
  const metadata = user?.publicMetadata as ClerkPublicMetadata | undefined;
  const primaryPublisherId = metadata?.primary_publisher_id;

  // Fetch publisher details from API
  const fetchPublishers = useCallback(async () => {
    if (!userLoaded || !user) {
      setIsLoading(false);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const token = await getToken();
      if (!token) {
        setError('Not authenticated');
        setIsLoading(false);
        return;
      }

      const response = await fetch(`${API_BASE}/api/v1/publisher/accessible`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch accessible publishers');
      }

      const data = await response.json();
      const fetchedPublishers = data.data?.publishers || data.publishers || [];
      setPublishers(fetchedPublishers);

      // Initialize selection if we have publishers but no selection yet
      if (fetchedPublishers.length > 0 && !selectedPublisherId) {
        const urlPublisherId = searchParams.get('p');
        const storedId = typeof window !== 'undefined' ? localStorage.getItem('selectedPublisherId') : null;

        let initialId = null;

        // Priority: URL param > localStorage > primary > first
        if (urlPublisherId && fetchedPublishers.some((p: Publisher) => p.id === urlPublisherId)) {
          initialId = urlPublisherId;
        } else if (storedId && fetchedPublishers.some((p: Publisher) => p.id === storedId)) {
          initialId = storedId;
        } else if (primaryPublisherId && fetchedPublishers.some((p: Publisher) => p.id === primaryPublisherId)) {
          initialId = primaryPublisherId;
        } else {
          initialId = fetchedPublishers[0].id;
        }

        setSelectedPublisherIdState(initialId);
        if (typeof window !== 'undefined' && initialId) {
          localStorage.setItem('selectedPublisherId', initialId);
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load publishers');
      console.error('Failed to fetch publishers:', err);
    } finally {
      setIsLoading(false);
    }
  }, [userLoaded, user, getToken, selectedPublisherId, searchParams, primaryPublisherId]);

  // Fetch publishers on mount
  useEffect(() => {
    if (userLoaded && user) {
      fetchPublishers();
    }
  }, [userLoaded, user, fetchPublishers]);

  // Handle publisher selection change
  const setSelectedPublisherId = useCallback((id: string) => {
    setSelectedPublisherIdState(id);

    if (typeof window !== 'undefined') {
      localStorage.setItem('selectedPublisherId', id);
    }

    // Update URL without full navigation
    const params = new URLSearchParams(searchParams.toString());
    params.set('p', id);
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  }, [searchParams, router, pathname]);

  // Start impersonation (admin only)
  const startImpersonation = useCallback((publisherId: string, publisher: Publisher) => {
    setIsImpersonating(true);
    setImpersonatedPublisher(publisher);
    setSelectedPublisherIdState(publisherId);
    if (typeof window !== 'undefined') {
      sessionStorage.setItem('impersonating', JSON.stringify({ publisherId, publisher }));
    }
    router.push('/publisher/dashboard');
  }, [router]);

  // Exit impersonation
  const exitImpersonation = useCallback(() => {
    setIsImpersonating(false);
    const previousPublisher = impersonatedPublisher;
    setImpersonatedPublisher(null);
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem('impersonating');
    }
    router.push(previousPublisher ? `/admin/publishers/${previousPublisher.id}` : '/admin/publishers');
  }, [router, impersonatedPublisher]);

  // Check for impersonation state on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const stored = sessionStorage.getItem('impersonating');
      if (stored) {
        try {
          const { publisherId, publisher } = JSON.parse(stored);
          setIsImpersonating(true);
          setImpersonatedPublisher(publisher);
          setSelectedPublisherIdState(publisherId);
        } catch {
          sessionStorage.removeItem('impersonating');
        }
      }
    }
  }, []);

  // Get the effective selected publisher (impersonated or regular)
  const selectedPublisher = isImpersonating && impersonatedPublisher
    ? impersonatedPublisher
    : publishers.find(p => p.id === selectedPublisherId) || null;

  const contextValue: PublisherContextType = {
    selectedPublisherId,
    setSelectedPublisherId,
    publishers,
    selectedPublisher,
    isLoading: isLoading || !userLoaded,
    error,
    refreshPublishers: fetchPublishers,
    // Impersonation
    isImpersonating,
    impersonatedPublisher,
    startImpersonation,
    exitImpersonation,
  };

  return (
    <PublisherContext.Provider value={contextValue}>
      {children}
    </PublisherContext.Provider>
  );
}

export function PublisherProvider({ children }: { children: ReactNode }) {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <PublisherProviderInner>{children}</PublisherProviderInner>
    </Suspense>
  );
}

export function usePublisherContext() {
  const context = useContext(PublisherContext);
  if (!context) {
    throw new Error('usePublisherContext must be used within PublisherProvider');
  }
  return context;
}
