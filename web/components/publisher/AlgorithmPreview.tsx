'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface AlgorithmConfig {
  name: string;
  description?: string;
  zmanim: Record<string, ZmanConfig>;
}

interface PreviewZman {
  name: string;
  key: string;
  time: string;
  formula: {
    method: string;
    display_name: string;
    explanation: string;
  };
}

interface AlgorithmPreviewProps {
  configuration: AlgorithmConfig;
}

// Sample location for preview (Brooklyn, NY)
const PREVIEW_LOCATION = {
  latitude: 40.6782,
  longitude: -73.9442,
  timezone: 'America/New_York',
  name: 'Brooklyn, NY',
};

export function AlgorithmPreview({ configuration }: AlgorithmPreviewProps) {
  const [preview, setPreview] = useState<PreviewZman[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [date] = useState(() => new Date().toISOString().split('T')[0]);

  useEffect(() => {
    loadPreview();
  }, [configuration]);

  const loadPreview = async () => {
    if (Object.keys(configuration.zmanim).length === 0) {
      setPreview([]);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm/preview`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          configuration,
          date,
          latitude: PREVIEW_LOCATION.latitude,
          longitude: PREVIEW_LOCATION.longitude,
          timezone: PREVIEW_LOCATION.timezone,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to load preview');
      }

      const data = await response.json();
      setPreview(data.zmanim || []);
    } catch (err) {
      console.error('Failed to load preview:', err);
      setError('Failed to calculate preview');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card data-testid="algorithm-preview">
      <CardHeader>
        <CardTitle>Live Preview</CardTitle>
        <CardDescription>
          Today&apos;s zmanim for {PREVIEW_LOCATION.name}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {loading && (
          <div className="text-center py-4 text-slate-400">
            Calculating...
          </div>
        )}

        {error && (
          <div className="text-center py-4 text-red-400">
            {error}
          </div>
        )}

        {!loading && !error && preview.length === 0 && (
          <div className="text-center py-4 text-slate-400">
            Configure zmanim to see preview
          </div>
        )}

        {!loading && !error && preview.length > 0 && (
          <div className="space-y-3">
            {preview.map((zman) => (
              <div
                key={zman.key}
                className="flex justify-between items-center py-2 border-b border-slate-700 last:border-0"
                data-testid={`preview-${zman.key}`}
              >
                <div>
                  <div className="font-medium text-white text-sm">{zman.name}</div>
                  <div className="text-xs text-slate-400">{zman.formula.display_name}</div>
                </div>
                <div className="text-lg font-mono text-blue-400">{zman.time}</div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-4 pt-4 border-t border-slate-700">
          <p className="text-xs text-slate-500">
            Date: {date}
          </p>
          <p className="text-xs text-slate-500">
            Location: {PREVIEW_LOCATION.latitude.toFixed(4)}, {PREVIEW_LOCATION.longitude.toFixed(4)}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
