import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuthenticatedFetch } from './useAuthenticatedFetch';

// Types
export interface PublisherZman {
  id: string;
  publisher_id: string;
  zman_key: string;
  hebrew_name: string;
  english_name: string;
  formula_dsl: string;
  ai_explanation: string | null;
  publisher_comment: string | null;
  is_enabled: boolean;
  is_visible: boolean;
  is_custom: boolean;
  category: 'essential' | 'optional' | 'custom';
  dependencies: string[];
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface ZmanimTemplate {
  id: string;
  zman_key: string;
  hebrew_name: string;
  english_name: string;
  formula_dsl: string;
  category: 'essential' | 'optional';
  description: string | null;
  is_required: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface CreateZmanRequest {
  zman_key: string;
  hebrew_name: string;
  english_name: string;
  formula_dsl: string;
  ai_explanation?: string;
  publisher_comment?: string;
  is_enabled?: boolean;
  is_visible?: boolean;
  sort_order?: number;
}

export interface UpdateZmanRequest {
  hebrew_name?: string;
  english_name?: string;
  formula_dsl?: string;
  ai_explanation?: string;
  publisher_comment?: string;
  is_enabled?: boolean;
  is_visible?: boolean;
  sort_order?: number;
}

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

export interface PreviewResult {
  result: string; // HH:MM:SS format
  timestamp: number;
  breakdown: CalculationStep[];
}

export interface CalculationStep {
  step: number;
  description: string;
  value: string;
}

export interface DayPreview {
  date: string;
  hebrew_date: string;
  result: string;
  sunrise: string;
  sunset: string;
  events: string[];
  is_shabbat: boolean;
  is_yom_tov: boolean;
}

export interface WeeklyPreviewResult {
  days: DayPreview[];
}

// Hook: Get all zmanim for publisher
export function useZmanimList() {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useQuery({
    queryKey: ['publisher-zmanim'],
    queryFn: async () => {
      const response = await fetchWithAuth<{ data: PublisherZman[] }>('/api/v1/publisher/zmanim');
      return response.data;
    },
  });
}

// Hook: Get single zman by key
export function useZmanDetails(zmanKey: string | null) {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useQuery({
    queryKey: ['publisher-zman', zmanKey],
    queryFn: async () => {
      if (!zmanKey) return null;
      const response = await fetchWithAuth<{ data: PublisherZman }>(`/api/v1/publisher/zmanim/${zmanKey}`);
      return response.data;
    },
    enabled: !!zmanKey,
  });
}

// Hook: Create new zman
export function useCreateZman() {
  const queryClient = useQueryClient();
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (zman: CreateZmanRequest) => {
      const response = await fetchWithAuth<{ data: PublisherZman }>('/api/v1/publisher/zmanim', {
        method: 'POST',
        body: JSON.stringify(zman),
      });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['publisher-zmanim'] });
    },
  });
}

// Hook: Update zman
export function useUpdateZman(zmanKey: string) {
  const queryClient = useQueryClient();
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (updates: UpdateZmanRequest) => {
      const response = await fetchWithAuth<{ data: PublisherZman }>(
        `/api/v1/publisher/zmanim/${zmanKey}`,
        {
          method: 'PUT',
          body: JSON.stringify(updates),
        }
      );
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['publisher-zmanim'] });
      queryClient.invalidateQueries({ queryKey: ['publisher-zman', zmanKey] });
    },
  });
}

// Hook: Delete zman (custom only)
export function useDeleteZman() {
  const queryClient = useQueryClient();
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (zmanKey: string) => {
      await fetchWithAuth(`/api/v1/publisher/zmanim/${zmanKey}`, {
        method: 'DELETE',
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['publisher-zmanim'] });
    },
  });
}

// Hook: Get zmanim templates
export function useZmanimTemplates() {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useQuery({
    queryKey: ['zmanim-templates'],
    queryFn: async () => {
      const response = await fetchWithAuth<{ data: ZmanimTemplate[] }>('/api/v1/zmanim/templates');
      return response.data;
    },
    staleTime: 1000 * 60 * 60, // 1 hour - templates don't change often
  });
}

// Hook: Browse public zmanim
export function useBrowseZmanim(searchQuery?: string, category?: string) {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useQuery({
    queryKey: ['browse-zmanim', searchQuery, category],
    queryFn: async () => {
      const params = new URLSearchParams();
      if (searchQuery) params.append('q', searchQuery);
      if (category) params.append('category', category);

      const url = `/api/v1/zmanim/browse${params.toString() ? `?${params.toString()}` : ''}`;
      const response = await fetchWithAuth<{
        data: Array<PublisherZman & { publisher_name: string; usage_count: number }>;
      }>(url);
      return response.data;
    },
    enabled: !!searchQuery || !!category, // Only fetch when searching
  });
}

// Hook: Preview formula (single day)
export function usePreviewFormula() {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (params: {
      formula: string;
      date: string;
      location: PreviewLocation;
    }) => {
      const response = await fetchWithAuth<PreviewResult>('/api/v1/dsl/preview', {
        method: 'POST',
        body: JSON.stringify({
          formula: params.formula,
          date: params.date,
          latitude: params.location.latitude,
          longitude: params.location.longitude,
          timezone: params.location.timezone,
        }),
      });
      return response;
    },
  });
}

// Hook: Preview formula (weekly)
export function usePreviewWeek() {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (params: {
      formula: string;
      start_date: string;
      location: PreviewLocation;
    }) => {
      const response = await fetchWithAuth<WeeklyPreviewResult>('/api/v1/dsl/preview-week', {
        method: 'POST',
        body: JSON.stringify({
          formula: params.formula,
          start_date: params.start_date,
          latitude: params.location.latitude,
          longitude: params.location.longitude,
          timezone: params.location.timezone,
        }),
      });
      return response;
    },
  });
}

// Hook: Validate DSL formula
export function useValidateFormula() {
  const { fetchWithAuth } = useAuthenticatedFetch();

  return useMutation({
    mutationFn: async (formula: string) => {
      const response = await fetchWithAuth<{
        valid: boolean;
        errors?: Array<{ message: string; line?: number; column?: number }>;
        dependencies?: string[];
      }>('/api/v1/dsl/validate', {
        method: 'POST',
        body: JSON.stringify({ formula }),
      });
      return response;
    },
  });
}

// Helper: Categorize zmanim by category
export function categorizeZmanim(zmanim: PublisherZman[]) {
  return {
    essential: zmanim.filter((z) => z.category === 'essential'),
    optional: zmanim.filter((z) => z.category === 'optional'),
    custom: zmanim.filter((z) => z.category === 'custom'),
  };
}

// Helper: Extract dependencies from formula (client-side)
export function extractDependencies(formula: string): string[] {
  const regex = /@([a-z_][a-z0-9_]*)/g;
  const matches = formula.matchAll(regex);
  const deps = new Set<string>();

  for (const match of matches) {
    deps.add(match[1]);
  }

  return Array.from(deps);
}
