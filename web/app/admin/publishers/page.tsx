'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import Link from 'next/link';

interface Publisher {
  id: string;
  name: string;
  organization: string;
  email: string;
  status: 'pending' | 'verified' | 'suspended';
  clerk_user_id?: string;
  website?: string;
  logo_url?: string;
  bio?: string;
  created_at: string;
  updated_at: string;
}

export default function AdminPublishersPage() {
  const [publishers, setPublishers] = useState<Publisher[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  useEffect(() => {
    fetchPublishers();
  }, []);

  const fetchPublishers = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/v1/admin/publishers', {
        headers: {
          'Content-Type': 'application/json',
          // TODO: Add Clerk auth token when implemented
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch publishers');
      }

      const data = await response.json();
      setPublishers(data.data.publishers || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (publisherId: string, action: 'verify' | 'suspend' | 'reactivate') => {
    try {
      const endpoint = `/api/v1/admin/publishers/${publisherId}/${action}`;
      const response = await fetch(endpoint, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          // TODO: Add Clerk auth token when implemented
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

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'verified':
        return 'bg-green-100 text-green-800 border-green-300';
      case 'pending':
        return 'bg-yellow-100 text-yellow-800 border-yellow-300';
      case 'suspended':
        return 'bg-red-100 text-red-800 border-red-300';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-300';
    }
  };

  const filteredPublishers = publishers.filter((publisher) => {
    const matchesSearch =
      publisher.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      publisher.organization.toLowerCase().includes(searchTerm.toLowerCase()) ||
      publisher.email.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesStatus = statusFilter === 'all' || publisher.status === statusFilter;

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
        <Card className="border-red-300 bg-red-50">
          <CardHeader>
            <CardTitle className="text-red-800">Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-red-700">{error}</p>
            <Button onClick={fetchPublishers} className="mt-4" variant="outline">
              Retry
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold">Publisher Management</h1>
          <p className="text-gray-600 mt-1">Manage publisher accounts and permissions</p>
        </div>
        <Link href="/admin/publishers/new">
          <Button>Create New Publisher</Button>
        </Link>
      </div>

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
                className="w-full px-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
                    <td colSpan={6} className="py-8 text-center text-gray-500">
                      No publishers found
                    </td>
                  </tr>
                ) : (
                  filteredPublishers.map((publisher) => (
                    <tr key={publisher.id} className="border-b hover:bg-gray-50">
                      <td className="py-4">
                        <div className="font-medium">{publisher.name}</div>
                      </td>
                      <td className="py-4">{publisher.organization}</td>
                      <td className="py-4">
                        <a href={`mailto:${publisher.email}`} className="text-blue-600 hover:underline">
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
                      <td className="py-4 text-sm text-gray-600">
                        {new Date(publisher.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 text-right">
                        <div className="flex justify-end gap-2">
                          {publisher.status === 'pending' && (
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
