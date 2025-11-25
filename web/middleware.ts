import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';

// Type augmentation for Clerk session claims with custom metadata
interface CustomSessionClaims {
  metadata?: {
    role?: string;
  };
}

// Routes that require authentication
const isPublisherRoute = createRouteMatcher(['/publisher(.*)']);
const isAdminRoute = createRouteMatcher(['/admin(.*)']);

export default clerkMiddleware(async (auth, req) => {
  // DEVELOPMENT MODE: Set to true to bypass role checks
  const DEV_BYPASS_ROLES = process.env.NODE_ENV === 'development';

  // Publisher routes require publisher or admin role
  if (isPublisherRoute(req)) {
    const { userId, sessionClaims, orgRole } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    if (!DEV_BYPASS_ROLES) {
      // Check for role in multiple places (same as admin check)
      const claims = sessionClaims as any;
      const role =
        orgRole || // Clerk org role (e.g., "org:publisher")
        claims?.metadata?.role || // Custom metadata
        claims?.publicMetadata?.role; // Public metadata

      // Normalize role: handle both "publisher" and "org:publisher" formats
      const normalizedRole = role?.replace('org:', '');

      if (normalizedRole !== 'publisher' && normalizedRole !== 'admin') {
        return new NextResponse('Forbidden: Publisher role required', { status: 403 });
      }
    }
  }

  // Admin routes require admin role
  if (isAdminRoute(req)) {
    const { userId, sessionClaims, orgRole } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    if (!DEV_BYPASS_ROLES) {
      // Check for role in multiple places:
      // 1. Clerk organization role (if using organizations)
      // 2. Custom metadata role (if using custom claims)
      // 3. Public metadata (alternative location)
      const claims = sessionClaims as any;
      const role =
        orgRole || // Clerk org role (e.g., "org:admin")
        claims?.metadata?.role || // Custom metadata
        claims?.publicMetadata?.role; // Public metadata

      // Normalize role: handle both "admin" and "org:admin" formats
      const normalizedRole = role?.replace('org:', '');

      if (normalizedRole !== 'admin') {
        // Debug logging
        console.log('Admin access denied:', {
          userId,
          orgRole,
          normalizedRole,
          metadata_role: claims?.metadata?.role,
          publicMetadata_role: claims?.publicMetadata?.role,
        });
        return new NextResponse('Forbidden: Admin role required', { status: 403 });
      }
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
