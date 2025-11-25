'use client';

import { useState, useEffect } from 'react';
import { DateTime } from 'luxon';
import LocationInput from '@/components/LocationInput';
import DatePicker from '@/components/DatePicker';
import PublisherCard from '@/components/PublisherCard';
import { api, Publisher, ZmanimResponse } from '@/lib/api';

export default function Home() {
  const [publishers, setPublishers] = useState<Publisher[]>([]);
  const [selectedPublisher, setSelectedPublisher] = useState<Publisher | null>(null);
  const [loading, setLoading] = useState(true);
  const [zmanimLoading, setZmanimLoading] = useState(false);
  const [zmanim, setZmanim] = useState<ZmanimResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Location state
  const [latitude, setLatitude] = useState(31.7683); // Jerusalem
  const [longitude, setLongitude] = useState(35.2137);
  const [timezone, setTimezone] = useState('Asia/Jerusalem');
  const [selectedDate, setSelectedDate] = useState<DateTime>(DateTime.now());

  useEffect(() => {
    loadPublishers();
  }, []);

  const loadPublishers = async () => {
    try {
      setLoading(true);
      const response = await api.getPublishers({ page: 1, page_size: 20 });
      setPublishers(response.publishers);
      if (response.publishers.length > 0) {
        setSelectedPublisher(response.publishers[0]);
      }
    } catch (err) {
      console.error('Failed to load publishers:', err);
      setError('Failed to load publishers. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleLocationChange = (lat: number, lon: number, tz: string) => {
    setLatitude(lat);
    setLongitude(lon);
    setTimezone(tz);
  };

  const calculateZmanim = async () => {
    if (!selectedPublisher) return;

    try {
      setZmanimLoading(true);
      setError(null);
      const response = await api.calculateZmanim({
        date: selectedDate.toISODate() || DateTime.now().toISODate()!,
        latitude,
        longitude,
        timezone,
        publisher_id: selectedPublisher.id,
      });
      setZmanim(response);
    } catch (err) {
      console.error('Failed to calculate zmanim:', err);
      setError('Failed to calculate zmanim. Please try again.');
    } finally {
      setZmanimLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 shadow-sm">
        <div className="container mx-auto px-4 py-16">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-block mb-4">
              <span className="text-6xl">🕍</span>
            </div>
            <h1 className="text-5xl font-bold text-gray-900 mb-4 tracking-tight">
              Zmanim Lab
            </h1>
            <p className="text-xl text-gray-600 mb-6">
              Multi-Publisher Zmanim Platform
            </p>
            <p className="text-gray-500 max-w-2xl mx-auto">
              Choose your preferred halachic authority and calculation method for accurate prayer times worldwide.
            </p>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-12">
        {/* Publishers Section */}
        <section className="mb-12">
          <div className="mb-6">
            <h2 className="text-3xl font-bold text-gray-900 mb-2">
              Select Your Publisher
            </h2>
            <p className="text-gray-600">
              Choose from verified halachic authorities and calculation methods
            </p>
          </div>

          {loading ? (
            <div className="flex justify-center py-20">
              <div className="text-center">
                <svg className="animate-spin h-12 w-12 mx-auto text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
                <p className="text-gray-600 font-medium">Loading publishers...</p>
              </div>
            </div>
          ) : publishers.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {publishers.map((publisher) => (
                <PublisherCard
                  key={publisher.id}
                  publisher={publisher}
                  onSelect={setSelectedPublisher}
                  isSelected={selectedPublisher?.id === publisher.id}
                />
              ))}
            </div>
          ) : (
            <div className="bg-yellow-50 border border-yellow-200 rounded-2xl p-8 text-center">
              <p className="text-yellow-800">
                No publishers available. Please check your backend connection.
              </p>
            </div>
          )}
        </section>

        {/* Calculation Section */}
        {selectedPublisher && (
          <section className="bg-white rounded-3xl shadow-lg border border-gray-200 p-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">
              Calculate Zmanim
            </h2>

            {/* Input Controls */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
              <LocationInput onLocationChange={handleLocationChange} />
              <DatePicker onDateChange={setSelectedDate} />
            </div>

            {/* Calculate Button */}
            <div className="text-center mb-8">
              <button
                onClick={calculateZmanim}
                disabled={zmanimLoading}
                className="bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold text-lg px-12 py-4 rounded-full hover:from-blue-700 hover:to-purple-700 transition-all duration-200 shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {zmanimLoading ? (
                  <span className="flex items-center">
                    <svg className="animate-spin h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                    Calculating...
                  </span>
                ) : (
                  'Calculate Zmanim'
                )}
              </button>
            </div>

            {/* Error Display */}
            {error && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-4 mb-6">
                <p className="text-red-800 text-center">{error}</p>
              </div>
            )}

            {/* Results Display */}
            {zmanim && (
              <div className="space-y-6">
                <div className="bg-gradient-to-r from-blue-100 to-purple-100 rounded-2xl p-6 border border-blue-200">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                      <p className="text-sm text-gray-600 mb-1">Publisher</p>
                      <p className="text-lg font-bold text-gray-900">{zmanim.publisher?.name}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 mb-1">Algorithm</p>
                      <p className="text-lg font-bold text-gray-900">{zmanim.algorithm?.name}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 mb-1">Location</p>
                      <p className="text-lg font-bold text-gray-900">{zmanim.location.name}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 mb-1">Date</p>
                      <p className="text-lg font-bold text-gray-900">{zmanim.date}</p>
                    </div>
                  </div>
                  {zmanim.cached_at && (
                    <p className="text-xs text-gray-500 text-center">
                      Cached result from {new Date(zmanim.cached_at).toLocaleString()}
                    </p>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {Object.entries(zmanim.zmanim).map(([name, time]) => (
                    <div
                      key={name}
                      className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-4 border border-gray-200 hover:shadow-md transition-shadow"
                    >
                      <p className="text-sm text-gray-600 mb-1 capitalize">
                        {name.replace(/_/g, ' ')}
                      </p>
                      <p className="text-2xl font-bold text-gray-900">{time}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </section>
        )}
      </div>

      {/* Footer */}
      <footer className="mt-20 border-t border-gray-200 bg-white">
        <div className="container mx-auto px-4 py-12 text-center">
          <p className="text-sm text-gray-600 mb-2">
            Zmanim Lab - Multi-Publisher Prayer Times Platform
          </p>
          <p className="text-xs text-gray-500">
            Times are calculated based on astronomical and halachic methods.
            <br />
            Consult your local rabbi for practical halachic guidance.
          </p>
        </div>
      </footer>
    </main>
  );
}
