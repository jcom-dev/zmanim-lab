'use client';

import { useState, useEffect, useCallback } from 'react';
import Image from 'next/image';
import { useAuth } from '@clerk/nextjs';
import { useParams, useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import Link from 'next/link';
import { API_BASE } from '@/lib/api';

interface Publisher {
  id: string;
  name: string;
  organization: string;
  email?: string;
  status: string;
  website?: string;
  bio?: string;
  created_at: string;
  updated_at: string;
}

interface PublisherUser {
  clerk_user_id: string;
  email: string;
  name: string;
  image_url?: string;
  created_at: number;
}

export default function AdminPublisherDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const { getToken } = useAuth();
  const [publisher, setPublisher] = useState<Publisher | null>(null);
  const [users, setUsers] = useState<PublisherUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteDialogOpen, setInviteDialogOpen] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [inviteSuccess, setInviteSuccess] = useState<string | null>(null);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [editLoading, setEditLoading] = useState(false);
  const [editForm, setEditForm] = useState({
    name: '',
    organization: '',
    email: '',
    website: '',
    bio: '',
  });
  const [deleteLoading, setDeleteLoading] = useState(false);

  const fetchPublisher = useCallback(async () => {
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch publisher');
      }

      const data = await response.json();
      const publishers = data.data?.publishers || data.publishers || [];
      const found = publishers.find((p: Publisher) => p.id === id);

      if (!found) {
        throw new Error('Publisher not found');
      }

      setPublisher(found);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    }
  }, [getToken, id]);

  const fetchUsers = useCallback(async () => {
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}/users`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch users');
      }

      const data = await response.json();
      setUsers(data.data?.users || data.users || []);
    } catch (err) {
      console.error('Failed to fetch users:', err);
      // Don't set error for users - publisher may have no users yet
      setUsers([]);
    }
  }, [getToken, id]);

  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await Promise.all([fetchPublisher(), fetchUsers()]);
      setLoading(false);
    };
    loadData();
  }, [fetchPublisher, fetchUsers]);

  const handleInviteUser = async () => {
    if (!inviteEmail.trim()) {
      setInviteError('Email is required');
      return;
    }

    try {
      setInviteLoading(true);
      setInviteError(null);
      setInviteSuccess(null);

      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}/users/invite`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({ email: inviteEmail }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || data.message || 'Failed to invite user');
      }

      setInviteSuccess(data.data?.message || data.message || 'Invitation sent successfully');
      setInviteEmail('');
      await fetchUsers();

      // Close dialog after short delay to show success message
      setTimeout(() => {
        setInviteDialogOpen(false);
        setInviteSuccess(null);
      }, 2000);
    } catch (err) {
      setInviteError(err instanceof Error ? err.message : 'Failed to invite user');
    } finally {
      setInviteLoading(false);
    }
  };

  const handleRemoveUser = async (userId: string) => {
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}/users/${userId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to remove user');
      }

      await fetchUsers();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove user');
    }
  };

  const handleStatusChange = async (action: 'verify' | 'suspend' | 'reactivate') => {
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}/${action}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to ${action} publisher`);
      }

      await fetchPublisher();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    }
  };

  const handleEditPublisher = async () => {
    try {
      setEditLoading(true);
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(editForm),
      });

      if (!response.ok) {
        throw new Error('Failed to update publisher');
      }

      await fetchPublisher();
      setEditDialogOpen(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setEditLoading(false);
    }
  };

  const handleDeletePublisher = async () => {
    try {
      setDeleteLoading(true);
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/admin/publishers/${id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to delete publisher');
      }

      router.push('/admin/publishers');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      setDeleteLoading(false);
    }
  };

  const openEditDialog = () => {
    if (publisher) {
      setEditForm({
        name: publisher.name || '',
        organization: publisher.organization || '',
        email: publisher.email || '',
        website: publisher.website || '',
        bio: publisher.bio || '',
      });
      setEditDialogOpen(true);
    }
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'verified':
        return 'bg-green-100 text-green-800 border-green-300';
      case 'pending_verification':
      case 'pending':
        return 'bg-yellow-100 text-yellow-800 border-yellow-300';
      case 'suspended':
        return 'bg-red-100 text-red-800 border-red-300';
      default:
        return 'bg-muted text-muted-foreground border-border';
    }
  };

  if (loading) {
    return (
      <div className="container mx-auto py-8">
        <div className="text-center">Loading publisher details...</div>
      </div>
    );
  }

  if (error || !publisher) {
    return (
      <div className="container mx-auto py-8">
        <Card className="border-red-300 bg-red-50 dark:border-red-700 dark:bg-red-950">
          <CardHeader>
            <CardTitle className="text-red-800 dark:text-red-200">Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-red-700 dark:text-red-300">{error || 'Publisher not found'}</p>
            <Link href="/admin/publishers">
              <Button className="mt-4" variant="outline">
                Back to Publishers
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8">
      {/* Header */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <div className="flex items-center gap-2 mb-2">
            <Link href="/admin/publishers" className="text-blue-600 dark:text-blue-400 hover:underline text-sm">
              Publishers
            </Link>
            <span className="text-muted-foreground">/</span>
            <span className="text-muted-foreground">{publisher.name}</span>
          </div>
          <h1 className="text-3xl font-bold">{publisher.name}</h1>
          <p className="text-muted-foreground">{publisher.organization}</p>
        </div>
        <span
          className={`inline-block px-4 py-2 rounded-full text-sm font-semibold border ${getStatusBadgeClass(
            publisher.status
          )}`}
        >
          {publisher.status.replace('_', ' ')}
        </span>
      </div>

      {/* Actions Card */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
        </CardHeader>
        <CardContent>
          <Button
            onClick={() => {
              // Store impersonation state in sessionStorage
              sessionStorage.setItem('impersonating', JSON.stringify({
                publisherId: publisher.id,
                publisher: {
                  id: publisher.id,
                  name: publisher.name,
                  organization: publisher.organization,
                  status: publisher.status,
                }
              }));
              router.push('/publisher/dashboard');
            }}
            className="bg-yellow-600 hover:bg-yellow-700 dark:bg-yellow-600 dark:hover:bg-yellow-700 text-white"
          >
            <svg className="w-4 h-4 mr-2" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            Impersonate Publisher
          </Button>
          <p className="text-sm text-muted-foreground mt-2">
            View the dashboard as this publisher to troubleshoot issues
          </p>
        </CardContent>
      </Card>

      {/* Publisher Details Card */}
      <Card className="mb-6">
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Publisher Details</CardTitle>
          <div className="flex gap-2">
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
              <DialogTrigger asChild>
                <Button variant="outline" size="sm" onClick={openEditDialog}>
                  Edit
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-md">
                <DialogHeader>
                  <DialogTitle>Edit Publisher</DialogTitle>
                  <DialogDescription>
                    Update the publisher&apos;s information.
                  </DialogDescription>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div>
                    <label className="text-sm font-medium">Name</label>
                    <Input
                      value={editForm.name}
                      onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                      placeholder="Publisher name"
                    />
                  </div>
                  <div>
                    <label className="text-sm font-medium">Organization</label>
                    <Input
                      value={editForm.organization}
                      onChange={(e) => setEditForm({ ...editForm, organization: e.target.value })}
                      placeholder="Organization name"
                    />
                  </div>
                  <div>
                    <label className="text-sm font-medium">Email</label>
                    <Input
                      type="email"
                      value={editForm.email}
                      onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                      placeholder="contact@example.com"
                    />
                  </div>
                  <div>
                    <label className="text-sm font-medium">Website</label>
                    <Input
                      type="url"
                      value={editForm.website}
                      onChange={(e) => setEditForm({ ...editForm, website: e.target.value })}
                      placeholder="https://example.com"
                    />
                  </div>
                  <div>
                    <label className="text-sm font-medium">Bio</label>
                    <textarea
                      className="w-full px-3 py-2 border border-border rounded-md bg-background text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary min-h-[80px]"
                      value={editForm.bio}
                      onChange={(e) => setEditForm({ ...editForm, bio: e.target.value })}
                      placeholder="About this publisher..."
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setEditDialogOpen(false)} disabled={editLoading}>
                    Cancel
                  </Button>
                  <Button onClick={handleEditPublisher} disabled={editLoading}>
                    {editLoading ? 'Saving...' : 'Save Changes'}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="destructive" size="sm">
                  Delete
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete Publisher</AlertDialogTitle>
                  <AlertDialogDescription>
                    Are you sure you want to delete &quot;{publisher.name}&quot;? This action cannot be undone.
                    <br /><br />
                    <strong>This will:</strong>
                    <ul className="list-disc list-inside mt-2 text-sm">
                      <li>Delete all publisher data (algorithms, coverage, etc.)</li>
                      <li>Remove access for all users linked to this publisher</li>
                      <li>Delete Clerk users who only had access to this publisher</li>
                    </ul>
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction
                    onClick={handleDeletePublisher}
                    disabled={deleteLoading}
                    className="bg-red-600 hover:bg-red-700"
                  >
                    {deleteLoading ? 'Deleting...' : 'Delete Publisher'}
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-sm font-medium text-muted-foreground">Email</label>
              <p>{publisher.email || 'Not set'}</p>
            </div>
            <div>
              <label className="text-sm font-medium text-muted-foreground">Website</label>
              <p>{publisher.website || 'Not set'}</p>
            </div>
            <div>
              <label className="text-sm font-medium text-muted-foreground">Created</label>
              <p>{new Date(publisher.created_at).toLocaleDateString()}</p>
            </div>
            <div>
              <label className="text-sm font-medium text-muted-foreground">Updated</label>
              <p>{new Date(publisher.updated_at).toLocaleDateString()}</p>
            </div>
            {publisher.bio && (
              <div className="col-span-2">
                <label className="text-sm font-medium text-muted-foreground">Bio</label>
                <p>{publisher.bio}</p>
              </div>
            )}
          </div>

          {/* Status Actions */}
          <div className="mt-6 pt-4 border-t flex gap-2">
            {(publisher.status === 'pending_verification' || publisher.status === 'pending') && (
              <Button onClick={() => handleStatusChange('verify')}>
                Verify Publisher
              </Button>
            )}
            {publisher.status === 'verified' && (
              <Button variant="destructive" onClick={() => handleStatusChange('suspend')}>
                Suspend Publisher
              </Button>
            )}
            {publisher.status === 'suspended' && (
              <Button variant="outline" onClick={() => handleStatusChange('reactivate')}>
                Reactivate Publisher
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Users Section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Users</CardTitle>
            <CardDescription>
              Users who can manage this publisher account
            </CardDescription>
          </div>
          <Dialog open={inviteDialogOpen} onOpenChange={setInviteDialogOpen}>
            <DialogTrigger asChild>
              <Button>Invite User</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Invite User to Publisher</DialogTitle>
                <DialogDescription>
                  Send an invitation email to allow a user to manage this publisher.
                  If the user already exists, they will be granted access immediately.
                </DialogDescription>
              </DialogHeader>
              <div className="py-4">
                <Input
                  type="email"
                  placeholder="user@example.com"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  disabled={inviteLoading}
                />
                {inviteError && (
                  <p className="text-destructive text-sm mt-2">{inviteError}</p>
                )}
                {inviteSuccess && (
                  <p className="text-green-600 dark:text-green-400 text-sm mt-2">{inviteSuccess}</p>
                )}
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setInviteDialogOpen(false)} disabled={inviteLoading}>
                  Cancel
                </Button>
                <Button onClick={handleInviteUser} disabled={inviteLoading}>
                  {inviteLoading ? 'Sending...' : 'Send Invitation'}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </CardHeader>
        <CardContent>
          {users.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <p>No users have access to this publisher yet.</p>
              <p className="text-sm mt-2">Click &quot;Invite User&quot; to add someone.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="border-b">
                  <tr className="text-left">
                    <th className="pb-3 font-semibold">User</th>
                    <th className="pb-3 font-semibold">Email</th>
                    <th className="pb-3 font-semibold">Joined</th>
                    <th className="pb-3 font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((user) => (
                    <tr key={user.clerk_user_id} className="border-b hover:bg-accent/50">
                      <td className="py-4">
                        <div className="flex items-center gap-3">
                          {user.image_url ? (
                            <div className="relative w-8 h-8">
                              <Image
                                src={user.image_url}
                                alt={user.name}
                                fill
                                className="rounded-full object-cover"
                                unoptimized
                              />
                            </div>
                          ) : (
                            <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                              <span className="text-muted-foreground text-sm">
                                {user.name?.charAt(0) || user.email?.charAt(0) || '?'}
                              </span>
                            </div>
                          )}
                          <span className="font-medium">{user.name || 'Unknown'}</span>
                        </div>
                      </td>
                      <td className="py-4">
                        <a href={`mailto:${user.email}`} className="text-blue-600 dark:text-blue-400 hover:underline">
                          {user.email}
                        </a>
                      </td>
                      <td className="py-4 text-sm text-muted-foreground">
                        {new Date(user.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 text-right">
                        <AlertDialog>
                          <AlertDialogTrigger asChild>
                            <Button variant="destructive" size="sm">
                              Remove
                            </Button>
                          </AlertDialogTrigger>
                          <AlertDialogContent>
                            <AlertDialogHeader>
                              <AlertDialogTitle>Remove User Access</AlertDialogTitle>
                              <AlertDialogDescription>
                                Are you sure you want to remove {user.name || user.email} from this publisher?
                                They will no longer be able to manage this publisher account.
                              </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                              <AlertDialogCancel>Cancel</AlertDialogCancel>
                              <AlertDialogAction onClick={() => handleRemoveUser(user.clerk_user_id)}>
                                Remove
                              </AlertDialogAction>
                            </AlertDialogFooter>
                          </AlertDialogContent>
                        </AlertDialog>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
