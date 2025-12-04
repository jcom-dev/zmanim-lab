'use client';

import { useQuery } from '@tanstack/react-query';
import { useApi } from '@/lib/api-client';
import { Tag, TagType, TAG_TYPE_ORDER } from '../constants';

interface TagsResponse {
  tags: Tag[];
}

// Fetch all tags from the API
export function useTags() {
  const api = useApi();

  return useQuery({
    queryKey: ['tags'],
    queryFn: async () => {
      const response = await api.public.get<TagsResponse>('/registry/tags');
      return response.tags || [];
    },
    staleTime: 5 * 60 * 1000, // 5 minutes - tags don't change often
  });
}

// Fetch tags grouped by type
export function useTagsByType() {
  const { data: tags, ...rest } = useTags();

  const groupedTags = tags
    ? TAG_TYPE_ORDER.reduce(
        (acc, type) => {
          acc[type] = tags.filter((t) => t.tag_type === type);
          return acc;
        },
        {} as Record<TagType, Tag[]>
      )
    : ({} as Record<TagType, Tag[]>);

  return {
    ...rest,
    data: tags,
    groupedTags,
  };
}

// Fetch jewish_day tags only
export function useJewishDayTags() {
  const { data: tags, ...rest } = useTags();

  const jewishDayTags = tags?.filter((t) => t.tag_type === 'jewish_day') || [];

  return {
    ...rest,
    data: jewishDayTags,
  };
}
