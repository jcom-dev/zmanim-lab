import { auth } from '@clerk/nextjs/server';

export default async function DebugAuth() {
  const { userId, sessionClaims, orgRole } = await auth();

  return (
    <div className="p-8 font-mono">
      <h1 className="text-2xl font-bold mb-4">Auth Debug</h1>

      <div className="mb-4">
        <strong>User ID:</strong> {userId || 'Not signed in'}
      </div>

      <div className="mb-4">
        <strong>Org Role:</strong> {orgRole || 'None'}
      </div>

      <div className="mb-4">
        <strong>Session Claims:</strong>
        <pre className="bg-muted p-4 rounded mt-2 overflow-auto">
          {JSON.stringify(sessionClaims, null, 2)}
        </pre>
      </div>

      <div className="mb-4">
        <strong>Public Metadata Role:</strong> {(sessionClaims as any)?.publicMetadata?.role || 'Not set'}
      </div>

      <div className="mb-4">
        <strong>Metadata Role:</strong> {(sessionClaims as any)?.metadata?.role || 'Not set'}
      </div>
    </div>
  );
}
