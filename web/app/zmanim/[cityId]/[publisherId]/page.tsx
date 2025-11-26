'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import {
  MapPin, User, Building, ChevronLeft, ChevronRight,
  Loader2, AlertCircle, ArrowLeft, Calendar, Info
} from 'lucide-react';
import Link from 'next/link';
import { DateTime } from 'luxon';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface City {
  id: string;
  name: string;
  country: string;
  region: string | null;
  timezone: string;
}

interface Publisher {
  id: string;
  name: string;
  organization: string | null;
  logo_url: string | null;
}

interface ZmanFormula {
  method: string;
  display_name: string;
  parameters: Record<string, unknown>;
  explanation: string;
}

interface Zman {
  name: string;
  key: string;
  time: string;
  formula: ZmanFormula;
}

interface ZmanimData {
  date: string;
  city: City;
  publisher?: Publisher;
  zmanim: Zman[];
  is_default: boolean;
}

// Format zman names for display
const formatZmanName = (key: string): string => {
  const names: Record<string, string> = {
    alos_hashachar: 'Alos HaShachar',
    misheyakir: 'Misheyakir',
    sunrise: 'Sunrise (Netz)',
    sof_zman_shma_gra: 'Sof Zman Shma (GRA)',
    sof_zman_shma_mga: 'Sof Zman Shma (MGA)',
    sof_zman_tefilla_gra: 'Sof Zman Tefilla (GRA)',
    sof_zman_tefilla_mga: 'Sof Zman Tefilla (MGA)',
    chatzos: 'Chatzos',
    mincha_gedola: 'Mincha Gedola',
    mincha_ketana: 'Mincha Ketana',
    plag_hamincha: 'Plag HaMincha',
    sunset: 'Sunset (Shkiah)',
    tzeis_hakochavim: 'Tzeis HaKochavim',
    tzeis_72: 'Tzeis (72 min)',
  };
  return names[key] || key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
};

export default function ZmanimPage() {
  const params = useParams();
  const router = useRouter();
  const searchParams = useSearchParams();

  const cityId = params.cityId as string;
  const publisherId = params.publisherId as string;
  const isDefault = publisherId === 'default';

  // Date state
  const dateParam = searchParams.get('date');
  const [selectedDate, setSelectedDate] = useState<DateTime>(() => {
    if (dateParam) {
      const parsed = DateTime.fromISO(dateParam);
      return parsed.isValid ? parsed : DateTime.now();
    }
    return DateTime.now();
  });

  const [data, setData] = useState<ZmanimData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedZman, setExpandedZman] = useState<string | null>(null);

  useEffect(() => {
    if (cityId) {
      loadZmanim();
    }
  }, [cityId, publisherId, selectedDate]);

  const loadZmanim = async () => {
    try {
      setLoading(true);
      setError(null);

      let url = `${API_BASE}/api/v1/zmanim?cityId=${cityId}&date=${selectedDate.toISODate()}`;
      if (!isDefault) {
        url += `&publisherId=${publisherId}`;
      }

      const response = await fetch(url);
      if (!response.ok) {
        throw new Error('Failed to load zmanim');
      }

      const result = await response.json();
      const zmanimData = result.data || result;

      setData({
        date: zmanimData.date,
        city: zmanimData.location || zmanimData.city,
        publisher: zmanimData.publisher,
        zmanim: zmanimData.zmanim || [],
        is_default: isDefault || !zmanimData.publisher,
      });
    } catch (err) {
      console.error('Failed to load zmanim:', err);
      setError(err instanceof Error ? err.message : 'Failed to load zmanim');
    } finally {
      setLoading(false);
    }
  };

  const handlePrevDay = () => {
    const newDate = selectedDate.minus({ days: 1 });
    setSelectedDate(newDate);
    router.replace(`/zmanim/${cityId}/${publisherId}?date=${newDate.toISODate()}`);
  };

  const handleNextDay = () => {
    const newDate = selectedDate.plus({ days: 1 });
    setSelectedDate(newDate);
    router.replace(`/zmanim/${cityId}/${publisherId}?date=${newDate.toISODate()}`);
  };

  const handleToday = () => {
    const today = DateTime.now();
    setSelectedDate(today);
    router.replace(`/zmanim/${cityId}/${publisherId}`);
  };

  if (loading) {
    return (
      <main className="min-h-screen bg-slate-900 flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-blue-400 animate-spin" />
      </main>
    );
  }

  if (error) {
    return (
      <main className="min-h-screen bg-slate-900">
        <div className="container mx-auto px-4 py-12">
          <div className="bg-red-900/50 border border-red-700 rounded-lg p-6 text-center">
            <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-4" />
            <h2 className="text-xl font-bold text-white mb-2">Error</h2>
            <p className="text-red-200 mb-4">{error}</p>
            <Link
              href={`/zmanim/${cityId}`}
              className="inline-flex items-center gap-2 text-blue-400 hover:text-blue-300"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to publisher selection
            </Link>
          </div>
        </div>
      </main>
    );
  }

  const city = data?.city;
  const publisher = data?.publisher;
  const zmanim = data?.zmanim || [];

  return (
    <main className="min-h-screen bg-slate-900">
      {/* Header */}
      <div className="bg-slate-800 border-b border-slate-700">
        <div className="container mx-auto px-4 py-6">
          <Link
            href={`/zmanim/${cityId}`}
            className="inline-flex items-center gap-2 text-slate-400 hover:text-white mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Change publisher
          </Link>

          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            {/* Location & Publisher */}
            <div>
              <div className="flex items-center gap-2 text-slate-400 text-sm mb-1">
                <MapPin className="w-4 h-4" />
                <span>{city?.name}, {city?.region && `${city.region}, `}{city?.country}</span>
              </div>

              {isDefault ? (
                <div className="flex items-center gap-2">
                  <AlertCircle className="w-5 h-5 text-yellow-400" />
                  <h1 className="text-xl font-bold text-yellow-200">Default Zmanim</h1>
                </div>
              ) : publisher ? (
                <div className="flex items-center gap-3">
                  {publisher.logo_url ? (
                    <img
                      src={publisher.logo_url}
                      alt={publisher.name}
                      className="w-10 h-10 rounded-lg object-cover"
                    />
                  ) : (
                    <div className="w-10 h-10 bg-slate-700 rounded-lg flex items-center justify-center">
                      <User className="w-5 h-5 text-slate-400" />
                    </div>
                  )}
                  <div>
                    <h1 className="text-xl font-bold text-white">{publisher.name}</h1>
                    {publisher.organization && (
                      <div className="flex items-center gap-1 text-slate-400 text-sm">
                        <Building className="w-3 h-3" />
                        <span>{publisher.organization}</span>
                      </div>
                    )}
                  </div>
                </div>
              ) : null}
            </div>

            {/* Date Navigation */}
            <div className="flex items-center gap-2">
              <button
                onClick={handlePrevDay}
                className="p-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition-colors"
                aria-label="Previous day"
              >
                <ChevronLeft className="w-5 h-5 text-white" />
              </button>

              <button
                onClick={handleToday}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition-colors flex items-center gap-2"
              >
                <Calendar className="w-4 h-4 text-slate-400" />
                <span className="text-white font-medium">
                  {selectedDate.toFormat('EEE, MMM d, yyyy')}
                </span>
              </button>

              <button
                onClick={handleNextDay}
                className="p-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition-colors"
                aria-label="Next day"
              >
                <ChevronRight className="w-5 h-5 text-white" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Default Warning */}
      {isDefault && (
        <div className="bg-yellow-900/30 border-b border-yellow-700">
          <div className="container mx-auto px-4 py-3">
            <p className="text-yellow-200 text-sm">
              These are default calculations using standard algorithms.
              They are not endorsed by a local halachic authority.
            </p>
          </div>
        </div>
      )}

      {/* Zmanim List */}
      <div className="container mx-auto px-4 py-6">
        <div className="space-y-2">
          {zmanim.map((zman) => (
            <div
              key={zman.key}
              className="bg-slate-800 border border-slate-700 rounded-lg overflow-hidden"
            >
              <button
                onClick={() => setExpandedZman(expandedZman === zman.key ? null : zman.key)}
                className="w-full flex items-center justify-between p-4 hover:bg-slate-700/50 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <span className="text-white font-medium">
                    {zman.name || formatZmanName(zman.key)}
                  </span>
                  <button
                    className="text-slate-500 hover:text-slate-300"
                    aria-label="Show formula details"
                  >
                    <Info className="w-4 h-4" />
                  </button>
                </div>
                <span className="text-2xl font-bold text-blue-400 tabular-nums">
                  {zman.time}
                </span>
              </button>

              {/* Expanded Formula Details */}
              {expandedZman === zman.key && zman.formula && (
                <div className="px-4 pb-4 border-t border-slate-700 pt-3">
                  <div className="bg-slate-900/50 rounded-lg p-3 text-sm">
                    <div className="text-slate-400 mb-1">
                      <span className="text-slate-500">Method:</span>{' '}
                      {zman.formula.display_name || zman.formula.method}
                    </div>
                    {zman.formula.explanation && (
                      <div className="text-slate-400">
                        <span className="text-slate-500">Details:</span>{' '}
                        {zman.formula.explanation}
                      </div>
                    )}
                    {zman.formula.parameters && Object.keys(zman.formula.parameters).length > 0 && (
                      <div className="text-slate-400 mt-1">
                        <span className="text-slate-500">Parameters:</span>{' '}
                        {Object.entries(zman.formula.parameters)
                          .map(([k, v]) => `${k}: ${v}`)
                          .join(', ')}
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>

        {zmanim.length === 0 && (
          <div className="text-center py-12">
            <p className="text-slate-400">No zmanim available for this date.</p>
          </div>
        )}
      </div>

      {/* Footer */}
      <footer className="mt-auto border-t border-slate-700 bg-slate-800/50">
        <div className="container mx-auto px-4 py-8 text-center">
          <p className="text-sm text-slate-500">
            Zmanim Lab - Multi-Publisher Prayer Times Platform
          </p>
          <p className="text-xs text-slate-600 mt-2">
            Timezone: {city?.timezone || 'Unknown'}
          </p>
        </div>
      </footer>
    </main>
  );
}
