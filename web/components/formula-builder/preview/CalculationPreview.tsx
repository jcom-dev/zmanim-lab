'use client';
import { API_BASE } from '@/lib/api';

import { useEffect, useState, useMemo } from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CalculationPreviewProps {
  formula: string;
  isValid: boolean;
  latitude?: number;
  longitude?: number;
  locationName?: string;
  date?: Date;
  className?: string;
}

interface PreviewResult {
  time: string;
  formatted: string;
  success: boolean;
  error?: string;
}

export function CalculationPreview({
  formula,
  isValid,
  latitude = 40.7128,
  longitude = -74.006,
  date,
  className,
}: CalculationPreviewProps) {
  const [result, setResult] = useState<PreviewResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Stabilize date to prevent re-render loops when no date prop is passed
  const stableDate = useMemo(() => {
    if (date) return date;
    return new Date();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Only create once on mount

  const dateString = useMemo(() => {
    const d = date || stableDate;
    return d.toISOString().split('T')[0];
  }, [date, stableDate]);

  useEffect(() => {
    if (!isValid || !formula) {
      setResult(null);
      return;
    }

    const controller = new AbortController();

    const fetchPreview = async () => {
      setLoading(true);
      setError(null);

      try {
        const response = await fetch(`${API_BASE}/api/v1/dsl/preview`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            formula,
            latitude,
            longitude,
            date: dateString,
          }),
          signal: controller.signal,
        });

        if (!response.ok) {
          const data = await response.json();
          throw new Error(data.error || 'Preview failed');
        }

        const json = await response.json();
        const data = json.data || json; // Handle wrapped or direct response
        setResult({
          time: data.time || data.result,
          formatted: data.formatted || formatTime(data.time || data.result),
          success: true,
        });
      } catch (err) {
        if (err instanceof Error && err.name === 'AbortError') return;
        setError(err instanceof Error ? err.message : 'Preview failed');
        setResult(null);
      } finally {
        setLoading(false);
      }
    };

    // Debounce API calls
    const timeoutId = setTimeout(fetchPreview, 300);

    return () => {
      clearTimeout(timeoutId);
      controller.abort();
    };
  }, [formula, isValid, latitude, longitude, dateString]);

  const formatTime = (timeValue: string): string => {
    if (!timeValue) return timeValue;

    // If it's already a simple time string (HH:MM:SS or HH:MM), format it nicely
    const timeOnlyMatch = timeValue.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
    if (timeOnlyMatch) {
      const hours = parseInt(timeOnlyMatch[1], 10);
      const minutes = timeOnlyMatch[2];
      const seconds = timeOnlyMatch[3] || '00';
      const period = hours >= 12 ? 'PM' : 'AM';
      const displayHour = hours % 12 || 12;
      return `${displayHour}:${minutes}:${seconds} ${period}`;
    }

    // Try parsing as ISO date/time
    try {
      const d = new Date(timeValue);
      if (!isNaN(d.getTime())) {
        return d.toLocaleTimeString('en-US', {
          hour: 'numeric',
          minute: '2-digit',
          second: '2-digit',
          hour12: true,
        });
      }
    } catch {
      // Fall through to return original
    }

    return timeValue;
  };

  return (
    <div className={cn('rounded-lg border bg-card p-4 text-center', className)}>
      <div className="text-xs text-muted-foreground mb-2">Calculated Time</div>
      {loading ? (
        <Loader2 className="h-5 w-5 animate-spin text-muted-foreground mx-auto" />
      ) : error ? (
        <span className="text-sm text-destructive">{error}</span>
      ) : result ? (
        <span className="text-3xl font-bold font-mono text-primary">
          {result.formatted}
        </span>
      ) : (
        <span className="text-2xl font-mono text-muted-foreground">--:--</span>
      )}
    </div>
  );
}

export default CalculationPreview;
