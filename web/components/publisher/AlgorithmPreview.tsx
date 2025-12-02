'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { PublisherZman } from '@/lib/hooks/useZmanimList';
import { useApi } from '@/lib/api-client';
import { FlaskConical } from 'lucide-react';

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

interface PreviewResult {
  key: string;
  english_name: string;
  hebrew_name: string;
  time: string | null;
  error?: string;
  is_beta?: boolean;
}

interface AlgorithmPreviewProps {
  zmanim: PublisherZman[];
  location: PreviewLocation;
  selectedDate: Date;
  displayLanguage?: 'hebrew' | 'english' | 'both';
  hasCoverage?: boolean;
}

export function AlgorithmPreview({ zmanim, location, selectedDate, displayLanguage = 'both', hasCoverage = true }: AlgorithmPreviewProps) {
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
            english_name: zman.english_name,
            hebrew_name: zman.hebrew_name,
            time: result.result || result.time || null,
            is_beta: zman.is_beta,
          };
        })
      );

      const previewResults: PreviewResult[] = results.map((result, index) => {
        if (result.status === 'fulfilled') {
          return result.value;
        } else {
          return {
            key: enabledZmanim[index].zman_key,
            english_name: enabledZmanim[index].english_name,
            hebrew_name: enabledZmanim[index].hebrew_name,
            time: null,
            error: result.reason?.message || 'Error',
            is_beta: enabledZmanim[index].is_beta,
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
      <CardContent>
        {!hasCoverage && (
          <div className="text-center py-6 text-muted-foreground">
            <div className="text-amber-500 mb-2">
              <svg className="w-8 h-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <p className="text-sm font-medium">No Coverage Areas</p>
            <p className="text-xs mt-1">Add coverage to see live preview</p>
          </div>
        )}

        {hasCoverage && loading && (
          <div className="text-center py-4 text-muted-foreground">
            Calculating...
          </div>
        )}

        {hasCoverage && error && (
          <div className="text-center py-4 text-destructive">
            {error}
          </div>
        )}

        {hasCoverage && !loading && !error && preview.length === 0 && (
          <div className="text-center py-4 text-muted-foreground">
            {zmanim.length === 0
              ? 'No zmanim configured yet'
              : 'No enabled zmanim to preview'}
          </div>
        )}

        {hasCoverage && !loading && !error && preview.length > 0 && (
          <table className="w-full">
            <tbody>
              {preview.map((item) => (
                <tr
                  key={item.key}
                  className="border-b border-border last:border-0"
                  data-testid={`preview-${item.key}`}
                >
                  <td className={`py-2 pr-4 font-medium text-foreground text-sm ${displayLanguage === 'hebrew' ? 'font-hebrew text-right' : ''}`}>
                    <span className="flex items-center gap-1.5">
                      <span className="truncate max-w-[180px]" title={displayLanguage === 'hebrew' ? item.hebrew_name : item.english_name}>
                        {displayLanguage === 'hebrew' ? item.hebrew_name : item.english_name}
                      </span>
                      {item.is_beta && <FlaskConical className="h-3 w-3 text-amber-500 shrink-0" />}
                    </span>
                  </td>
                  <td className="py-2 text-right whitespace-nowrap">
                    {item.error ? (
                      <span className="text-sm text-destructive">Error</span>
                    ) : item.time ? (
                      <span className="text-lg font-mono text-primary">
                        {formatTime(item.time)}
                      </span>
                    ) : (
                      <span className="text-sm text-muted-foreground">--:--</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </CardContent>
    </Card>
  );
}
