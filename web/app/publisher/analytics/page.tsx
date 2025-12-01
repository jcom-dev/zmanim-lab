'use client';

import { useState, useEffect, useCallback } from 'react';
import { usePublisherContext } from '@/providers/PublisherContext';
import { BarChart3, Globe, Calculator, Calendar, MapPin, Loader2 } from 'lucide-react';
import { useApi } from '@/lib/api-client';

interface Analytics {
  calculations_total: number;
  calculations_this_month: number;
  coverage_areas: number;
  cities_covered: number;
}

export default function PublisherAnalyticsPage() {
  const api = useApi();
  const { selectedPublisher, isLoading: contextLoading } = usePublisherContext();
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAnalytics = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setIsLoading(true);
      setError(null);

      const data = await api.get<Analytics>('/publisher/analytics');
      setAnalytics(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analytics');
    } finally {
      setIsLoading(false);
    }
  }, [api, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      fetchAnalytics();
    }
  }, [selectedPublisher, fetchAnalytics]);

  if (contextLoading || isLoading) {
    return (
      <div className="p-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center py-12">
            <Loader2 className="w-8 h-8 text-blue-600 dark:text-blue-400 animate-spin mx-auto" />
            <p className="mt-4 text-muted-foreground">Loading analytics...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-red-900/50 border border-red-700 dark:bg-red-950 dark:border-red-700 rounded-lg p-4">
            <p className="text-red-200 dark:text-red-300">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const hasActivity = analytics && (analytics.calculations_total > 0 || analytics.coverage_areas > 0);

  return (
    <div className="p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-4 md:mb-8">
          <h1 className="text-3xl font-bold">Analytics</h1>
          <p className="text-muted-foreground mt-1">
            View usage statistics for your zmanim
          </p>
        </div>

        {/* Empty State */}
        {!hasActivity && (
          <div className="bg-card rounded-lg border border-border p-12 text-center">
            <BarChart3 className="w-16 h-16 mx-auto text-muted-foreground mb-4" />
            <h2 className="text-xl font-semibold mb-2">No activity yet</h2>
            <p className="text-muted-foreground max-w-md mx-auto">
              Once users start viewing your zmanim and you add coverage areas,
              you&apos;ll see statistics here.
            </p>
          </div>
        )}

        {/* Stats Cards */}
        {hasActivity && analytics && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div className="bg-card rounded-lg border border-border p-6">
              <div className="flex items-center gap-2 text-muted-foreground mb-3">
                <Calculator className="w-5 h-5" />
                <span className="text-sm font-medium">Total Calculations</span>
              </div>
              <p className="text-4xl font-bold text-foreground">
                {analytics.calculations_total.toLocaleString()}
              </p>
              <p className="text-muted-foreground text-sm mt-1">all time</p>
            </div>

            <div className="bg-card rounded-lg border border-border p-6">
              <div className="flex items-center gap-2 text-muted-foreground mb-3">
                <Calendar className="w-5 h-5" />
                <span className="text-sm font-medium">This Month</span>
              </div>
              <p className="text-4xl font-bold text-foreground">
                {analytics.calculations_this_month.toLocaleString()}
              </p>
              <p className="text-muted-foreground text-sm mt-1">calculations</p>
            </div>

            <div className="bg-card rounded-lg border border-border p-6">
              <div className="flex items-center gap-2 text-muted-foreground mb-3">
                <Globe className="w-5 h-5" />
                <span className="text-sm font-medium">Coverage Areas</span>
              </div>
              <p className="text-4xl font-bold text-foreground">
                {analytics.coverage_areas.toLocaleString()}
              </p>
              <p className="text-muted-foreground text-sm mt-1">active areas</p>
            </div>

            <div className="bg-card rounded-lg border border-border p-6">
              <div className="flex items-center gap-2 text-muted-foreground mb-3">
                <MapPin className="w-5 h-5" />
                <span className="text-sm font-medium">Cities Covered</span>
              </div>
              <p className="text-4xl font-bold text-foreground">
                {analytics.cities_covered.toLocaleString()}
              </p>
              <p className="text-muted-foreground text-sm mt-1">total cities</p>
            </div>
          </div>
        )}

        {/* Coming Soon Note */}
        <div className="bg-card/50 rounded-lg border border-border p-6 text-center">
          <BarChart3 className="w-8 h-8 mx-auto text-muted-foreground mb-3" />
          <h3 className="text-lg font-semibold mb-2">Detailed Analytics Coming Soon</h3>
          <p className="text-muted-foreground text-sm max-w-md mx-auto">
            Charts, trends, geographic breakdowns, and more detailed statistics
            will be available in a future update.
          </p>
        </div>
      </div>
    </div>
  );
}
