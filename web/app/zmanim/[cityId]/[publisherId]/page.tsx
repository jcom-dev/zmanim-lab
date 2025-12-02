'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import {
  MapPin, ChevronLeft, ChevronRight,
  Loader2, AlertCircle, ArrowLeft, Info, Search, X
} from 'lucide-react';
import Link from 'next/link';
import { DateTime } from 'luxon';
import { FormulaPanel, type Zman } from '@/components/zmanim/FormulaPanel';
import { DatePickerDropdown } from '@/components/zmanim/DatePickerDropdown';
import { API_BASE } from '@/lib/api';
import { formatTimeShort } from '@/lib/utils';

interface City {
  id: string;
  name: string;
  country: string;
  region: string | null;
  timezone: string;
  display_name?: string;
}

interface SearchCity {
  id: string;
  name: string;
  country: string;
  region: string | null;
  display_name: string;
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
    sunrise: 'Sunrise (Netz HaChama)',
    sof_zman_shma_gra: 'Sof Zman Shma (GRA)',
    sof_zman_shma_mga: 'Sof Zman Shma (MGA)',
    sof_zman_tefilla_gra: 'Sof Zman Tefilla (GRA)',
    sof_zman_tefilla_mga: 'Sof Zman Tefilla (MGA)',
    chatzos: 'Chatzos (Midday)',
    mincha_gedola: 'Mincha Gedola',
    mincha_ketana: 'Mincha Ketana',
    plag_hamincha: 'Plag HaMincha',
    sunset: 'Sunset (Shkiah)',
    tzeis_hakochavim: 'Tzeis HaKochavim',
    tzeis_72: 'Tzeis (72 minutes)',
  };
  return names[key] || key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
};

// Spiral binding component for calendar effect
function SpiralBinding() {
  return (
    <div className="relative w-full h-6 bg-gradient-to-b from-zinc-400 to-zinc-500 dark:from-zinc-600 dark:to-zinc-700 flex items-center justify-center overflow-hidden">
      <div className="flex gap-4 sm:gap-6 md:gap-8">
        {Array.from({ length: 15 }).map((_, i) => (
          <div
            key={i}
            className="w-3 h-3 sm:w-4 sm:h-4 rounded-full bg-gradient-to-br from-zinc-300 to-zinc-500 dark:from-zinc-500 dark:to-zinc-700 border border-zinc-600 dark:border-zinc-800 shadow-inner"
          />
        ))}
      </div>
      {/* Shadow under spirals */}
      <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-b from-black/20 to-transparent" />
    </div>
  );
}

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
  const [showHebrew, setShowHebrew] = useState(false);

  // Location search state
  const [locationSearchOpen, setLocationSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<SearchCity[]>([]);
  const [searching, setSearching] = useState(false);

  // Hebrew names for zmanim
  const hebrewNames: Record<string, string> = {
    alos_hashachar: 'עלות השחר',
    misheyakir: 'משיכיר',
    sunrise: 'הנץ החמה',
    sof_zman_shma_gra: 'סוף זמן ק״ש גר״א',
    sof_zman_shma_mga: 'סוף זמן ק״ש מג״א',
    sof_zman_tefilla_gra: 'סוף זמן תפלה גר״א',
    sof_zman_tefilla_mga: 'סוף זמן תפלה מג״א',
    chatzos: 'חצות היום',
    mincha_gedola: 'מנחה גדולה',
    mincha_ketana: 'מנחה קטנה',
    plag_hamincha: 'פלג המנחה',
    sunset: 'שקיעה',
    tzeis_hakochavim: 'צאת הכוכבים',
    tzeis_72: 'צאת (72 דקות)',
  };

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

  // Search for cities
  const searchCities = async (query: string) => {
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }

    setSearching(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/cities?search=${encodeURIComponent(query)}&limit=10`);
      if (response.ok) {
        const result = await response.json();
        const cities = result.data?.cities || result.cities || [];
        setSearchResults(cities);
      }
    } catch (err) {
      console.error('Failed to search cities:', err);
    } finally {
      setSearching(false);
    }
  };

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery) {
        searchCities(searchQuery);
      } else {
        setSearchResults([]);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  const handleSelectCity = (newCityId: string) => {
    setLocationSearchOpen(false);
    setSearchQuery('');
    setSearchResults([]);
    router.push(`/zmanim/${newCityId}/${publisherId}${selectedDate ? `?date=${selectedDate.toISODate()}` : ''}`);
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
    <main className="min-h-screen bg-stone-100 dark:bg-zinc-900">
      {/* Calendar Card */}
      <div className="container mx-auto px-2 sm:px-4 py-4">
        <div className="max-w-2xl mx-auto">
          {/* Spiral binding */}
          <SpiralBinding />

          {/* Calendar page */}
          <div className="bg-amber-50 dark:bg-zinc-800 shadow-xl border-x border-b border-stone-300 dark:border-zinc-700">
            {/* Publisher Header Bar */}
            <div className="bg-indigo-900 dark:bg-indigo-950 text-white px-4 py-3">
              <div className="flex items-center justify-between gap-2">
                {/* Back button + Publisher info */}
                <div className="flex items-center gap-3">
                  <Link
                    href={`/zmanim/${cityId}`}
                    className="p-1.5 hover:bg-indigo-800 rounded-full transition-colors"
                    aria-label="Back to publisher selection"
                  >
                    <ArrowLeft className="w-4 h-4" />
                  </Link>
                  {!isDefault && publisher?.logo_url ? (
                    <div className="relative w-8 h-8">
                      <Image
                        src={publisher.logo_url}
                        alt={publisher.name}
                        fill
                        className="rounded object-cover"
                        unoptimized
                      />
                    </div>
                  ) : null}
                  <div>
                    <h1 className="font-bold text-sm sm:text-base tracking-wide">
                      {isDefault ? 'Default Zmanim' : publisher?.name || 'Zmanim'}
                    </h1>
                    <button
                      onClick={() => setLocationSearchOpen(true)}
                      className="flex items-center gap-1 text-indigo-200 text-xs hover:text-white transition-colors group"
                    >
                      <MapPin className="w-3 h-3" />
                      <span className="group-hover:underline">{city?.name}, {city?.region ? `${city.region}, ` : ''}{city?.country}</span>
                      <Search className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                    </button>
                    {!isDefault && (
                      <p className="text-indigo-300/70 text-[10px] mt-0.5">
                        Coverage may be limited to specific areas
                      </p>
                    )}
                  </div>
                </div>

                {/* Language toggle */}
                <button
                  onClick={() => setShowHebrew(!showHebrew)}
                  className="px-3 py-1.5 text-xs font-medium bg-indigo-800 hover:bg-indigo-700 rounded transition-colors"
                >
                  {showHebrew ? 'English' : 'עברית'}
                </button>
              </div>
            </div>

            {/* Date header with navigation */}
            <div className="border-b border-stone-300 dark:border-zinc-600 px-4 py-3 flex items-center justify-between bg-stone-50 dark:bg-zinc-750">
              <button
                onClick={handlePrevDay}
                className="p-2 hover:bg-stone-200 dark:hover:bg-zinc-700 rounded-full transition-colors"
                aria-label="Previous day"
              >
                <ChevronLeft className="w-5 h-5 text-stone-600 dark:text-zinc-400" />
              </button>

              <DatePickerDropdown
                selectedDate={selectedDate}
                onDateChange={(newDate) => {
                  setSelectedDate(newDate);
                  router.replace(`/zmanim/${cityId}/${publisherId}?date=${newDate.toISODate()}`);
                }}
                showHebrew={showHebrew}
              />

              <button
                onClick={handleNextDay}
                className="p-2 hover:bg-stone-200 dark:hover:bg-zinc-700 rounded-full transition-colors"
                aria-label="Next day"
              >
                <ChevronRight className="w-5 h-5 text-stone-600 dark:text-zinc-400" />
              </button>
            </div>

            {/* Default Warning */}
            {isDefault && (
              <div className="bg-amber-100 dark:bg-amber-900/30 border-b border-amber-200 dark:border-amber-800 px-4 py-2">
                <p className="text-amber-800 dark:text-amber-200 text-xs text-center">
                  These are default calculations using standard algorithms. They are not endorsed by a local halachic authority.
                </p>
              </div>
            )}

            {/* Zmanim List */}
            <div className={`divide-y divide-stone-200 dark:divide-zinc-700 ${showHebrew ? 'text-right' : ''}`} dir={showHebrew ? 'rtl' : 'ltr'}>
              {zmanim.map((zman) => {
                const englishName = zman.name || formatZmanName(zman.key);
                const displayName = showHebrew
                  ? (hebrewNames[zman.key] || englishName)
                  : englishName;
                const zmanWithName = {
                  ...zman,
                  name: englishName,
                };
                return (
                  <div
                    key={zman.key}
                    className="flex items-center justify-between px-4 py-3 hover:bg-stone-100 dark:hover:bg-zinc-750 transition-colors"
                  >
                    <div className="flex items-center gap-2">
                      <span className={`text-stone-700 dark:text-zinc-200 font-medium text-sm sm:text-base ${showHebrew ? 'font-hebrew' : ''}`}>
                        {displayName}
                      </span>
                      <button
                        onClick={() => {
                          setSelectedZman(zmanWithName);
                          setFormulaPanelOpen(true);
                        }}
                        className="p-1 text-stone-400 hover:text-indigo-600 dark:hover:text-indigo-400 rounded transition-colors"
                        aria-label={`Show formula details for ${englishName}`}
                      >
                        <Info className="w-3.5 h-3.5" />
                      </button>
                    </div>
                    <span className="text-xl sm:text-2xl font-bold text-indigo-700 dark:text-indigo-400 tabular-nums font-mono" dir="ltr">
                      {formatTimeShort(zman.time)}
                    </span>
                  </div>
                );
              })}
            </div>

            {zmanim.length === 0 && (
              <div className="text-center py-12">
                <p className="text-stone-500 dark:text-zinc-500">No zmanim available for this date.</p>
              </div>
            )}

            {/* Footer */}
            <div className="border-t border-stone-300 dark:border-zinc-600 px-4 py-3 bg-stone-50 dark:bg-zinc-800">
              <p className="text-xs text-stone-500 dark:text-zinc-500 text-center">
                Timezone: {city?.timezone || 'Unknown'}
              </p>
            </div>
          </div>
        </div>
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

      {/* Location Search Modal */}
      {locationSearchOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center pt-20 px-4">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => {
              setLocationSearchOpen(false);
              setSearchQuery('');
              setSearchResults([]);
            }}
          />

          {/* Modal */}
          <div className="relative w-full max-w-md bg-white dark:bg-zinc-800 rounded-xl shadow-2xl overflow-hidden">
            {/* Search Header */}
            <div className="p-4 border-b border-stone-200 dark:border-zinc-700">
              <div className="flex items-center gap-3">
                <Search className="w-5 h-5 text-stone-400" />
                <input
                  type="text"
                  placeholder="Search for a city..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 bg-transparent text-stone-800 dark:text-zinc-100 placeholder-stone-400 outline-none text-lg"
                  autoFocus
                />
                <button
                  onClick={() => {
                    setLocationSearchOpen(false);
                    setSearchQuery('');
                    setSearchResults([]);
                  }}
                  className="p-1 hover:bg-stone-100 dark:hover:bg-zinc-700 rounded-full transition-colors"
                >
                  <X className="w-5 h-5 text-stone-500" />
                </button>
              </div>
              {!isDefault && (
                <p className="text-xs text-amber-600 dark:text-amber-400 mt-2">
                  Note: This publisher may not cover all locations. If your city isn&apos;t covered, try Default Zmanim.
                </p>
              )}
            </div>

            {/* Results */}
            <div className="max-h-80 overflow-y-auto">
              {searching && (
                <div className="p-4 text-center">
                  <Loader2 className="w-6 h-6 text-indigo-500 animate-spin mx-auto" />
                </div>
              )}

              {!searching && searchQuery.length >= 2 && searchResults.length === 0 && (
                <div className="p-4 text-center text-stone-500 dark:text-zinc-400">
                  No cities found for &quot;{searchQuery}&quot;
                </div>
              )}

              {!searching && searchResults.map((result) => (
                <button
                  key={result.id}
                  onClick={() => handleSelectCity(result.id)}
                  className="w-full px-4 py-3 text-left hover:bg-stone-100 dark:hover:bg-zinc-700 transition-colors flex items-center gap-3 border-b border-stone-100 dark:border-zinc-700 last:border-0"
                >
                  <MapPin className="w-4 h-4 text-stone-400 flex-shrink-0" />
                  <div>
                    <p className="font-medium text-stone-800 dark:text-zinc-100">
                      {result.name}
                    </p>
                    <p className="text-sm text-stone-500 dark:text-zinc-400">
                      {result.region ? `${result.region}, ` : ''}{result.country}
                    </p>
                  </div>
                </button>
              ))}

              {!searching && searchQuery.length < 2 && (
                <div className="p-4 text-center text-stone-500 dark:text-zinc-400 text-sm">
                  Type at least 2 characters to search
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
