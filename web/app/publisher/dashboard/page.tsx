import { UserButton } from '@clerk/nextjs';

export default function PublisherDashboardPage() {
  return (
    <div className="min-h-screen bg-slate-900 text-white p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Publisher Dashboard</h1>
          <UserButton afterSignOutUrl="/" />
        </div>
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <p className="text-slate-300">Welcome to the publisher dashboard. Algorithm configuration coming soon.</p>
        </div>
      </div>
    </div>
  );
}
