'use client';

import { useEffect, useState, Suspense } from 'react';
import { useUser, useAuth } from '@clerk/nextjs';
import { useRouter, useSearchParams } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import Link from 'next/link';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

function AcceptInvitationContent() {
  const { isLoaded, isSignedIn, user } = useUser();
  const { getToken } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token');

  const [status, setStatus] = useState<'loading' | 'accepting' | 'success' | 'error' | 'redirect'>('loading');
  const [error, setError] = useState<string | null>(null);
  const [publisherName, setPublisherName] = useState<string | null>(null);

  useEffect(() => {
    if (!isLoaded) return;

    // If there's a token, this is a publisher team invitation
    if (token) {
      if (!isSignedIn) {
        // User needs to sign in first
        // Preserve the token in the URL after sign-in
        const returnUrl = `/accept-invitation?token=${encodeURIComponent(token)}`;
        router.push(`/sign-in?redirect_url=${encodeURIComponent(returnUrl)}`);
        return;
      }

      // User is signed in, accept the invitation
      acceptInvitation();
    } else {
      // No token - this is the old Clerk invitation flow
      handleClerkInvitation();
    }
  }, [isLoaded, isSignedIn, token]);

  const acceptInvitation = async () => {
    if (!token) return;

    setStatus('accepting');

    try {
      const authToken = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/team/accept`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authToken}`,
        },
        body: JSON.stringify({ token }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.message || 'Failed to accept invitation');
        setStatus('error');
        return;
      }

      setPublisherName(data.publisher_name);
      setStatus('success');

      // Redirect to publisher dashboard after a short delay
      setTimeout(() => {
        router.push(`/publisher/dashboard`);
      }, 2000);
    } catch (err) {
      setError('Network error. Please try again.');
      setStatus('error');
    }
  };

  const handleClerkInvitation = () => {
    // Original Clerk invitation flow
    if (!isSignedIn || !user) {
      router.push('/sign-up');
      return;
    }

    const metadata = user.publicMetadata as { role?: string; publisher_access_list?: string[] };

    if (metadata?.role === 'publisher' && metadata?.publisher_access_list?.length) {
      router.push('/publisher/dashboard');
    } else {
      router.push('/');
    }
  };

  if (status === 'loading' || status === 'redirect') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="max-w-md w-full mx-4">
          <CardHeader className="text-center">
            <CardTitle>Welcome to Zmanim Lab!</CardTitle>
            <CardDescription>
              Setting up your account...
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
            <p className="mt-4 text-gray-600">
              Please wait while we redirect you.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (status === 'accepting') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="max-w-md w-full mx-4">
          <CardHeader className="text-center">
            <CardTitle>Accepting Invitation</CardTitle>
            <CardDescription>
              Please wait while we add you to the team...
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (status === 'success') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="max-w-md w-full mx-4 border-green-200 bg-green-50">
          <CardHeader className="text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg
                className="w-8 h-8 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
            <CardTitle className="text-green-800">Welcome to the Team!</CardTitle>
            <CardDescription className="text-green-700">
              You&apos;ve been added to {publisherName}
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <p className="text-green-700 mb-4">
              Redirecting you to the dashboard...
            </p>
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-green-600 mx-auto"></div>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="max-w-md w-full mx-4 border-red-200 bg-red-50">
          <CardHeader className="text-center">
            <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg
                className="w-8 h-8 text-red-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </div>
            <CardTitle className="text-red-800">Invitation Error</CardTitle>
            <CardDescription className="text-red-700">
              {error || 'This invitation is invalid or has expired.'}
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <p className="text-red-700 mb-6">
              Please contact the person who invited you to request a new invitation.
            </p>
            <Link href="/">
              <Button variant="outline" className="border-red-600 text-red-700 hover:bg-red-100">
                Return to Home
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return null;
}

export default function AcceptInvitationPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    }>
      <AcceptInvitationContent />
    </Suspense>
  );
}
