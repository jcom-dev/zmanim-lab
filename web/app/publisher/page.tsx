'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function PublisherPage() {
  const router = useRouter();

  useEffect(() => {
    // Redirect to publisher dashboard
    router.replace('/publisher/dashboard');
  }, [router]);

  return (
    <div className="min-h-screen bg-background flex items-center justify-center">
      <div className="text-foreground">Redirecting to dashboard...</div>
    </div>
  );
}
