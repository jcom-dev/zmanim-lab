'use client';
import { API_BASE } from '@/lib/api';

import { useEffect, useState } from 'react';
import { Clock, MapPin, Calendar, Loader2, AlertCircle } from 'lucide-react';
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
  locationName = 'New York, NY',
  date = new Date(),
  className,
}: CalculationPreviewProps) {
  const [result, setResult] = useState<PreviewResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
            date: date.toISOString().split('T')[0],
          }),
          signal: controller.signal,
        });

        if (!response.ok) {
          const data = await response.json();
          throw new Error(data.error || 'Preview failed');
        }

        const data = await response.json();
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
  }, [formula, isValid, latitude, longitude, date]);

  const formatTime = (isoTime: string): string => {
    try {
      const d = new Date(isoTime);
      return d.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      });
    } catch {
      return isoTime;
    }
  };

  const formatDate = (d: Date): string => {
    return d.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className={cn('rounded-lg border bg-card p-4', className)}>
      <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
        <Clock className="h-4 w-4" />
        Live Preview
      </h3>

      {/* Location and date info */}
      <div className="text-xs text-muted-foreground space-y-1 mb-4">
        <div className="flex items-center gap-1">
          <MapPin className="h-3 w-3" />
          {locationName}
        </div>
        <div className="flex items-center gap-1">
          <Calendar className="h-3 w-3" />
          {formatDate(date)}
        </div>
      </div>

      {/* Result display */}
      <div className="min-h-[60px] flex items-center justify-center">
        {loading ? (
          <div className="flex items-center gap-2 text-muted-foreground">
            <Loader2 className="h-5 w-5 animate-spin" />
            <span className="text-sm">Calculating...</span>
          </div>
        ) : error ? (
          <div className="flex items-center gap-2 text-destructive">
            <AlertCircle className="h-5 w-5" />
            <span className="text-sm">{error}</span>
          </div>
        ) : result ? (
          <div className="text-center">
            <div className="text-3xl font-bold text-primary">
              {result.formatted}
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              {result.time}
            </div>
          </div>
        ) : (
          <div className="text-sm text-muted-foreground">
            {isValid ? 'Enter a formula to see preview' : 'Fix validation errors to see preview'}
          </div>
        )}
      </div>
    </div>
  );
}

export default CalculationPreview;
