'use client';

import { useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { API_BASE } from '@/lib/api';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public data?: unknown
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

interface FetchOptions extends Omit<RequestInit, 'headers'> {
  headers?: Record<string, string>;
  skipPublisherId?: boolean;
}

export function useAuthenticatedFetch() {
  const { getToken } = useAuth();
  const { selectedPublisher } = usePublisherContext();

  const fetchWithAuth = useCallback(async <T>(
    endpoint: string,
    options: FetchOptions = {}
  ): Promise<T> => {
    const { skipPublisherId, headers: customHeaders, ...fetchOptions } = options;

    const token = await getToken();
    if (!token) {
      throw new Error('Not authenticated - no token available');
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      ...customHeaders,
    };

    if (!skipPublisherId && selectedPublisher?.id) {
      headers['X-Publisher-Id'] = selectedPublisher.id;
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...fetchOptions,
      headers,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: response.statusText }));
      throw new ApiError(
        error.message || `API Error: ${response.status}`,
        response.status,
        error
      );
    }

    const json = await response.json();
    return json.data !== undefined ? json.data : json;
  }, [getToken, selectedPublisher]);

  return { fetchWithAuth };
}
