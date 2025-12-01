'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { PendingRequests } from '@/components/admin/PendingRequests';
import Link from 'next/link';

import { API_BASE } from '@/lib/api';
import { getStatusBadgeClasses } from '@/lib/badge-colors';

interface Publisher {
  id: string;
  name: string;
  organization: string;
  email: string;
  status: 'pending' | 'pending_verification' | 'verified' | 'suspended';
  clerk_user_id?: string;
  website?: string;
  logo_url?: string;
  bio?: string;
  created_at: string;
  updated_at: string;
}

export default function AdminPublishersPage() {
  const { getToken } = useAuth();
  const [publishers, setPublishers] = useState<Publisher[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  const fetchPublishers = useCallback(async () => {
    try {
      setLoading(true);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/admin/publishers`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch publishers');
      }

      const data = await response.json();
      // API wraps response in {data: {publishers: [...]}, meta: {...}}
      setPublishers(data.data?.publishers || data.publishers || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [getToken]);

  useEffect(() => {
    fetchPublishers();
  }, [fetchPublishers]);

  const handleStatusChange = async (publisherId: string, action: 'verify' | 'suspend' | 'reactivate') => {
    try {
      const token = await getToken();
      const endpoint = `${API_BASE}/api/v1/admin/publishers/${publisherId}/${action}`;
      const response = await fetch(endpoint, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to ${action} publisher`);
      }

      // Refresh the list
      await fetchPublishers();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    }
  };


  const filteredPublishers = publishers.filter((publisher) => {
    const matchesSearch =
      publisher.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      publisher.organization.toLowerCase().includes(searchTerm.toLowerCase()) ||
      publisher.email.toLowerCase().includes(searchTerm.toLowerCase());

    // Match pending filter to both 'pending' and 'pending_verification' statuses
    const matchesStatus = statusFilter === 'all' ||
      publisher.status === statusFilter ||
      (statusFilter === 'pending' && publisher.status === 'pending_verification');

    return matchesSearch && matchesStatus;
  });

  if (loading) {
    return (
      <div className="container mx-auto py-8">
        <div className="text-center">Loading publishers...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto py-8">
        <Card className="border-red-300 bg-red-50 dark:border-red-700 dark:bg-red-950">
          <CardHeader>
            <CardTitle className="text-red-800 dark:text-red-200">Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-red-700 dark:text-red-300">{error}</p>
            <Button onClick={fetchPublishers} className="mt-4" variant="outline">
              Retry
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:justify-between md:items-center gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold">Publisher Management</h1>
          <p className="text-sm md:text-base text-muted-foreground mt-1">Manage publisher accounts and permissions</p>
        </div>
        <Link href="/admin/publishers/new" className="w-full md:w-auto">
          <Button className="w-full md:w-auto">Create New Publisher</Button>
        </Link>
      </div>

      {/* Pending Requests */}
      <PendingRequests onApprove={fetchPublishers} />

      {/* Filters */}
      <Card className="mb-6">
        <CardContent className="pt-6">
          <div className="flex gap-4">
            <div className="flex-1">
              <input
                type="text"
                placeholder="Search by name, organization, or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full px-4 py-2 border border-border rounded-md bg-background text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
            <div>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-4 py-2 border border-border rounded-md bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="all">All Statuses</option>
                <option value="pending">Pending</option>
                <option value="verified">Verified</option>
                <option value="suspended">Suspended</option>
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Publishers Table */}
      <Card>
        <CardHeader>
          <CardTitle>Publishers ({filteredPublishers.length})</CardTitle>
          <CardDescription>
            {statusFilter !== 'all' ? `Showing ${statusFilter} publishers` : 'Showing all publishers'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b">
                <tr className="text-left">
                  <th className="pb-3 font-semibold">Name</th>
                  <th className="pb-3 font-semibold">Organization</th>
                  <th className="pb-3 font-semibold">Email</th>
                  <th className="pb-3 font-semibold">Status</th>
                  <th className="pb-3 font-semibold">Created</th>
                  <th className="pb-3 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredPublishers.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-muted-foreground">
                      No publishers found
                    </td>
                  </tr>
                ) : (
                  filteredPublishers.map((publisher) => (
                    <tr key={publisher.id} className="border-b hover:bg-accent/50">
                      <td className="py-4">
                        <Link href={`/admin/publishers/${publisher.id}`} className="font-medium text-blue-600 hover:underline">
                          {publisher.name}
                        </Link>
                      </td>
                      <td className="py-4">
                        <div className="max-w-[150px] md:max-w-none truncate">
                          {publisher.organization}
                        </div>
                      </td>
                      <td className="py-4">
                        <a
                          href={`mailto:${publisher.email}`}
                          className="text-blue-600 hover:underline block max-w-[150px] md:max-w-[250px] truncate"
                          title={publisher.email}
                        >
                          {publisher.email}
                        </a>
                      </td>
                      <td className="py-4">
                        <span
                          className={`inline-block px-3 py-1 rounded-full text-xs font-semibold border ${getStatusBadgeClass(
                            publisher.status
                          )}`}
                        >
                          {publisher.status}
                        </span>
                      </td>
                      <td className="py-4 text-sm text-muted-foreground">
                        {new Date(publisher.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 text-right">
                        <div className="flex justify-end gap-2">
                          <Link href={`/admin/publishers/${publisher.id}`}>
                            <Button size="sm" variant="outline">
                              View
                            </Button>
                          </Link>
                          {(publisher.status === 'pending' || publisher.status === 'pending_verification') && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleStatusChange(publisher.id, 'verify')}
                            >
                              Verify
                            </Button>
                          )}
                          {publisher.status === 'verified' && (
                            <Button
                              size="sm"
                              variant="destructive"
                              onClick={() => handleStatusChange(publisher.id, 'suspend')}
                            >
                              Suspend
                            </Button>
                          )}
                          {publisher.status === 'suspended' && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleStatusChange(publisher.id, 'reactivate')}
                            >
                              Reactivate
                            </Button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

// Note: The admin layout handles dark mode styling via className="dark"
