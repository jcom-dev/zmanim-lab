import { clerkMiddleware, clerkClient, createRouteMatcher } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';

// Routes that require authentication
const isPublisherRoute = createRouteMatcher(['/publisher(.*)']);
const isAdminRoute = createRouteMatcher(['/admin(.*)']);

// Helper to get user role from Clerk
async function getUserRole(userId: string): Promise<string | null> {
  try {
    const client = await clerkClient();
    const user = await client.users.getUser(userId);
    return (user.publicMetadata?.role as string) || null;
  } catch (error) {
    console.error('Failed to fetch user:', error);
    return null;
  }
}

export default clerkMiddleware(async (auth, req) => {
  // Publisher routes require publisher or admin role
  if (isPublisherRoute(req)) {
    const { userId } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    const role = await getUserRole(userId);
    if (role !== 'publisher' && role !== 'admin') {
      console.log('Publisher access denied:', { userId, role });
      return new NextResponse('Forbidden: Publisher role required', { status: 403 });
    }
  }

  // Admin routes require admin role
  if (isAdminRoute(req)) {
    const { userId } = await auth();
    if (!userId) {
      const signInUrl = new URL('/sign-in', req.url);
      signInUrl.searchParams.set('redirect_url', req.url);
      return NextResponse.redirect(signInUrl);
    }

    const role = await getUserRole(userId);
    if (role !== 'admin') {
      console.log('Admin access denied:', { userId, role });
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
