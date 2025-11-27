'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { LogoUpload } from '@/components/publisher/LogoUpload';

import { API_BASE } from '@/lib/api';

interface PublisherProfile {
  id: string;
  name: string;
  organization?: string;
  email: string;
  website?: string;
  bio?: string;
  logo_url?: string;
  status: string;
}

export default function PublisherProfilePage() {
  const router = useRouter();
  const { getToken } = useAuth();
  const { selectedPublisher } = usePublisherContext();
  const [profile, setProfile] = useState<PublisherProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Form state
  const [name, setName] = useState('');
  const [organization, setOrganization] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [bio, setBio] = useState('');

  const loadProfile = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setLoading(true);
      setError(null);

      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/publisher/profile`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to load profile');
      }

      const data = await response.json();
      const profileData = data.data || data;

      setProfile(profileData);
      setName(profileData.name || '');
      setOrganization(profileData.organization || '');
      setEmail(profileData.email || '');
      setWebsite(profileData.website || '');
      setBio(profileData.bio || '');
    } catch (err) {
      console.error('Failed to load profile:', err);
      setError('Failed to load profile. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [getToken, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      loadProfile();
    }
  }, [selectedPublisher, loadProfile]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSuccess(false);
    setError(null);

    // Validate required fields
    if (!name.trim()) {
      setError('Name is required');
      return;
    }
    if (!email.trim()) {
      setError('Email is required');
      return;
    }

    if (!selectedPublisher) {
      setError('No publisher selected');
      return;
    }

    try {
      setSaving(true);

      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/publisher/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
        body: JSON.stringify({
          name,
          organization: organization || null,
          email,
          website: website || null,
          bio: bio || null,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || 'Failed to update profile');
      }

      const data = await response.json();
      const updatedProfile = data.data || data;

      setProfile(updatedProfile);
      setSuccess(true);

      // Clear success message after 3 seconds
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error('Failed to update profile:', err);
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 p-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex justify-center items-center h-64">
            <div className="text-white">Loading profile...</div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-900 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Publisher Profile</h1>
          <p className="text-slate-400">Manage your profile information</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Profile Information</CardTitle>
            <CardDescription>
              Update your profile details. Required fields are marked with an asterisk (*).
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Name */}
              <div>
                <label htmlFor="name" className="block text-sm font-medium mb-2">
                  Name *
                </label>
                <Input
                  id="name"
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Your name"
                  required
                />
              </div>

              {/* Organization */}
              <div>
                <label htmlFor="organization" className="block text-sm font-medium mb-2">
                  Organization
                </label>
                <Input
                  id="organization"
                  type="text"
                  value={organization}
                  onChange={(e) => setOrganization(e.target.value)}
                  placeholder="Your organization or synagogue"
                />
              </div>

              {/* Email */}
              <div>
                <label htmlFor="email" className="block text-sm font-medium mb-2">
                  Contact Email *
                </label>
                <Input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="contact@example.com"
                  required
                />
              </div>

              {/* Website */}
              <div>
                <label htmlFor="website" className="block text-sm font-medium mb-2">
                  Website
                </label>
                <Input
                  id="website"
                  type="url"
                  value={website}
                  onChange={(e) => setWebsite(e.target.value)}
                  placeholder="https://example.com"
                />
              </div>

              {/* Bio */}
              <div>
                <label htmlFor="bio" className="block text-sm font-medium mb-2">
                  Bio
                </label>
                <textarea
                  id="bio"
                  value={bio}
                  onChange={(e) => setBio(e.target.value)}
                  placeholder="Tell users about your organization..."
                  rows={4}
                  className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                />
              </div>

              {/* Logo Upload */}
              <div>
                <label className="block text-sm font-medium mb-2">
                  Logo
                </label>
                <LogoUpload
                  currentLogoUrl={profile?.logo_url}
                  onUploadComplete={(logoUrl) => {
                    setProfile(prev => prev ? { ...prev, logo_url: logoUrl } : null);
                    setSuccess(true);
                    setTimeout(() => setSuccess(false), 3000);
                  }}
                  onUploadError={(errorMsg) => {
                    setError(errorMsg);
                  }}
                />
              </div>

              {/* Error Message */}
              {error && (
                <div className="bg-red-50 border border-red-200 rounded-md p-4">
                  <p className="text-red-800 text-sm">{error}</p>
                </div>
              )}

              {/* Success Message */}
              {success && (
                <div className="bg-green-50 border border-green-200 rounded-md p-4">
                  <p className="text-green-800 text-sm">Profile updated successfully!</p>
                </div>
              )}

              {/* Buttons */}
              <div className="flex gap-4">
                <Button type="submit" disabled={saving}>
                  {saving ? 'Saving...' : 'Save Changes'}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => router.push('/publisher/dashboard')}
                >
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>

        {/* Profile Status */}
        {profile && (
          <Card className="mt-6">
            <CardHeader>
              <CardTitle>Account Status</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center gap-3">
                <span className="text-sm font-medium">Status:</span>
                <span
                  className={`px-3 py-1 rounded-full text-sm font-medium ${
                    profile.status === 'verified'
                      ? 'bg-green-100 text-green-800'
                      : profile.status === 'pending'
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-red-100 text-red-800'
                  }`}
                >
                  {profile.status}
                </span>
              </div>
              {profile.status === 'pending' && (
                <p className="text-sm text-slate-600 mt-2">
                  Your profile is pending approval by an administrator.
                </p>
              )}
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
