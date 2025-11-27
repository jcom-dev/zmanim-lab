import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';

// Routes that require authentication
const isPublisherRoute = createRouteMatcher(['/publisher(.*)']);
const isAdminRoute = createRouteMatcher(['/admin(.*)']);

// Helper to extract role from session claims
// Clerk session token must be customized to include: {"metadata": "{{user.public_metadata}}"}
function getRoleFromClaims(sessionClaims: any): string | null {
  return sessionClaims?.metadata?.role || null;
}

export default clerkMiddleware(async (auth, req) => {
  // Publisher routes require publisher or admin role
  if (isPublisherRoute(req)) {
    const { userId, sessionClaims } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    const role = getRoleFromClaims(sessionClaims);
    if (role !== 'publisher' && role !== 'admin') {
      // Access denied - role check failed
      return new NextResponse('Forbidden: Publisher role required', { status: 403 });
    }
  }

  // Admin routes require admin role
  if (isAdminRoute(req)) {
    const { userId, sessionClaims } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    const role = getRoleFromClaims(sessionClaims);
    if (role !== 'admin') {
      // Access denied - admin role required
      return new NextResponse('Forbidden: Admin role required', { status: 403 });
    }
  }

  // Explicitly return to allow request to proceed
  return NextResponse.next();
});

export const config = {
  matcher: [
    // Skip Next.js internals and all static files
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
};
