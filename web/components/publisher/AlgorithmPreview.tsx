'use client';
import { API_BASE } from '@/lib/api';

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

export interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

interface AlgorithmPreviewProps {
  configuration: AlgorithmConfig;
  getToken: () => Promise<string | null>;
  location: PreviewLocation;
}

export function AlgorithmPreview({ configuration, getToken, location }: AlgorithmPreviewProps) {
  const [preview, setPreview] = useState<PreviewZman[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [date] = useState(() => new Date().toISOString().split('T')[0]);

  useEffect(() => {
    loadPreview();
  }, [configuration, location]);

  const loadPreview = async () => {
    if (Object.keys(configuration.zmanim).length === 0) {
      setPreview([]);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const token = await getToken();
      if (!token) {
        setError('Not authenticated');
        setLoading(false);
        return;
      }

      const response = await fetch(`${API_BASE}/api/v1/publisher/algorithm/preview`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          configuration,
          date,
          latitude: location.latitude,
          longitude: location.longitude,
          timezone: location.timezone,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to load preview');
      }

      const data = await response.json();
      setPreview(data.data?.zmanim || data.zmanim || []);
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
          Today&apos;s zmanim for {location.displayName}
        </CardDescription>
      </CardHeader>
      <CardContent>
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
            Configure zmanim to see preview
          </div>
        )}

        {!loading && !error && preview.length > 0 && (
          <div className="space-y-3">
            {preview.map((zman) => (
              <div
                key={zman.key}
                className="flex justify-between items-center py-2 border-b border-border last:border-0"
                data-testid={`preview-${zman.key}`}
              >
                <div>
                  <div className="font-medium text-foreground text-sm">{zman.name}</div>
                  <div className="text-xs text-muted-foreground">{zman.formula.display_name}</div>
                </div>
                <div className="text-lg font-mono text-primary">{zman.time}</div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-4 pt-4 border-t border-border">
          <p className="text-xs text-muted-foreground">
            Date: {date}
          </p>
          <p className="text-xs text-muted-foreground">
            Location: {location.latitude.toFixed(4)}, {location.longitude.toFixed(4)}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
