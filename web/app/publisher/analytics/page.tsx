'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { BarChart3, Globe, Calculator, Calendar, MapPin, Loader2 } from 'lucide-react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface Analytics {
  calculations_total: number;
  calculations_this_month: number;
  coverage_areas: number;
  cities_covered: number;
}

export default function PublisherAnalyticsPage() {
  const { getToken } = useAuth();
  const { selectedPublisher, isLoading: contextLoading } = usePublisherContext();
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAnalytics = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setIsLoading(true);
      setError(null);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/analytics`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch analytics');
      }

      const data = await response.json();
      setAnalytics(data.data || data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analytics');
    } finally {
      setIsLoading(false);
    }
  }, [getToken, selectedPublisher]);

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
            <Loader2 className="w-8 h-8 text-blue-400 animate-spin mx-auto" />
            <p className="mt-4 text-gray-400">Loading analytics...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-red-900/50 border border-red-700 rounded-lg p-4">
            <p className="text-red-200">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const hasActivity = analytics && (analytics.calculations_total > 0 || analytics.coverage_areas > 0);

  return (
    <div className="p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold">Analytics</h1>
          <p className="text-gray-400 mt-1">
            View usage statistics for your zmanim
          </p>
        </div>

        {/* Empty State */}
        {!hasActivity && (
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-12 text-center">
            <BarChart3 className="w-16 h-16 mx-auto text-slate-600 mb-4" />
            <h2 className="text-xl font-semibold mb-2">No activity yet</h2>
            <p className="text-slate-400 max-w-md mx-auto">
              Once users start viewing your zmanim and you add coverage areas,
              you'll see statistics here.
            </p>
          </div>
        )}

        {/* Stats Cards */}
        {hasActivity && analytics && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
              <div className="flex items-center gap-2 text-slate-400 mb-3">
                <Calculator className="w-5 h-5" />
                <span className="text-sm font-medium">Total Calculations</span>
              </div>
              <p className="text-4xl font-bold text-white">
                {analytics.calculations_total.toLocaleString()}
              </p>
              <p className="text-slate-500 text-sm mt-1">all time</p>
            </div>

            <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
              <div className="flex items-center gap-2 text-slate-400 mb-3">
                <Calendar className="w-5 h-5" />
                <span className="text-sm font-medium">This Month</span>
              </div>
              <p className="text-4xl font-bold text-white">
                {analytics.calculations_this_month.toLocaleString()}
              </p>
              <p className="text-slate-500 text-sm mt-1">calculations</p>
            </div>

            <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
              <div className="flex items-center gap-2 text-slate-400 mb-3">
                <Globe className="w-5 h-5" />
                <span className="text-sm font-medium">Coverage Areas</span>
              </div>
              <p className="text-4xl font-bold text-white">
                {analytics.coverage_areas.toLocaleString()}
              </p>
              <p className="text-slate-500 text-sm mt-1">active areas</p>
            </div>

            <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
              <div className="flex items-center gap-2 text-slate-400 mb-3">
                <MapPin className="w-5 h-5" />
                <span className="text-sm font-medium">Cities Covered</span>
              </div>
              <p className="text-4xl font-bold text-white">
                {analytics.cities_covered.toLocaleString()}
              </p>
              <p className="text-slate-500 text-sm mt-1">total cities</p>
            </div>
          </div>
        )}

        {/* Coming Soon Note */}
        <div className="bg-slate-800/50 rounded-lg border border-slate-700/50 p-6 text-center">
          <BarChart3 className="w-8 h-8 mx-auto text-slate-500 mb-3" />
          <h3 className="text-lg font-semibold mb-2">Detailed Analytics Coming Soon</h3>
          <p className="text-slate-400 text-sm max-w-md mx-auto">
            Charts, trends, geographic breakdowns, and more detailed statistics
            will be available in a future update.
          </p>
        </div>
      </div>
    </div>
  );
}
