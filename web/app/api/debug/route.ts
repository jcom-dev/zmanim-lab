import { auth } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';

export async function GET() {
  const { userId, sessionClaims, orgRole, orgId } = await auth();

  if (!userId) {
    return NextResponse.json({ error: 'Not authenticated' }, { status: 401 });
  }

  const claims = sessionClaims as any;

  return NextResponse.json({
    userId,
    orgId,
    orgRole,
    sessionClaims: {
      metadata: claims?.metadata,
      publicMetadata: claims?.publicMetadata,
      privateMetadata: claims?.privateMetadata,
    },
    roleCheck: {
      orgRole,
      metadata_role: claims?.metadata?.role,
      publicMetadata_role: claims?.publicMetadata?.role,
      normalizedRole: (orgRole || claims?.metadata?.role || claims?.publicMetadata?.role)?.replace('org:', ''),
    },
  });
}
