'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useApi } from '@/lib/api-client';
import { FlaskConical, Flame, Moon, Star } from 'lucide-react';

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

// Day context returned from backend
interface DayContext {
  date: string;
  day_of_week: number;
  day_name: string;
  hebrew_date: string;
  hebrew_date_formatted: string;
  is_erev_shabbos: boolean;
  is_shabbos: boolean;
  is_yom_tov: boolean;
  is_fast_day: boolean;
  holidays: string[];
  active_event_codes: string[];
  show_candle_lighting: boolean;
  show_havdalah: boolean;
  show_fast_start: boolean;
  show_fast_end: boolean;
  special_contexts: string[];
}

// Zman with calculated time from backend
interface ZmanWithTime {
  id: string;
  zman_key: string;
  hebrew_name: string;
  english_name: string;
  time?: string;
  error?: string;
  is_beta: boolean;
  is_enabled: boolean;
}

// Response from enhanced /publisher/zmanim endpoint with date params
interface FilteredZmanimResponse {
  day_context: DayContext;
  zmanim: ZmanWithTime[];
}

interface AlgorithmPreviewProps {
  location: PreviewLocation;
  selectedDate: Date;
  displayLanguage?: 'hebrew' | 'english' | 'both';
  hasCoverage?: boolean;
}

export function AlgorithmPreview({ location, selectedDate, displayLanguage = 'both', hasCoverage = true }: AlgorithmPreviewProps) {
  const api = useApi();
  const [dayContext, setDayContext] = useState<DayContext | null>(null);
  const [preview, setPreview] = useState<ZmanWithTime[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Format selected date as YYYY-MM-DD
  const dateStr = useMemo(() => {
    return selectedDate.toISOString().split('T')[0];
  }, [selectedDate]);

  // Load preview from backend - all filtering and calculation done server-side
  const loadPreview = useCallback(async () => {
    if (!hasCoverage) {
      setPreview([]);
      setDayContext(null);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Call enhanced endpoint with date/location params
      // Backend handles: filtering by day context, time calculation, caching
      const params = new URLSearchParams({
        date: dateStr,
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        timezone: location.timezone,
      });

      const response = await api.get<FilteredZmanimResponse>(`/publisher/zmanim?${params}`);

      setDayContext(response.day_context);
      setPreview(response.zmanim || []);
    } catch (err) {
      console.error('Failed to load preview:', err);
      setError('Failed to calculate preview');
    } finally {
      setLoading(false);
    }
  }, [api, dateStr, location, hasCoverage]);

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

  // Get Chanukah day from holidays
  const chanukahDay = useMemo(() => {
    if (!dayContext?.holidays) return null;
    for (const h of dayContext.holidays) {
      if (h.includes('Chanukah')) {
        const match = h.match(/(\d+)/);
        if (match) return parseInt(match[1], 10);
      }
    }
    return null;
  }, [dayContext?.holidays]);

  // Get Omer day from active event codes
  const omerDay = useMemo(() => {
    if (!dayContext?.active_event_codes) return null;
    for (const code of dayContext.active_event_codes) {
      if (code.startsWith('omer_')) {
        const match = code.match(/omer_(\d+)/);
        if (match) return parseInt(match[1], 10);
      }
    }
    return null;
  }, [dayContext?.active_event_codes]);

  // Filter out Chanukah and Omer from holidays display (shown separately)
  const displayHolidays = useMemo(() => {
    if (!dayContext?.holidays) return [];
    return dayContext.holidays.filter(h => !h.includes('Chanukah') && !h.includes('Omer'));
  }, [dayContext?.holidays]);

  return (
    <Card data-testid="algorithm-preview">
      <CardHeader className="pb-2">
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">Live Preview</CardTitle>
            <span className="text-sm text-muted-foreground">{dayContext?.day_name || ''}</span>
          </div>
          <div className="text-xs text-muted-foreground">{dayContext?.hebrew_date || ''}</div>
          {dayContext && (dayContext.is_erev_shabbos || dayContext.is_shabbos || displayHolidays.length > 0 || chanukahDay || omerDay) && (
            <div className="flex items-center gap-1.5 flex-wrap justify-start">
              {dayContext.is_erev_shabbos && (
                <Badge className="text-xs gap-1 shrink-0 bg-orange-500 text-white border-orange-600">
                  <Flame className="h-3 w-3" />
                  Erev Shabbos
                </Badge>
              )}
              {dayContext.is_shabbos && (
                <Badge className="text-xs gap-1 shrink-0 bg-purple-500 text-white border-purple-600">
                  <Moon className="h-3 w-3" />
                  Shabbos
                </Badge>
              )}
              {displayHolidays.map((holiday, i) => (
                <Badge key={i} variant="outline" className="text-xs shrink-0 bg-blue-100 text-blue-800 border-blue-300 dark:bg-blue-900/30 dark:text-blue-200 dark:border-blue-700">
                  {holiday}
                </Badge>
              ))}
              {chanukahDay && (
                <Badge className="text-xs gap-1 shrink-0 bg-amber-500 text-black border-amber-600">
                  <Star className="h-3 w-3" />
                  Chanukah Day {chanukahDay}
                </Badge>
              )}
              {omerDay && (
                <Badge variant="outline" className="text-xs shrink-0 bg-green-100 text-green-800 border-green-300 dark:bg-green-900/30 dark:text-green-200 dark:border-green-700">
                  Omer {omerDay}
                </Badge>
              )}
            </div>
          )}
        </div>
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
            No enabled zmanim to preview
          </div>
        )}

        {hasCoverage && !loading && !error && preview.length > 0 && (
          <table className="w-full">
            <tbody>
              {preview.map((item) => (
                <tr
                  key={item.zman_key}
                  className="border-b border-border last:border-0"
                  data-testid={`preview-${item.zman_key}`}
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
