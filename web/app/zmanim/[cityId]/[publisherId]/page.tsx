'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import {
  MapPin, ChevronLeft, ChevronRight,
  Loader2, AlertCircle, ArrowLeft, Info, Search, X, Sun, Moon, Sunset, Clock,
  Flame, Star, Calendar
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

// Zman key patterns for categorization
const ZMAN_CATEGORIES = {
  dawn: ['alos_hashachar', 'alos_', 'misheyakir'],
  morning: ['sunrise', 'netz', 'sof_zman_shma', 'sof_zman_tfila', 'sof_zman_tefilla', 'sof_zman_achilas_chametz', 'sof_zman_biur_chametz'],
  midday: ['chatzos', 'mincha_gedola', 'mincha_ketana', 'plag_hamincha', 'samuch_lmincha'],
  evening: ['sunset', 'shkiah', 'tzeis', 'tzais', 'nightfall'],
  // Special occasion categories
  shabbos_yomtov: ['candle_lighting', 'hadlakas_neiros', 'shabbos_ends', 'havdalah', 'motzei'],
  fast: ['fast_begins', 'fast_ends', 'tzom_', 'taanis_'],
};

// Check if a zman key matches any pattern in a category
const matchesCategory = (key: string, patterns: string[]) => {
  return patterns.some(pattern =>
    key === pattern || key.startsWith(pattern) || key.includes(pattern)
  );
};

// Group zmanim by time of day and occasion
interface GroupedZmanim {
  dawn: Zman[];
  morning: Zman[];
  midday: Zman[];
  evening: Zman[];
  shabbos_yomtov: Zman[];
  fast: Zman[];
}

const groupZmanim = (zmanim: Zman[]): GroupedZmanim => {
  const result: GroupedZmanim = {
    dawn: [],
    morning: [],
    midday: [],
    evening: [],
    shabbos_yomtov: [],
    fast: [],
  };

  for (const zman of zmanim) {
    const key = zman.key.toLowerCase();

    // Check occasion-based categories first (they take priority)
    if (matchesCategory(key, ZMAN_CATEGORIES.shabbos_yomtov)) {
      result.shabbos_yomtov.push(zman);
    } else if (matchesCategory(key, ZMAN_CATEGORIES.fast)) {
      result.fast.push(zman);
    }
    // Then check time-of-day categories
    else if (matchesCategory(key, ZMAN_CATEGORIES.dawn)) {
      result.dawn.push(zman);
    } else if (matchesCategory(key, ZMAN_CATEGORIES.morning)) {
      result.morning.push(zman);
    } else if (matchesCategory(key, ZMAN_CATEGORIES.midday)) {
      result.midday.push(zman);
    } else if (matchesCategory(key, ZMAN_CATEGORIES.evening)) {
      result.evening.push(zman);
    }
    // Uncategorized zmanim go to evening as fallback (most likely nightfall variants)
    else {
      result.evening.push(zman);
    }
  }

  return result;
};

// Get icon for zman group
const getSectionIcon = (section: string) => {
  switch (section) {
    case 'dawn':
      return <Moon className="w-4 h-4" />;
    case 'morning':
      return <Sun className="w-4 h-4" />;
    case 'midday':
      return <Clock className="w-4 h-4" />;
    case 'evening':
      return <Sunset className="w-4 h-4" />;
    case 'shabbos_yomtov':
      return <Flame className="w-4 h-4" />;
    case 'fast':
      return <Calendar className="w-4 h-4" />;
    default:
      return <Star className="w-4 h-4" />;
  }
};

// Get section title
const getSectionTitle = (section: string, hebrew: boolean = false) => {
  if (hebrew) {
    switch (section) {
      case 'dawn':
        return 'שחר';
      case 'morning':
        return 'בוקר';
      case 'midday':
        return 'צהריים';
      case 'evening':
        return 'ערב';
      case 'shabbos_yomtov':
        return 'שבת / יום טוב';
      case 'fast':
        return 'יום צום';
      default:
        return 'מיוחד';
    }
  }
  switch (section) {
    case 'dawn':
      return 'Dawn';
    case 'morning':
      return 'Morning';
    case 'midday':
      return 'Midday';
    case 'evening':
      return 'Evening';
    case 'shabbos_yomtov':
      return 'Shabbos / Yom Tov';
    case 'fast':
      return 'Fast Day';
    default:
      return 'Special';
  }
};

// Define the order sections should appear
const SECTION_ORDER = ['dawn', 'morning', 'midday', 'evening', 'shabbos_yomtov', 'fast'] as const;

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
      <main className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50 dark:from-zinc-950 dark:via-zinc-900 dark:to-blue-950/20 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="w-8 h-8 text-primary animate-spin" />
          <p className="text-sm text-muted-foreground">Loading zmanim...</p>
        </div>
      </main>
    );
  }

  if (error) {
    return (
      <main className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50 dark:from-zinc-950 dark:via-zinc-900 dark:to-blue-950/20">
        <div className="container mx-auto px-4 py-12">
          <div className="max-w-md mx-auto bg-destructive/10 border border-destructive/20 rounded-xl p-8 text-center backdrop-blur-sm">
            <AlertCircle className="w-12 h-12 text-destructive mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-foreground mb-2">Error Loading Zmanim</h2>
            <p className="text-muted-foreground mb-6">{error}</p>
            <Link
              href={`/zmanim/${cityId}`}
              className="inline-flex items-center gap-2 text-primary hover:text-primary/80 font-medium transition-colors"
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
  const groupedZmanim = groupZmanim(zmanim);

  return (
    <main className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50 dark:from-zinc-950 dark:via-zinc-900 dark:to-blue-950/20">
      <div className="container mx-auto px-4 py-6 md:py-8">
        <div className="max-w-3xl mx-auto space-y-4">
          {/* Header Card */}
          <div className="bg-white/80 dark:bg-zinc-900/80 backdrop-blur-xl rounded-2xl shadow-lg border border-slate-200/50 dark:border-zinc-800/50 overflow-hidden transition-all hover:shadow-xl">
            {/* Publisher Info Bar */}
            <div className="bg-gradient-to-r from-primary via-primary to-blue-600 dark:from-primary dark:via-primary dark:to-blue-700 text-primary-foreground px-5 py-4">
              <div className="flex items-center justify-between gap-3">
                {/* Back button + Publisher */}
                <div className="flex items-center gap-3 min-w-0">
                  <Link
                    href={`/zmanim/${cityId}`}
                    className="p-2 hover:bg-white/20 rounded-lg transition-all hover:scale-105 active:scale-95 flex-shrink-0"
                    aria-label="Back to publisher selection"
                  >
                    <ArrowLeft className="w-4 h-4" />
                  </Link>
                  {!isDefault && publisher?.logo_url ? (
                    <div className="relative w-10 h-10 rounded-lg overflow-hidden bg-white/10 backdrop-blur-sm border border-white/20 flex-shrink-0">
                      <Image
                        src={publisher.logo_url}
                        alt={publisher.name}
                        fill
                        className="object-cover"
                        unoptimized
                      />
                    </div>
                  ) : null}
                  <div className="min-w-0">
                    <h1 className="font-bold text-base md:text-lg tracking-tight truncate">
                      {isDefault ? 'Default Zmanim' : publisher?.name || 'Zmanim'}
                    </h1>
                    <button
                      onClick={() => setLocationSearchOpen(true)}
                      className="flex items-center gap-1.5 text-primary-foreground/90 text-xs md:text-sm hover:text-white transition-all group"
                    >
                      <MapPin className="w-3.5 h-3.5 flex-shrink-0" />
                      <span className="group-hover:underline underline-offset-2 truncate">
                        {city?.name}, {city?.region ? `${city.region}, ` : ''}{city?.country}
                      </span>
                      <Search className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0" />
                    </button>
                  </div>
                </div>

                {/* Language toggle */}
                <button
                  onClick={() => setShowHebrew(!showHebrew)}
                  className="px-4 py-2 text-xs md:text-sm font-medium bg-white/20 hover:bg-white/30 rounded-lg transition-all hover:scale-105 active:scale-95 backdrop-blur-sm border border-white/20 flex-shrink-0"
                >
                  {showHebrew ? 'English' : 'עברית'}
                </button>
              </div>
            </div>

            {/* Date Navigation */}
            <div className="px-5 py-4 flex items-center justify-between gap-4 border-b border-slate-200/50 dark:border-zinc-800/50">
              <button
                onClick={handlePrevDay}
                className="p-2.5 hover:bg-slate-100 dark:hover:bg-zinc-800 rounded-xl transition-all hover:scale-110 active:scale-95"
                aria-label="Previous day"
              >
                <ChevronLeft className="w-5 h-5 text-muted-foreground" />
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
                className="p-2.5 hover:bg-slate-100 dark:hover:bg-zinc-800 rounded-xl transition-all hover:scale-110 active:scale-95"
                aria-label="Next day"
              >
                <ChevronRight className="w-5 h-5 text-muted-foreground" />
              </button>
            </div>

            {/* Default Warning */}
            {isDefault && (
              <div className="px-5 py-3 bg-amber-50 dark:bg-amber-950/30 border-b border-amber-200/50 dark:border-amber-800/50">
                <p className="text-amber-800 dark:text-amber-200 text-xs md:text-sm text-center">
                  These are default calculations using standard algorithms. They are not endorsed by a local halachic authority.
                </p>
              </div>
            )}
          </div>

          {/* Zmanim Content */}
          {zmanim.length === 0 ? (
            <div className="bg-white/80 dark:bg-zinc-900/80 backdrop-blur-xl rounded-2xl shadow-lg border border-slate-200/50 dark:border-zinc-800/50 p-12 text-center">
              <Clock className="w-16 h-16 text-muted-foreground/30 mx-auto mb-4" />
              <p className="text-muted-foreground text-lg">No zmanim available for this date.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {/* Render sections in defined order */}
              {SECTION_ORDER.map((section) => {
                const sectionZmanim = groupedZmanim[section];
                if (!sectionZmanim || sectionZmanim.length === 0) return null;

                return (
                  <div
                    key={section}
                    className="bg-white/80 dark:bg-zinc-900/80 backdrop-blur-xl rounded-2xl shadow-lg border border-slate-200/50 dark:border-zinc-800/50 overflow-hidden transition-all hover:shadow-xl"
                  >
                    {/* Section Header */}
                    <div className="px-5 py-3 bg-slate-50 dark:bg-zinc-800/50 border-b border-slate-200/50 dark:border-zinc-800/50" dir={showHebrew ? 'rtl' : 'ltr'}>
                      <div className="flex items-center gap-2">
                        <div className="p-1.5 bg-primary/10 text-primary rounded-lg">
                          {getSectionIcon(section)}
                        </div>
                        <h2 className={`text-sm font-semibold text-foreground tracking-wide uppercase ${showHebrew ? 'font-hebrew' : ''}`}>
                          {getSectionTitle(section, showHebrew)}
                        </h2>
                      </div>
                    </div>

                    {/* Zmanim List */}
                    <div className={`divide-y divide-slate-200/50 dark:divide-zinc-800/50 ${showHebrew ? 'text-right' : ''}`} dir={showHebrew ? 'rtl' : 'ltr'}>
                      {sectionZmanim.map((zman, idx) => {
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
                            className="px-5 py-4 hover:bg-slate-50/80 dark:hover:bg-zinc-800/50 transition-all group"
                            style={{
                              animation: `fadeSlideIn 0.3s ease-out ${idx * 0.05}s both`
                            }}
                          >
                            <div className="flex items-center justify-between gap-4">
                              <div className="flex items-center gap-2 min-w-0">
                                <span className={`text-foreground font-medium text-base md:text-lg ${showHebrew ? 'font-hebrew' : ''} truncate`}>
                                  {displayName}
                                </span>
                                <button
                                  onClick={() => {
                                    setSelectedZman(zmanWithName);
                                    setFormulaPanelOpen(true);
                                  }}
                                  className="p-1.5 text-muted-foreground hover:text-primary hover:bg-primary/10 rounded-lg transition-all opacity-60 group-hover:opacity-100 hover:scale-110 active:scale-95 flex-shrink-0"
                                  aria-label={`Show formula details for ${englishName}`}
                                >
                                  <Info className="w-4 h-4" />
                                </button>
                              </div>
                              <div
                                className="text-xl md:text-2xl font-bold bg-gradient-to-br from-primary via-primary to-blue-600 dark:from-primary dark:via-primary dark:to-blue-400 bg-clip-text text-transparent tabular-nums tracking-tight flex-shrink-0"
                                dir="ltr"
                              >
                                {formatTimeShort(zman.time)}
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Footer Info */}
          <div className="text-center py-2">
            <p className="text-xs text-muted-foreground">
              Timezone: {city?.timezone || 'Unknown'}
            </p>
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
        <div className="fixed inset-0 z-50 flex items-start justify-center pt-20 px-4 animate-in fade-in duration-200">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-md"
            onClick={() => {
              setLocationSearchOpen(false);
              setSearchQuery('');
              setSearchResults([]);
            }}
          />

          {/* Modal */}
          <div className="relative w-full max-w-lg bg-white dark:bg-zinc-900 rounded-2xl shadow-2xl overflow-hidden border border-slate-200/50 dark:border-zinc-800/50 animate-in slide-in-from-top-4 duration-300">
            {/* Search Header */}
            <div className="p-5 border-b border-slate-200 dark:border-zinc-800">
              <div className="flex items-center gap-3">
                <Search className="w-5 h-5 text-muted-foreground flex-shrink-0" />
                <input
                  type="text"
                  placeholder="Search for a city..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 bg-transparent text-foreground placeholder-muted-foreground outline-none text-base"
                  autoFocus
                />
                <button
                  onClick={() => {
                    setLocationSearchOpen(false);
                    setSearchQuery('');
                    setSearchResults([]);
                  }}
                  className="p-2 hover:bg-slate-100 dark:hover:bg-zinc-800 rounded-lg transition-all hover:scale-110 active:scale-95 flex-shrink-0"
                >
                  <X className="w-5 h-5 text-muted-foreground" />
                </button>
              </div>
              {!isDefault && (
                <p className="text-xs text-amber-600 dark:text-amber-400 mt-3 ml-8">
                  Note: This publisher may not cover all locations. If your city is not covered, try Default Zmanim.
                </p>
              )}
            </div>

            {/* Results */}
            <div className="max-h-96 overflow-y-auto">
              {searching && (
                <div className="p-8 text-center">
                  <Loader2 className="w-6 h-6 text-primary animate-spin mx-auto" />
                  <p className="text-sm text-muted-foreground mt-2">Searching...</p>
                </div>
              )}

              {!searching && searchQuery.length >= 2 && searchResults.length === 0 && (
                <div className="p-8 text-center">
                  <Search className="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
                  <p className="text-muted-foreground">No cities found for &quot;{searchQuery}&quot;</p>
                </div>
              )}

              {!searching && searchResults.map((result, idx) => (
                <button
                  key={result.id}
                  onClick={() => handleSelectCity(result.id)}
                  className="w-full px-5 py-4 text-left hover:bg-slate-50 dark:hover:bg-zinc-800/50 transition-all flex items-center gap-3 border-b border-slate-200/50 dark:border-zinc-800/50 last:border-0 group"
                  style={{
                    animation: `fadeSlideIn 0.2s ease-out ${idx * 0.03}s both`
                  }}
                >
                  <div className="p-2 bg-primary/10 text-primary rounded-lg group-hover:scale-110 transition-transform flex-shrink-0">
                    <MapPin className="w-4 h-4" />
                  </div>
                  <div className="min-w-0">
                    <p className="font-semibold text-foreground group-hover:text-primary transition-colors truncate">
                      {result.name}
                    </p>
                    <p className="text-sm text-muted-foreground truncate">
                      {result.region ? `${result.region}, ` : ''}{result.country}
                    </p>
                  </div>
                </button>
              ))}

              {!searching && searchQuery.length < 2 && (
                <div className="p-8 text-center">
                  <Search className="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
                  <p className="text-muted-foreground text-sm">
                    Type at least 2 characters to search
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Global Styles for Animations */}
      <style jsx global>{`
        @keyframes fadeSlideIn {
          from {
            opacity: 0;
            transform: translateY(8px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </main>
  );
}
