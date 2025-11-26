'use client';

import { usePublisherContext } from '@/providers/PublisherContext';

export function PublisherSwitcher() {
  const { publishers, selectedPublisherId, setSelectedPublisherId, selectedPublisher, isLoading } = usePublisherContext();

  if (isLoading) {
    return (
      <div className="flex items-center gap-2 text-sm text-gray-400">
        <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
        </svg>
        <span>Loading...</span>
      </div>
    );
  }

  // Don't show switcher for single publisher or no publishers
  if (publishers.length <= 1) {
    if (selectedPublisher) {
      return (
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
            <span className="text-blue-600 font-semibold text-sm">
              {selectedPublisher.name.charAt(0).toUpperCase()}
            </span>
          </div>
          <div className="flex flex-col">
            <span className="font-medium text-sm">{selectedPublisher.name}</span>
            <span className="text-xs text-gray-500">{selectedPublisher.organization}</span>
          </div>
        </div>
      );
    }
    return null;
  }

  return (
    <div className="flex items-center gap-2">
      <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
        <span className="text-blue-600 font-semibold text-sm">
          {selectedPublisher?.name.charAt(0).toUpperCase() || '?'}
        </span>
      </div>
      <select
        value={selectedPublisherId || ''}
        onChange={(e) => setSelectedPublisherId(e.target.value)}
        className="bg-transparent border border-gray-200 rounded-md px-3 py-1.5 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent min-w-[200px]"
      >
        {publishers.map((publisher) => (
          <option key={publisher.id} value={publisher.id}>
            {publisher.name} - {publisher.organization}
          </option>
        ))}
      </select>
    </div>
  );
}
