import { UserButton } from '@clerk/nextjs';
import Link from 'next/link';
import { User, MapPin, Settings } from 'lucide-react';

export default function PublisherDashboardPage() {
  return (
    <div className="min-h-screen bg-slate-900 text-white p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Publisher Dashboard</h1>
          <UserButton afterSignOutUrl="/" />
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Link
            href="/publisher/profile"
            className="bg-slate-800 rounded-lg p-6 border border-slate-700 hover:border-slate-500 transition-colors group"
          >
            <User className="w-8 h-8 text-blue-500 mb-3" />
            <h2 className="text-lg font-semibold mb-2 group-hover:text-blue-400 transition-colors">Profile</h2>
            <p className="text-slate-400 text-sm">Manage your profile information and logo</p>
          </Link>

          <Link
            href="/publisher/coverage"
            className="bg-slate-800 rounded-lg p-6 border border-slate-700 hover:border-slate-500 transition-colors group"
          >
            <MapPin className="w-8 h-8 text-green-500 mb-3" />
            <h2 className="text-lg font-semibold mb-2 group-hover:text-green-400 transition-colors">Coverage Areas</h2>
            <p className="text-slate-400 text-sm">Define where users can find your zmanim</p>
          </Link>

          <div className="bg-slate-800 rounded-lg p-6 border border-slate-700 opacity-60">
            <Settings className="w-8 h-8 text-purple-500 mb-3" />
            <h2 className="text-lg font-semibold mb-2">Algorithm Settings</h2>
            <p className="text-slate-400 text-sm">Configure your zmanim calculations (coming soon)</p>
          </div>
        </div>
      </div>
    </div>
  );
}
