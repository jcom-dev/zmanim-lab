'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { PublisherZman } from '@/lib/hooks/useZmanimList';
import { useApi } from '@/lib/api-client';

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

interface PreviewResult {
  key: string;
  name: string;
  time: string | null;
  error?: string;
}

interface AlgorithmPreviewProps {
  zmanim: PublisherZman[];
  location: PreviewLocation;
  selectedDate: Date;
}

export function AlgorithmPreview({ zmanim, location, selectedDate }: AlgorithmPreviewProps) {
  const api = useApi();
  const [preview, setPreview] = useState<PreviewResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Format selected date as YYYY-MM-DD
  const dateStr = useMemo(() => {
    return selectedDate.toISOString().split('T')[0];
  }, [selectedDate]);

  const loadPreview = useCallback(async () => {
    // Only preview enabled zmanim
    const enabledZmanim = zmanim.filter(z => z.is_enabled);

    if (enabledZmanim.length === 0) {
      setPreview([]);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Calculate preview for each zman using the DSL preview endpoint
      const results = await Promise.allSettled(
        enabledZmanim.slice(0, 20).map(async (zman) => {
          // Use api.post - it handles auth automatically
          const result = await api.post<{ result?: string; time?: string }>('/dsl/preview', {
            body: JSON.stringify({
              formula: zman.formula_dsl,
              date: dateStr,
              latitude: location.latitude,
              longitude: location.longitude,
              timezone: location.timezone,
            }),
          });
          return {
            key: zman.zman_key,
            name: zman.english_name,
            time: result.result || result.time || null,
          };
        })
      );

      const previewResults: PreviewResult[] = results.map((result, index) => {
        if (result.status === 'fulfilled') {
          return result.value;
        } else {
          return {
            key: enabledZmanim[index].zman_key,
            name: enabledZmanim[index].english_name,
            time: null,
            error: result.reason?.message || 'Error',
          };
        }
      });

      setPreview(previewResults);
    } catch (err) {
      console.error('Failed to load preview:', err);
      setError('Failed to calculate preview');
    } finally {
      setLoading(false);
    }
  }, [api, zmanim, location, dateStr]);

  useEffect(() => {
    // Debounce the preview calculation
    const timeoutId = setTimeout(() => {
      loadPreview();
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [loadPreview]);

  // Format time for display (HH:MM:SS -> h:mm AM/PM)
  const formatTime = (timeStr: string): string => {
    try {
      const [hours, minutes] = timeStr.split(':').map(Number);
      const period = hours >= 12 ? 'PM' : 'AM';
      const displayHours = hours % 12 || 12;
      return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
    } catch {
      return timeStr;
    }
  };

  return (
    <Card data-testid="algorithm-preview">
      <CardHeader className="pb-2">
        <CardTitle className="text-base">Live Preview</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Location info */}
        <div className="text-xs text-muted-foreground">
          {location.displayName}
        </div>

        {loading && (
          <div className="text-center py-4 text-muted-foreground">
            Calculating...
          </div>
        )}

        {error && (
          <div className="text-center py-4 text-destructive">
            {error}
          </div>
        )}

        {!loading && !error && preview.length === 0 && (
          <div className="text-center py-4 text-muted-foreground">
            {zmanim.length === 0
              ? 'No zmanim configured yet'
              : 'No enabled zmanim to preview'}
          </div>
        )}

        {!loading && !error && preview.length > 0 && (
          <div className="space-y-3">
            {preview.map((item) => (
              <div
                key={item.key}
                className="flex justify-between items-center py-2 border-b border-border last:border-0"
                data-testid={`preview-${item.key}`}
              >
                <div className="font-medium text-foreground text-sm truncate max-w-[60%]">
                  {item.name}
                </div>
                {item.error ? (
                  <div className="text-sm text-destructive">Error</div>
                ) : item.time ? (
                  <div className="text-lg font-mono text-primary">
                    {formatTime(item.time)}
                  </div>
                ) : (
                  <div className="text-sm text-muted-foreground">--:--</div>
                )}
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
