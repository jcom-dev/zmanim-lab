import { auth, currentUser } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';

export async function GET() {
  const authResult = await auth();
  const user = await currentUser();

  if (!authResult.userId) {
    return NextResponse.json({ error: 'Not authenticated' }, { status: 401 });
  }

  return NextResponse.json({
    auth: {
      userId: authResult.userId,
      orgId: authResult.orgId,
      orgRole: authResult.orgRole,
      sessionClaims: authResult.sessionClaims,
    },
    user: user ? {
      id: user.id,
      publicMetadata: user.publicMetadata,
      privateMetadata: user.privateMetadata,
      unsafeMetadata: user.unsafeMetadata,
    } : null,
  });
}
