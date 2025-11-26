'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { useAuth } from '@clerk/nextjs';
import { User, MapPin, Code, BarChart3, AlertTriangle, Clock, Loader2, Plus, CheckCircle } from 'lucide-react';
import { usePublisherContext } from '@/providers/PublisherContext';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface DashboardSummary {
  profile: {
    name: string;
    organization: string;
    is_verified: boolean;
    status: string;
  };
  algorithm: {
    status: 'none' | 'draft' | 'published';
    name: string | null;
    updated_at: string | null;
  };
  coverage: {
    total_areas: number;
    total_cities: number;
  };
  analytics: {
    calculations_this_month: number;
    calculations_total: number;
  };
  recent_activity: Array<{
    action_type: string;
    description: string;
    created_at: string;
    actor_type: string;
  }>;
}

export default function PublisherDashboardPage() {
  const { getToken } = useAuth();
  const { selectedPublisher, isLoading: contextLoading } = usePublisherContext();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchDashboard = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setIsLoading(true);
      setError(null);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/dashboard`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch dashboard');
      }

      const data = await response.json();
      setSummary(data.data || data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard');
    } finally {
      setIsLoading(false);
    }
  }, [getToken, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      fetchDashboard();
    }
  }, [selectedPublisher, fetchDashboard]);

  if (contextLoading || isLoading) {
    return (
      <div className="p-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center py-12">
            <Loader2 className="w-8 h-8 text-blue-400 animate-spin mx-auto" />
            <p className="mt-4 text-gray-400">Loading dashboard...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <div className="max-w-6xl mx-auto">
          <div className="bg-red-900/50 border border-red-700 rounded-lg p-4">
            <p className="text-red-200">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Never';
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'verified':
        return <span className="flex items-center gap-1 text-green-400 text-sm"><CheckCircle className="w-4 h-4" /> Verified</span>;
      case 'pending':
      case 'pending_verification':
        return <span className="flex items-center gap-1 text-yellow-400 text-sm"><Clock className="w-4 h-4" /> Pending</span>;
      default:
        return <span className="text-gray-400 text-sm">{status}</span>;
    }
  };

  const getAlgorithmStatus = () => {
    if (!summary) return null;
    switch (summary.algorithm.status) {
      case 'published':
        return <span className="flex items-center gap-1 text-green-400 text-sm"><CheckCircle className="w-4 h-4" /> Published</span>;
      case 'draft':
        return (
          <span className="flex items-center gap-1 text-yellow-400 text-sm">
            <AlertTriangle className="w-4 h-4" /> Draft
          </span>
        );
      case 'none':
        return <span className="text-gray-500 text-sm">Not configured</span>;
      default:
        return null;
    }
  };

  return (
    <div className="p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold">Dashboard</h1>
          {selectedPublisher && (
            <p className="text-gray-400 mt-1">
              Managing: {selectedPublisher.name} ({selectedPublisher.organization})
            </p>
          )}
        </div>

        {/* Main Cards Grid */}
        <div className="grid gap-6 md:grid-cols-2 mb-8">
          {/* Profile Card */}
          <Link
            href="/publisher/profile"
            className="bg-slate-800 rounded-lg p-6 border border-slate-700 hover:border-slate-500 transition-colors group"
          >
            <div className="flex items-start justify-between mb-4">
              <User className="w-8 h-8 text-blue-500" />
              {summary && getStatusBadge(summary.profile.status)}
            </div>
            <h2 className="text-lg font-semibold mb-1 group-hover:text-blue-400 transition-colors">Profile</h2>
            {summary && (
              <>
                <p className="text-white">{summary.profile.name}</p>
                <p className="text-slate-400 text-sm">{summary.profile.organization}</p>
              </>
            )}
          </Link>

          {/* Zmanim Card */}
          <Link
            href="/publisher/algorithm"
            className={`bg-slate-800 rounded-lg p-6 border transition-colors group ${
              summary?.algorithm.status === 'draft'
                ? 'border-yellow-500/50 hover:border-yellow-500'
                : 'border-slate-700 hover:border-slate-500'
            }`}
          >
            <div className="flex items-start justify-between mb-4">
              <Code className="w-8 h-8 text-purple-500" />
              {getAlgorithmStatus()}
            </div>
            <h2 className="text-lg font-semibold mb-1 group-hover:text-purple-400 transition-colors">Zmanim</h2>
            {summary && (
              <>
                <p className="text-white">{summary.algorithm.name || 'No zmanim configured'}</p>
                <p className="text-slate-400 text-sm">
                  Updated: {formatDate(summary.algorithm.updated_at)}
                </p>
              </>
            )}
            {summary?.algorithm.status === 'draft' && (
              <div className="mt-3 flex items-center gap-2 text-yellow-400 text-sm">
                <AlertTriangle className="w-4 h-4" />
                Zmanim not published - users can't see your times
              </div>
            )}
          </Link>

          {/* Coverage Card */}
          <Link
            href="/publisher/coverage"
            className="bg-slate-800 rounded-lg p-6 border border-slate-700 hover:border-slate-500 transition-colors group"
          >
            <div className="flex items-start justify-between mb-4">
              <MapPin className="w-8 h-8 text-green-500" />
              {summary && summary.coverage.total_areas > 0 && (
                <span className="text-green-400 text-sm">{summary.coverage.total_areas} areas</span>
              )}
            </div>
            <h2 className="text-lg font-semibold mb-1 group-hover:text-green-400 transition-colors">Coverage</h2>
            {summary && summary.coverage.total_areas > 0 ? (
              <>
                <p className="text-white">{summary.coverage.total_areas} coverage areas</p>
                <p className="text-slate-400 text-sm">{summary.coverage.total_cities.toLocaleString()} cities covered</p>
              </>
            ) : (
              <div className="flex items-center gap-2 text-slate-400">
                <Plus className="w-4 h-4" />
                <span>Add your first coverage area</span>
              </div>
            )}
          </Link>

          {/* Analytics Card */}
          <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
            <div className="flex items-start justify-between mb-4">
              <BarChart3 className="w-8 h-8 text-orange-500" />
            </div>
            <h2 className="text-lg font-semibold mb-1">Analytics</h2>
            {summary && (
              <>
                <p className="text-3xl font-bold text-white">
                  {summary.analytics.calculations_this_month.toLocaleString()}
                </p>
                <p className="text-slate-400 text-sm">calculations this month</p>
              </>
            )}
            <p className="text-slate-500 text-xs mt-2">Coming soon in a future update</p>
          </div>
        </div>

        {/* Recent Activity Section */}
        <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
          <h2 className="text-lg font-semibold mb-4">Recent Activity</h2>
          {summary && summary.recent_activity.length > 0 ? (
            <div className="space-y-3">
              {summary.recent_activity.map((activity, index) => (
                <div key={index} className="flex items-center gap-3 py-2 border-b border-slate-700 last:border-0">
                  <Clock className="w-4 h-4 text-slate-500" />
                  <div className="flex-1">
                    <p className="text-white text-sm">{activity.description}</p>
                    <p className="text-slate-500 text-xs">
                      {formatDate(activity.created_at)} • {activity.actor_type}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-slate-500">
              <Clock className="w-8 h-8 mx-auto mb-2 opacity-50" />
              <p>No recent activity</p>
              <p className="text-xs mt-1">Activity will appear here as you make changes</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
