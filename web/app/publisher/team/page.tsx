'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
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

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface TeamMember {
  user_id: string;
  email: string;
  name: string;
  image_url?: string;
  added_at: string;
  is_owner: boolean;
}

interface PendingInvitation {
  id: string;
  email: string;
  status: string;
  expires_at: string;
  created_at: string;
}

export default function PublisherTeamPage() {
  const { getToken, userId } = useAuth();
  const { selectedPublisher } = usePublisherContext();
  const [members, setMembers] = useState<TeamMember[]>([]);
  const [invitations, setInvitations] = useState<PendingInvitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Invite dialog state
  const [inviteDialogOpen, setInviteDialogOpen] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);

  const fetchTeam = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setLoading(true);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch team');
      }

      const data = await response.json();
      setMembers(data.data?.members || data.members || []);
      setInvitations(data.data?.pending_invitations || data.pending_invitations || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [getToken, selectedPublisher]);

  useEffect(() => {
    fetchTeam();
  }, [fetchTeam]);

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    setInviteError(null);

    if (!inviteEmail.trim()) {
      setInviteError('Email is required');
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(inviteEmail)) {
      setInviteError('Please enter a valid email');
      return;
    }

    setInviteLoading(true);

    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team/invite`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher?.id || '',
        },
        body: JSON.stringify({ email: inviteEmail.trim().toLowerCase() }),
      });

      const data = await response.json();

      if (!response.ok) {
        setInviteError(data.message || 'Failed to send invitation');
        return;
      }

      setInviteEmail('');
      setInviteDialogOpen(false);
      fetchTeam();
    } catch (err) {
      setInviteError('Network error. Please try again.');
    } finally {
      setInviteLoading(false);
    }
  };

  const handleRemoveMember = async (memberUserId: string) => {
    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team/${memberUserId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher?.id || '',
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message || 'Failed to remove member');
      }

      fetchTeam();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove member');
    }
  };

  const handleResendInvitation = async (invitationId: string) => {
    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team/invitations/${invitationId}/resend`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher?.id || '',
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message || 'Failed to resend invitation');
      }

      fetchTeam();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to resend invitation');
    }
  };

  const handleCancelInvitation = async (invitationId: string) => {
    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team/invitations/${invitationId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher?.id || '',
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message || 'Failed to cancel invitation');
      }

      fetchTeam();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to cancel invitation');
    }
  };

  const getInitials = (name: string, email: string) => {
    if (name) {
      const parts = name.split(' ');
      return parts.length >= 2
        ? `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
        : name.substring(0, 2).toUpperCase();
    }
    return email.substring(0, 2).toUpperCase();
  };

  if (!selectedPublisher) {
    return (
      <div className="container mx-auto py-8">
        <Card>
          <CardContent className="py-8 text-center text-gray-500">
            Please select a publisher to manage team members
          </CardContent>
        </Card>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="container mx-auto py-8">
        <div className="text-center">Loading team...</div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold">Team Members</h1>
          <p className="text-gray-600 mt-1">Manage who can access {selectedPublisher.name}</p>
        </div>
        <Dialog open={inviteDialogOpen} onOpenChange={setInviteDialogOpen}>
          <DialogTrigger asChild>
            <Button>Invite Member</Button>
          </DialogTrigger>
          <DialogContent>
            <form onSubmit={handleInvite}>
              <DialogHeader>
                <DialogTitle>Invite Team Member</DialogTitle>
                <DialogDescription>
                  Send an invitation to join your publisher team. They&apos;ll receive an email with a link to
                  accept.
                </DialogDescription>
              </DialogHeader>
              <div className="py-4">
                {inviteError && (
                  <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-2 rounded-md text-sm">
                    {inviteError}
                  </div>
                )}
                <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                  Email Address
                </label>
                <input
                  type="email"
                  id="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="colleague@example.com"
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setInviteDialogOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={inviteLoading}>
                  {inviteLoading ? 'Sending...' : 'Send Invitation'}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {error && (
        <Card className="mb-6 border-red-300 bg-red-50">
          <CardContent className="py-4">
            <p className="text-red-700">{error}</p>
            <Button onClick={() => setError(null)} className="mt-2" variant="outline" size="sm">
              Dismiss
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Team Members */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Current Team ({members.length})</CardTitle>
          <CardDescription>People who can manage this publisher account</CardDescription>
        </CardHeader>
        <CardContent>
          {members.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No team members yet</p>
          ) : (
            <div className="space-y-4">
              {members.map((member) => (
                <div
                  key={member.user_id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex items-center gap-4">
                    {member.image_url ? (
                      <img
                        src={member.image_url}
                        alt={member.name || member.email}
                        className="w-10 h-10 rounded-full"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-medium">
                        {getInitials(member.name, member.email)}
                      </div>
                    )}
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium">{member.name || member.email}</span>
                        {member.is_owner && (
                          <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full">
                            Owner
                          </span>
                        )}
                      </div>
                      {member.name && (
                        <p className="text-sm text-gray-500">{member.email}</p>
                      )}
                      <p className="text-xs text-gray-400">
                        Added {new Date(member.added_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                  {!member.is_owner && member.user_id !== userId && (
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button variant="outline" size="sm" className="text-red-600 hover:text-red-700">
                          Remove
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>Remove Team Member</AlertDialogTitle>
                          <AlertDialogDescription>
                            Are you sure you want to remove {member.name || member.email} from the team? They
                            will no longer be able to access this publisher account.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction
                            onClick={() => handleRemoveMember(member.user_id)}
                            className="bg-red-600 hover:bg-red-700"
                          >
                            Remove
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  )}
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Pending Invitations */}
      {invitations.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Pending Invitations ({invitations.length})</CardTitle>
            <CardDescription>Invitations waiting to be accepted</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {invitations.map((invitation) => {
                const isExpired = invitation.status === 'expired' || new Date(invitation.expires_at) < new Date();
                return (
                  <div
                    key={invitation.id}
                    className={`flex items-center justify-between p-4 rounded-lg ${
                      isExpired ? 'bg-gray-100' : 'bg-yellow-50'
                    }`}
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium">{invitation.email}</span>
                        <span
                          className={`px-2 py-0.5 text-xs rounded-full ${
                            isExpired
                              ? 'bg-gray-200 text-gray-600'
                              : 'bg-yellow-100 text-yellow-700'
                          }`}
                        >
                          {isExpired ? 'Expired' : 'Pending'}
                        </span>
                      </div>
                      <p className="text-xs text-gray-500 mt-1">
                        Sent {new Date(invitation.created_at).toLocaleDateString()}
                        {!isExpired && (
                          <> &middot; Expires {new Date(invitation.expires_at).toLocaleDateString()}</>
                        )}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleResendInvitation(invitation.id)}
                      >
                        Resend
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        className="text-red-600 hover:text-red-700"
                        onClick={() => handleCancelInvitation(invitation.id)}
                      >
                        Cancel
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
