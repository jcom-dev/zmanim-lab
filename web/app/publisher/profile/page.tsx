'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { usePublisherContext } from '@/providers/PublisherContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { LogoUpload } from '@/components/publisher/LogoUpload';
import { useApi } from '@/lib/api-client';

interface PublisherProfile {
  id: string;
  name: string;
  email: string;
  website?: string;
  bio?: string;
  logo_url?: string;
  status: string;
}

export default function PublisherProfilePage() {
  const router = useRouter();
  const api = useApi();
  const { selectedPublisher, isLoading: contextLoading, error: contextError } = usePublisherContext();
  const [profile, setProfile] = useState<PublisherProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [loadingTimeout, setLoadingTimeout] = useState(false);

  // Form state
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [bio, setBio] = useState('');

  const loadProfile = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setLoading(true);
      setError(null);

      const profileData = await api.get<PublisherProfile>('/publisher/profile');

      setProfile(profileData);
      setName(profileData.name || '');
      setEmail(profileData.email || '');
      setWebsite(profileData.website || '');
      setBio(profileData.bio || '');
    } catch (err) {
      console.error('Failed to load profile:', err);
      setError('Failed to load profile. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [api, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      loadProfile();
    }
  }, [selectedPublisher, loadProfile]);

  // Add timeout for context loading
  useEffect(() => {
    const timer = setTimeout(() => {
      if (contextLoading || !selectedPublisher) {
        setLoadingTimeout(true);
        setLoading(false);
      }
    }, 10000); // 10 second timeout

    return () => clearTimeout(timer);
  }, [contextLoading, selectedPublisher]);

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

      const updatedProfile = await api.put<PublisherProfile>('/publisher/profile', {
        body: JSON.stringify({
          name,
          email,
          website: website || null,
          bio: bio || null,
        }),
      });

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

  // Show loading only if not timed out
  if ((contextLoading || loading) && !loadingTimeout) {
    return (
      <div className="min-h-screen bg-background p-4 md:p-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex justify-center items-center h-64">
            <div className="text-center">
              <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-current border-r-transparent align-[-0.125em] motion-reduce:animate-[spin_1.5s_linear_infinite]"></div>
              <p className="mt-4 text-muted-foreground">Loading profile...</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Show error if context failed, timeout occurred, or no publisher selected
  if (contextError || loadingTimeout || error || !selectedPublisher) {
    const errorMessage = contextError || error ||
      (!selectedPublisher ? 'No publisher account found. Please contact support if you believe this is an error.' : 'Request timed out. Please try again.');

    return (
      <div className="min-h-screen bg-background p-4 md:p-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg p-6">
            <div className="flex items-start gap-3">
              <svg className="w-5 h-5 text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <div className="flex-1">
                <p className="font-semibold text-red-800 dark:text-red-200 mb-2">Unable to Load Profile</p>
                <p className="text-red-700 dark:text-red-300 text-sm mb-4">{errorMessage}</p>
                <button
                  onClick={() => window.location.reload()}
                  className="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 text-sm font-medium"
                >
                  Reload Page
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground mb-2">Publisher Profile</h1>
          <p className="text-muted-foreground">Manage your profile information</p>
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
              {/* Name (Publisher/Organization Name) */}
              <div>
                <label htmlFor="name" className="block text-sm font-medium mb-2">
                  Publisher / Organization Name *
                </label>
                <Input
                  id="name"
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Congregation Beth Israel"
                  required
                />
                <p className="mt-1 text-sm text-muted-foreground">
                  This will be the name displayed to users
                </p>
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
                  placeholder="Tell users about your community and approach to zmanim..."
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
                  publisherName={name}
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
                  className={`px-3 py-1 rounded-full text-sm font-medium ${profile.status === 'verified'
                      ? 'bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-300'
                      : profile.status === 'pending'
                        ? 'bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-300'
                        : 'bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-300'
                    }`}
                >
                  {profile.status}
                </span>
              </div>
              {profile.status === 'pending' && (
                <p className="text-sm text-muted-foreground mt-2">
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
