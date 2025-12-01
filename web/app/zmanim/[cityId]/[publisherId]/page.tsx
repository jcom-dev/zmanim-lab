'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import {
  MapPin, User, Building, ChevronLeft, ChevronRight,
  Loader2, AlertCircle, ArrowLeft, Calendar, Info
} from 'lucide-react';
import Link from 'next/link';
import { DateTime } from 'luxon';
import { FormulaPanel, type Zman } from '@/components/zmanim/FormulaPanel';
import { API_BASE } from '@/lib/api';

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
  const [selectedZman, setSelectedZman] = useState<Zman | null>(null);
  const [formulaPanelOpen, setFormulaPanelOpen] = useState(false);

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

      // Map location response to City interface
      const location = zmanimData.location;
      const city: City = location ? {
        id: location.city_id || cityId,
        name: location.city_name || 'Unknown',
        country: location.country || '',
        region: location.region || null,
        timezone: location.timezone || 'UTC'
      } : zmanimData.city;

      setData({
        date: zmanimData.date,
        city: city,
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
      <main className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-blue-400 animate-spin" />
      </main>
    );
  }

  if (error) {
    return (
      <main className="min-h-screen bg-background">
        <div className="container mx-auto px-4 py-12">
          <div className="bg-red-900/50 border border-red-700 rounded-lg p-6 text-center">
            <AlertCircle className="w-12 h-12 text-destructive mx-auto mb-4" />
            <h2 className="text-xl font-bold text-foreground mb-2">Error</h2>
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
    <main className="min-h-screen bg-background">
      {/* Header */}
      <div className="bg-card border-b border-border">
        <div className="container mx-auto px-4 py-6">
          <Link
            href={`/zmanim/${cityId}`}
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Change publisher
          </Link>

          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            {/* Location & Publisher */}
            <div>
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <MapPin className="w-4 h-4" />
                <span>{city?.name}, {city?.region && `${city.region}, `}{city?.country}</span>
              </div>

              {isDefault ? (
                <div className="flex items-center gap-2">
                  <AlertCircle className="w-5 h-5 text-yellow-600 dark:text-yellow-400" />
                  <h1 className="text-xl font-bold text-yellow-600 dark:text-yellow-200">Default Zmanim</h1>
                </div>
              ) : publisher ? (
                <div className="flex items-center gap-3">
                  {publisher.logo_url ? (
                    <div className="relative w-10 h-10">
                      <Image
                        src={publisher.logo_url}
                        alt={publisher.name}
                        fill
                        className="rounded-lg object-cover"
                        unoptimized
                      />
                    </div>
                  ) : (
                    <div className="w-10 h-10 bg-muted rounded-lg flex items-center justify-center">
                      <User className="w-5 h-5 text-muted-foreground" />
                    </div>
                  )}
                  <div>
                    <h1 className="text-xl font-bold text-foreground">{publisher.name}</h1>
                    {publisher.organization && (
                      <div className="flex items-center gap-1 text-muted-foreground text-sm">
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
                className="p-2 bg-muted hover:bg-secondary rounded-lg transition-colors"
                aria-label="Previous day"
              >
                <ChevronLeft className="w-5 h-5 text-foreground" />
              </button>

              <button
                onClick={handleToday}
                className="px-4 py-2 bg-muted hover:bg-secondary rounded-lg transition-colors flex items-center gap-2"
              >
                <Calendar className="w-4 h-4 text-muted-foreground" />
                <span className="text-foreground font-medium">
                  {selectedDate.toFormat('EEE, MMM d, yyyy')}
                </span>
              </button>

              <button
                onClick={handleNextDay}
                className="p-2 bg-muted hover:bg-secondary rounded-lg transition-colors"
                aria-label="Next day"
              >
                <ChevronRight className="w-5 h-5 text-foreground" />
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
          {zmanim.map((zman) => {
            const zmanWithName = {
              ...zman,
              name: zman.name || formatZmanName(zman.key),
            };
            return (
              <div
                key={zman.key}
                className="bg-card border border-border rounded-lg overflow-hidden"
              >
                <div className="flex items-center justify-between p-4">
                  <div className="flex items-center gap-3">
                    <span className="text-foreground font-medium">
                      {zmanWithName.name}
                    </span>
                    <button
                      onClick={() => {
                        setSelectedZman(zmanWithName);
                        setFormulaPanelOpen(true);
                      }}
                      className="p-1 text-muted-foreground hover:text-blue-400 hover:bg-muted rounded transition-colors"
                      aria-label={`Show formula details for ${zmanWithName.name}`}
                    >
                      <Info className="w-4 h-4" />
                    </button>
                  </div>
                  <span className="text-2xl font-bold text-blue-400 tabular-nums">
                    {zman.time}
                  </span>
                </div>
              </div>
            );
          })}
        </div>

        {zmanim.length === 0 && (
          <div className="text-center py-12">
            <p className="text-muted-foreground">No zmanim available for this date.</p>
          </div>
        )}
      </div>

      {/* Formula Panel */}
      <FormulaPanel
        zman={selectedZman}
        open={formulaPanelOpen}
        onClose={() => {
          setFormulaPanelOpen(false);
          setSelectedZman(null);
        }}
      />

      {/* Footer */}
      <footer className="mt-auto border-t border-border bg-card/50">
        <div className="container mx-auto px-4 py-8 text-center">
          <p className="text-sm text-muted-foreground">
            Zmanim Lab - Multi-Publisher Prayer Times Platform
          </p>
          <p className="text-xs text-muted-foreground mt-2">
            Timezone: {city?.timezone || 'Unknown'}
          </p>
        </div>
      </footer>
    </main>
  );
}
