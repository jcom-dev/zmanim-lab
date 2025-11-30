'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@clerk/nextjs';
import { useQuery } from '@tanstack/react-query';
import { usePublisherContext } from '@/providers/PublisherContext';
import { useApi } from '@/lib/api-client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { ZmanGrid } from '@/components/publisher/ZmanCard';
import { AlgorithmPreview } from '@/components/publisher/AlgorithmPreview';
import { WeekPreview } from '@/components/publisher/WeekPreview';
import { OnboardingWizard } from '@/components/onboarding/OnboardingWizard';
import {
  useZmanimList,
  useImportZmanim,
  useDeletedZmanim,
  useRestoreZman,
  usePermanentDeleteZman,
  PublisherZman,
  DeletedZman,
} from '@/lib/hooks/useZmanimList';
import { MasterZmanPicker } from '@/components/publisher/MasterZmanPicker';

interface OnboardingState {
  completed_at?: string | null;
  skipped?: boolean;
}
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { MapPin, Search, Plus, Download, Filter, AlertTriangle, ChevronLeft, ChevronRight, Calendar, RotateCcw, Trash2, Loader2, CalendarDays, Flame } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

// Event zman keys - these are shown in Events tab and Weekly Preview
// Everyday zmanim are shown in Everyday tab and Live Preview
const EVENT_ZMAN_KEYS = new Set([
  // Candle lighting
  'candle_lighting',
  'candle_lighting_18',
  'candle_lighting_20',
  'candle_lighting_22',
  'candle_lighting_40',
  // Havdalah / Shabbos ends
  'shabbos_ends',
  'havdalah',
  'havdalah_42',
  'havdalah_50',
  'havdalah_72',
  // Yom Kippur
  'yom_kippur_starts',
  'yom_kippur_ends',
  // Fast days
  'fast_begins',
  'fast_ends',
  'fast_ends_42',
  'fast_ends_50',
  // Tisha B'Av
  'tisha_bav_starts',
  'tisha_bav_ends',
  // Pesach
  'sof_zman_achilas_chametz_gra',
  'sof_zman_achilas_chametz_mga',
  'sof_zman_biur_chametz_gra',
  'sof_zman_biur_chametz_mga',
]);

/**
 * Determines if a zman is an event zman (Shabbos, holidays, fasts)
 * vs an everyday zman (daily solar calculations)
 */
function isEventZman(zmanKey: string): boolean {
  return EVENT_ZMAN_KEYS.has(zmanKey);
}

// Hebrew month names mapping
const hebrewMonthNames: Record<string, string> = {
  'Nisan': 'ניסן',
  'Iyyar': 'אייר',
  'Sivan': 'סיון',
  'Tamuz': 'תמוז',
  'Av': 'אב',
  'Elul': 'אלול',
  'Tishrei': 'תשרי',
  'Cheshvan': 'חשון',
  'Kislev': 'כסלו',
  'Tevet': 'טבת',
  'Shvat': 'שבט',
  'Adar': 'אדר',
  'Adar I': 'אדר א׳',
  'Adar II': 'אדר ב׳',
};

// Convert day number to Hebrew numerals (gematria)
function toHebrewNumerals(num: number): string {
  if (num === undefined || num === null) return '';
  const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
  const tens = ['', 'י', 'כ', 'ל'];
  if (num === 15) return 'ט״ו';
  if (num === 16) return 'ט״ז';
  if (num === 30) return 'ל׳';
  if (num < 10) return ones[num] + '׳';
  if (num < 30) {
    const t = Math.floor(num / 10);
    const o = num % 10;
    if (o === 0) return tens[t] + '׳';
    return tens[t] + '״' + ones[o];
  }
  return num.toString();
}

// Convert year to Hebrew numerals
function toHebrewYear(year: number): string {
  if (year === undefined || year === null) return '';
  const hundreds = ['', 'ק', 'ר', 'ש', 'ת', 'תק', 'תר', 'תש'];
  const tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
  const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
  const lastThree = year % 1000;
  const h = Math.floor(lastThree / 100);
  const t = Math.floor((lastThree % 100) / 10);
  const o = lastThree % 10;
  let result = hundreds[h] || '';
  if (t === 1 && o === 5) {
    result += 'ט״ו';
  } else if (t === 1 && o === 6) {
    result += 'ט״ז';
  } else {
    result += tens[t] || '';
    if (o > 0) {
      result += '״' + ones[o];
    } else if (result.length > 0) {
      result += '׳';
    }
  }
  return result;
}

interface HebrewDateInfo {
  day: number;
  month: string;
  month_num: number;
  year: number;
}

// English month names
const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

// Hebrew months in order (for dropdown) with month numbers matching hdate library
// Month numbers: 1=Nisan, 2=Iyyar, ..., 7=Tishrei, 8=Cheshvan, 9=Kislev, etc.
const hebrewMonthsWithNum = [
  { num: 7, eng: 'Tishrei', heb: 'תשרי' },
  { num: 8, eng: 'Cheshvan', heb: 'חשון' },
  { num: 9, eng: 'Kislev', heb: 'כסלו' },
  { num: 10, eng: 'Tevet', heb: 'טבת' },
  { num: 11, eng: 'Shvat', heb: 'שבט' },
  { num: 12, eng: 'Adar', heb: 'אדר' },
  { num: 1, eng: 'Nisan', heb: 'ניסן' },
  { num: 2, eng: 'Iyyar', heb: 'אייר' },
  { num: 3, eng: 'Sivan', heb: 'סיון' },
  { num: 4, eng: 'Tamuz', heb: 'תמוז' },
  { num: 5, eng: 'Av', heb: 'אב' },
  { num: 6, eng: 'Elul', heb: 'אלול' },
];

// Generate years for dropdown
const currentYear = new Date().getFullYear();
const englishYears = Array.from({ length: 10 }, (_, i) => currentYear - 3 + i);

// Hebrew years (5780-5790 range approximately)
const currentHebrewYear = currentYear + 3760; // Approximate conversion
const hebrewYears = Array.from({ length: 10 }, (_, i) => currentHebrewYear - 3 + i);

// Get days in a month
function getDaysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

// Hebrew days (1-30)
const hebrewDays = Array.from({ length: 30 }, (_, i) => i + 1);

// Default location: Brooklyn, NY
const DEFAULT_LOCATION = {
  latitude: 40.6782,
  longitude: -73.9442,
  timezone: 'America/New_York',
  displayName: 'Brooklyn, NY',
};

// localStorage key prefix for preview location (per-publisher)
const PREVIEW_LOCATION_KEY_PREFIX = 'zmanim-preview-location-';

interface PreviewLocation {
  latitude: number;
  longitude: number;
  timezone: string;
  displayName: string;
}

interface CoverageCity {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  timezone: string;
  country: string;
  region?: string;
}

interface PublisherCoverage {
  id: string;
  coverage_level: 'country' | 'region' | 'city';
  country_code?: string;
  region?: string;
  city_id?: string;
  display_name?: string;
  city_name?: string;
  country?: string;
}

type FilterType = 'all' | 'published' | 'draft' | 'essential' | 'optional' | 'deleted';

export default function AlgorithmEditorPage() {
  const router = useRouter();
  const { getToken } = useAuth();
  const { selectedPublisher } = usePublisherContext();
  const api = useApi();

  // Fetch zmanim using React Query
  const { data: zmanimData, isLoading, error: zmanimError, refetch } = useZmanimList();
  // Memoize to prevent unnecessary re-renders of child components
  const zmanim = useMemo(() => Array.isArray(zmanimData) ? zmanimData : [], [zmanimData]);
  const importZmanim = useImportZmanim();

  // Deleted zmanim for restore
  const { data: deletedZmanim = [], isLoading: deletedLoading } = useDeletedZmanim();
  const restoreZman = useRestoreZman();
  const permanentDeleteZman = usePermanentDeleteZman();

  // Check onboarding status
  const { data: onboardingState, isLoading: onboardingLoading, refetch: refetchOnboarding } = useQuery({
    queryKey: ['onboarding-state', selectedPublisher?.id],
    queryFn: () => api.get<OnboardingState | null>('/publisher/onboarding'),
    enabled: !!selectedPublisher?.id,
    staleTime: 0, // Always refetch
  });
  const hasCompletedOnboarding = onboardingState?.completed_at != null || onboardingState?.skipped === true;

  // Debug logging
  console.log('[Algorithm Page] State:', {
    zmanimLength: zmanim.length,
    onboardingState,
    hasCompletedOnboarding,
    isLoading,
    onboardingLoading,
    selectedPublisher: selectedPublisher?.id,
  });

  const [showMonthView, setShowMonthView] = useState(false);
  const [showImportDialog, setShowImportDialog] = useState(false);
  const [showZmanPicker, setShowZmanPicker] = useState(false);
  const [showRestartConfirm, setShowRestartConfirm] = useState(false);
  const [forceShowWizard, setForceShowWizard] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<FilterType>('all');
  const [viewMode, setViewMode] = useState<'everyday' | 'events'>('everyday');

  // Location state - initialized with default, will be updated when publisher loads
  const [previewLocation, setPreviewLocation] = useState<PreviewLocation>(DEFAULT_LOCATION);
  const [coverageCities, setCoverageCities] = useState<CoverageCity[]>([]);
  const [coverageCountryCodes, setCoverageCountryCodes] = useState<string[]>([]);
  const [citySearch, setCitySearch] = useState('');
  const [searchResults, setSearchResults] = useState<CoverageCity[]>([]);
  const [showCityDropdown, setShowCityDropdown] = useState(false);

  // Preview date state (shared with AlgorithmPreview and edit page)
  const [previewDate, setPreviewDate] = useState(() => new Date());
  const [hebrewDate, setHebrewDate] = useState<HebrewDateInfo | null>(null);

  // Format date as YYYY-MM-DD
  const dateStr = useMemo(() => previewDate.toISOString().split('T')[0], [previewDate]);

  // Save date to localStorage for sharing with edit page
  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('zmanim-preview-date', dateStr);
    }
  }, [dateStr]);

  // Fetch Hebrew date when date changes - using public API (no auth required)
  useEffect(() => {
    const fetchHebrewDate = async () => {
      try {
        // Use api.public for unauthenticated calendar endpoint
        const data = await api.public.get<HebrewDateInfo>(`/calendar/hebrew-date?date=${dateStr}`);
        setHebrewDate(data);
      } catch (err) {
        console.error('Failed to fetch Hebrew date:', err);
      }
    };
    fetchHebrewDate();
  }, [api, dateStr]);

  // Date navigation
  const goToPreviousDay = () => {
    const newDate = new Date(previewDate);
    newDate.setDate(newDate.getDate() - 1);
    setPreviewDate(newDate);
  };

  const goToNextDay = () => {
    const newDate = new Date(previewDate);
    newDate.setDate(newDate.getDate() + 1);
    setPreviewDate(newDate);
  };

  const goToToday = () => {
    setPreviewDate(new Date());
  };

  const isToday = useMemo(() => {
    const today = new Date();
    return previewDate.toDateString() === today.toDateString();
  }, [previewDate]);

  // Convert Hebrew date to Gregorian and update previewDate
  const handleHebrewDateChange = useCallback(async (year: number, monthNum: number, day: number) => {
    try {
      const data = await api.public.get<{ date: string }>(`/calendar/gregorian-date?year=${year}&month=${monthNum}&day=${day}`);
      if (data.date) {
        setPreviewDate(new Date(data.date + 'T12:00:00')); // Add time to avoid timezone issues
      }
    } catch (err) {
      console.error('Failed to convert Hebrew date:', err);
    }
  }, [api]);

  // Save location to localStorage when it changes (per-publisher)
  useEffect(() => {
    if (typeof window !== 'undefined' && selectedPublisher?.id) {
      localStorage.setItem(PREVIEW_LOCATION_KEY_PREFIX + selectedPublisher.id, JSON.stringify(previewLocation));
    }
  }, [previewLocation, selectedPublisher?.id]);

  // Load publisher coverage and restore/set preview location
  const loadCoverage = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      // Fetch coverage areas (not cities directly)
      const coverageData = await api.get<{ coverage: PublisherCoverage[], total: number }>('/publisher/coverage');
      const coverageAreas = coverageData.coverage || [];

      // Extract unique country codes from coverage for filtering city search
      const countryCodes = [...new Set(
        coverageAreas
          .map(c => c.country_code)
          .filter((code): code is string => !!code)
      )];
      setCoverageCountryCodes(countryCodes);

      // For each coverage area, we need to get a representative city for preview
      const cities: CoverageCity[] = [];

      for (const coverage of coverageAreas) {
        if (coverage.coverage_level === 'city' && coverage.city_id) {
          // For city-level coverage, search for the specific city by name
          try {
            const cityData = await api.get<{ cities: CoverageCity[] }>(`/cities?search=${encodeURIComponent(coverage.city_name || '')}&limit=1`);
            if (cityData.cities && cityData.cities.length > 0) {
              cities.push(cityData.cities[0]);
            }
          } catch {
            // Ignore errors fetching individual cities
          }
        } else if (coverage.coverage_level === 'country' && coverage.country_code) {
          // For country-level coverage, get the most populous city in that country
          try {
            const cityData = await api.get<{ cities: CoverageCity[] }>(`/cities?country_code=${encodeURIComponent(coverage.country_code)}&limit=1`);
            if (cityData.cities && cityData.cities.length > 0) {
              cities.push(cityData.cities[0]);
            }
          } catch {
            // Ignore errors fetching country cities
          }
        } else if (coverage.coverage_level === 'region' && coverage.country_code && coverage.region) {
          // For region-level coverage, get a city in that region
          try {
            const cityData = await api.get<{ cities: CoverageCity[] }>(`/cities?search=${encodeURIComponent(coverage.region)}&country_code=${encodeURIComponent(coverage.country_code)}&limit=1`);
            if (cityData.cities && cityData.cities.length > 0) {
              cities.push(cityData.cities[0]);
            }
          } catch {
            // Ignore errors fetching region cities
          }
        }
      }

      setCoverageCities(cities);

      // Helper to check if a location is valid (matches a coverage city)
      const isLocationValid = (loc: PreviewLocation) => {
        return cities.some(city =>
          Math.abs(city.latitude - loc.latitude) < 0.01 &&
          Math.abs(city.longitude - loc.longitude) < 0.01
        );
      };

      // Try to restore saved location for this publisher
      const savedKey = PREVIEW_LOCATION_KEY_PREFIX + selectedPublisher.id;
      const saved = typeof window !== 'undefined' ? localStorage.getItem(savedKey) : null;

      if (saved) {
        try {
          const parsed = JSON.parse(saved) as PreviewLocation;
          // Only use saved location if it's still valid (in coverage)
          if (cities.length === 0 || isLocationValid(parsed)) {
            setPreviewLocation(parsed);
            return;
          }
          // Saved location is no longer valid, fall through to use first coverage city
          console.log('Saved location no longer in coverage, switching to first coverage city');
        } catch {
          // ignore parse errors, fall through to use coverage
        }
      }

      // No valid saved location - use first coverage city if available
      if (cities.length > 0) {
        const firstCity = cities[0];
        const newLocation = {
          latitude: firstCity.latitude,
          longitude: firstCity.longitude,
          timezone: firstCity.timezone,
          displayName: `${firstCity.name}${firstCity.region ? `, ${firstCity.region}` : ''}, ${firstCity.country}`,
        };
        setPreviewLocation(newLocation);
      }
    } catch (err) {
      console.error('Failed to load coverage:', err);
    }
  }, [api, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      loadCoverage();
    }
  }, [selectedPublisher, loadCoverage]);

  // Search for cities
  const handleCitySearch = async (query: string) => {
    setCitySearch(query);

    if (query.length < 2) {
      setSearchResults([]);
      setShowCityDropdown(false);
      return;
    }

    // First filter from coverage cities
    const coverageMatches = coverageCities.filter(city =>
      city.name.toLowerCase().includes(query.toLowerCase())
    );

    if (coverageMatches.length > 0) {
      setSearchResults(coverageMatches);
      setShowCityDropdown(true);
      return;
    }

    // Search cities within coverage area only
    // If we have coverage country codes, limit search to those countries
    try {
      const token = await getToken();
      let url = `${process.env.NEXT_PUBLIC_API_URL || ''}/api/v1/cities?search=${encodeURIComponent(query)}`;

      // Add country code filter if we have coverage
      if (coverageCountryCodes.length === 1) {
        url += `&country_code=${encodeURIComponent(coverageCountryCodes[0])}`;
      }

      const response = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        let cities = data.data?.cities || data.cities || [];

        // If we have multiple country codes, filter client-side by country_code field
        if (coverageCountryCodes.length > 1) {
          cities = cities.filter((city: { country_code?: string }) =>
            city.country_code && coverageCountryCodes.includes(city.country_code)
          );
        }

        setSearchResults(cities);
        setShowCityDropdown(true);
      }
    } catch (err) {
      console.error('Failed to search cities:', err);
    }
  };

  const selectCity = (city: CoverageCity) => {
    const newLocation = {
      latitude: city.latitude,
      longitude: city.longitude,
      timezone: city.timezone,
      displayName: `${city.name}${city.region ? `, ${city.region}` : ''}, ${city.country}`,
    };
    setPreviewLocation(newLocation);
    setCitySearch('');
    setSearchResults([]);
    setShowCityDropdown(false);
  };

  // Separate zmanim into everyday and event categories
  const { everydayZmanim, eventZmanim } = useMemo(() => {
    const everyday: PublisherZman[] = [];
    const events: PublisherZman[] = [];

    zmanim.forEach(z => {
      if (isEventZman(z.zman_key)) {
        events.push(z);
      } else {
        everyday.push(z);
      }
    });

    return { everydayZmanim: everyday, eventZmanim: events };
  }, [zmanim]);

  // Filter zmanim based on viewMode and other filters
  const filteredZmanim = useMemo(() => {
    // Start with zmanim based on view mode
    let result = viewMode === 'everyday' ? [...everydayZmanim] : [...eventZmanim];

    // Apply search filter
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      result = result.filter(z =>
        z.hebrew_name.toLowerCase().includes(query) ||
        z.english_name.toLowerCase().includes(query) ||
        z.zman_key.toLowerCase().includes(query)
      );
    }

    // Apply type filter
    switch (filterType) {
      case 'published':
        result = result.filter(z => z.is_published);
        break;
      case 'draft':
        result = result.filter(z => !z.is_published);
        break;
      case 'essential':
        result = result.filter(z => z.category === 'essential');
        break;
      case 'optional':
        result = result.filter(z => z.category === 'optional');
        break;
    }

    // Sort by sort_order only (category is just a visual label, not a grouping)
    result.sort((a, b) => a.sort_order - b.sort_order);

    return result;
  }, [everydayZmanim, eventZmanim, viewMode, searchQuery, filterType]);

  // Navigate to editor
  const handleEditZman = (zmanKey: string) => {
    router.push(`/publisher/algorithm/edit/${zmanKey}`);
  };

  // Existing zman keys to filter out in picker
  const existingZmanKeys = useMemo(() => zmanim.map(z => z.zman_key), [zmanim]);

  // Handlers for deleted zmanim
  const handleRestoreZman = async (zmanKey: string) => {
    await restoreZman.mutateAsync(zmanKey);
  };

  const handlePermanentDelete = async (zmanKey: string) => {
    if (confirm('Are you sure you want to permanently delete this zman? This cannot be undone.')) {
      await permanentDeleteZman.mutateAsync(zmanKey);
    }
  };

  // Import handlers
  const handleImportDefaults = async () => {
    try {
      await importZmanim.mutateAsync({ source: 'defaults' });
      setShowImportDialog(false);
    } catch (err) {
      console.error('Failed to import defaults:', err);
    }
  };

  // Calculate counts for current view
  const everydayCount = everydayZmanim.length;
  const eventCount = eventZmanim.length;
  const currentViewCount = viewMode === 'everyday' ? everydayCount : eventCount;
  const currentViewZmanim = viewMode === 'everyday' ? everydayZmanim : eventZmanim;
  const currentViewPublishedCount = currentViewZmanim.filter(z => z.is_published).length;
  const currentViewDraftCount = currentViewZmanim.filter(z => !z.is_published).length;
  const currentViewEssentialCount = currentViewZmanim.filter(z => z.category === 'essential').length;
  const currentViewOptionalCount = currentViewZmanim.filter(z => z.category === 'optional').length;

  // Show onboarding wizard if:
  // 1. User clicked "Restart Wizard" (forceShowWizard), OR
  // 2. No zmanim configured AND not completed onboarding
  const shouldShowWizard = forceShowWizard || (zmanim.length === 0 && !hasCompletedOnboarding);

  if (!isLoading && !onboardingLoading && shouldShowWizard) {
    return (
      <div className="min-h-screen bg-background">
        <OnboardingWizard
          publisherId={selectedPublisher?.id}
          onComplete={() => {
            refetch();
            refetchOnboarding();
            setForceShowWizard(false);
          }}
          onSkip={() => {
            refetchOnboarding();
            setForceShowWizard(false);
            // Stay on page but show empty state with import option
            setShowImportDialog(true);
          }}
        />
      </div>
    );
  }

  if (isLoading || onboardingLoading) {
    return (
      <div className="min-h-screen bg-background p-8">
        <div className="max-w-7xl mx-auto">
          <div className="flex justify-center items-center h-64">
            <div className="text-foreground">Loading zmanim...</div>
          </div>
        </div>
      </div>
    );
  }

  // Reset onboarding to restart wizard
  const handleRestartWizard = async () => {
    setShowRestartConfirm(false);
    try {
      await api.delete('/publisher/onboarding');
      // Set forceShowWizard first to trigger immediate re-render
      setForceShowWizard(true);
      // Then refetch in background
      refetchOnboarding();
      refetch(); // Refetch zmanim list to show empty state
    } catch (err) {
      console.error('Failed to reset onboarding:', err);
    }
  };

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8 flex justify-between items-start">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-3xl font-bold text-foreground">Algorithm Editor</h1>
              <Badge variant="outline" className="text-sm">
                {zmanim.length} Zmanim
              </Badge>
              <Badge variant="secondary" className="text-sm">
                {currentViewPublishedCount} Published
              </Badge>
            </div>
            <p className="text-muted-foreground">Configure your zmanim calculation formulas</p>
          </div>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowRestartConfirm(true)}
            >
              Restart Wizard
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowMonthView(true)}
            >
              View Week
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push('/publisher/dashboard')}
            >
              Back to Dashboard
            </Button>
          </div>
        </div>

        {/* Error message */}
        {zmanimError && (
          <div className="mb-6 bg-destructive/10 border border-destructive/50 rounded-md p-4">
            <p className="text-destructive text-sm">Failed to load zmanim. Please refresh the page.</p>
          </div>
        )}

        {/* Location & Date Header */}
        <Card className="mb-6">
          <CardContent className="py-4">
            <div className="flex items-center justify-between gap-4">
              {/* Left: Location */}
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-2 text-muted-foreground">
                  <MapPin className="h-4 w-4" />
                  <span className="text-sm font-medium">Preview Location:</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-foreground font-medium">{previewLocation.displayName}</span>
                </div>
                <div className="relative w-48">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <input
                      type="text"
                      placeholder="Search for a city..."
                      value={citySearch}
                      onChange={(e) => handleCitySearch(e.target.value)}
                      onFocus={() => citySearch.length >= 2 && setShowCityDropdown(true)}
                      onBlur={() => setTimeout(() => setShowCityDropdown(false), 200)}
                      className="bg-background border border-input rounded-md pl-10 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-ring cursor-text hover:bg-muted/50 w-full"
                    />
                  </div>
                  {showCityDropdown && searchResults.length > 0 && (
                    <div className="absolute top-full left-0 right-0 mt-1 bg-card border border-border rounded-md shadow-lg z-50 max-h-60 overflow-y-auto">
                      {searchResults.map((city) => (
                        <button
                          key={city.id}
                          className="w-full px-4 py-2 text-left text-sm hover:bg-muted transition-colors flex items-center gap-2"
                          onClick={() => selectCity(city)}
                        >
                          <MapPin className="h-3 w-3 text-muted-foreground flex-shrink-0" />
                          <span className="text-foreground">
                            {city.name}
                            {city.region && <span className="text-muted-foreground">, {city.region}</span>}
                            <span className="text-muted-foreground">, {city.country}</span>
                          </span>
                          {coverageCities.some(c => c.id === city.id) && (
                            <span className="ml-auto text-xs bg-primary/20 text-primary px-2 py-0.5 rounded">
                              Coverage
                            </span>
                          )}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Right: Date Pickers */}
              <div className="flex items-center gap-3">
                {/* Gregorian Date Picker Group */}
                <div className="flex items-center gap-1.5 bg-muted/30 rounded-lg px-3 py-1.5 border border-border/50">
                  <span className="text-xs font-medium text-muted-foreground mr-1">Gregorian</span>
                  <select
                    value={previewDate.getFullYear()}
                    onChange={(e) => {
                      const newDate = new Date(previewDate);
                      newDate.setFullYear(parseInt(e.target.value));
                      const maxDay = getDaysInMonth(parseInt(e.target.value), newDate.getMonth());
                      if (newDate.getDate() > maxDay) newDate.setDate(maxDay);
                      setPreviewDate(newDate);
                    }}
                    className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                  >
                    {englishYears.map((year) => (
                      <option key={year} value={year}>{year}</option>
                    ))}
                  </select>
                  <select
                    value={previewDate.getMonth()}
                    onChange={(e) => {
                      const newDate = new Date(previewDate);
                      const newMonth = parseInt(e.target.value);
                      const maxDay = getDaysInMonth(newDate.getFullYear(), newMonth);
                      if (newDate.getDate() > maxDay) newDate.setDate(maxDay);
                      newDate.setMonth(newMonth);
                      setPreviewDate(newDate);
                    }}
                    className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                  >
                    {monthNames.map((month, index) => (
                      <option key={month} value={index}>{month}</option>
                    ))}
                  </select>
                  <select
                    value={previewDate.getDate()}
                    onChange={(e) => {
                      const newDate = new Date(previewDate);
                      newDate.setDate(parseInt(e.target.value));
                      setPreviewDate(newDate);
                    }}
                    className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                  >
                    {Array.from(
                      { length: getDaysInMonth(previewDate.getFullYear(), previewDate.getMonth()) },
                      (_, i) => i + 1
                    ).map((day) => (
                      <option key={day} value={day}>{day}</option>
                    ))}
                  </select>
                </div>

                {/* Hebrew Date Picker Group */}
                {hebrewDate && hebrewDate.day && hebrewDate.month_num && hebrewDate.year && (
                  <div className="flex items-center gap-1.5 bg-muted/30 rounded-lg px-3 py-1.5 border border-border/50" dir="rtl">
                    <span className="text-xs font-medium text-muted-foreground ml-1 font-hebrew">עברי</span>
                    <select
                      value={hebrewDate.year}
                      onChange={(e) => handleHebrewDateChange(parseInt(e.target.value), hebrewDate.month_num, hebrewDate.day)}
                      className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium font-hebrew focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                    >
                      {hebrewYears.map((year) => (
                        <option key={year} value={year}>{toHebrewYear(year)}</option>
                      ))}
                    </select>
                    <select
                      value={hebrewDate.month_num}
                      onChange={(e) => handleHebrewDateChange(hebrewDate.year, parseInt(e.target.value), hebrewDate.day)}
                      className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium font-hebrew focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                    >
                      {hebrewMonthsWithNum.map((m) => (
                        <option key={m.num} value={m.num}>{m.heb}</option>
                      ))}
                    </select>
                    <select
                      value={hebrewDate.day}
                      onChange={(e) => handleHebrewDateChange(hebrewDate.year, hebrewDate.month_num, parseInt(e.target.value))}
                      className="bg-background border border-input rounded-md px-2 py-1.5 text-sm font-medium font-hebrew focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer hover:bg-muted/50"
                    >
                      {hebrewDays.map((day) => (
                        <option key={day} value={day}>{toHebrewNumerals(day)}</option>
                      ))}
                    </select>
                  </div>
                )}

                {/* Today Button */}
                <Button
                  variant={isToday ? "default" : "outline"}
                  size="sm"
                  onClick={goToToday}
                >
                  Today
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Editor Panel */}
          <div className="lg:col-span-2 space-y-6">
            {/* Everyday / Events Tabs */}
            <Tabs value={viewMode} onValueChange={(v) => setViewMode(v as 'everyday' | 'events')}>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="everyday" className="gap-2">
                  <CalendarDays className="h-4 w-4" />
                  Everyday Zmanim
                  <Badge variant="secondary" className="ml-1 text-xs">
                    {everydayCount}
                  </Badge>
                </TabsTrigger>
                <TabsTrigger value="events" className="gap-2">
                  <Flame className="h-4 w-4" />
                  Event Zmanim
                  <Badge variant="secondary" className="ml-1 text-xs">
                    {eventCount}
                  </Badge>
                </TabsTrigger>
              </TabsList>
            </Tabs>

            {/* Search, Filter, and Actions Bar */}
            <Card>
              <CardContent className="py-4">
                <div className="flex gap-3 mb-4">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Search zmanim by name or key..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                  <Button
                    variant="outline"
                    onClick={() => setShowImportDialog(true)}
                    className="flex items-center gap-2"
                  >
                    <Download className="h-4 w-4" />
                    Import
                  </Button>
                  <Button
                    variant="default"
                    onClick={() => setShowZmanPicker(true)}
                    className="flex items-center gap-2"
                  >
                    <Plus className="h-4 w-4" />
                    Add Zman
                  </Button>
                </div>

                {/* Filter Tabs */}
                <Tabs value={filterType} onValueChange={(v) => setFilterType(v as FilterType)}>
                  <TabsList>
                    <TabsTrigger value="all">
                      All ({currentViewCount})
                    </TabsTrigger>
                    <TabsTrigger value="published">
                      Published ({currentViewPublishedCount})
                    </TabsTrigger>
                    <TabsTrigger value="draft">
                      Draft ({currentViewDraftCount})
                    </TabsTrigger>
                    <TabsTrigger value="essential">
                      Core ({currentViewEssentialCount})
                    </TabsTrigger>
                    <TabsTrigger value="optional">
                      Optional ({currentViewOptionalCount})
                    </TabsTrigger>
                    {deletedZmanim.length > 0 && (
                      <TabsTrigger value="deleted" className="text-destructive">
                        Deleted ({deletedZmanim.length})
                      </TabsTrigger>
                    )}
                  </TabsList>
                </Tabs>
              </CardContent>
            </Card>

            {/* Zmanim List */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>
                      {filterType === 'deleted'
                        ? 'Deleted Zmanim'
                        : viewMode === 'everyday'
                          ? 'Everyday Zmanim'
                          : 'Event Zmanim'}
                    </CardTitle>
                    <CardDescription>
                      {filterType === 'deleted'
                        ? `${deletedZmanim.length} deleted zmanim available for restore`
                        : viewMode === 'everyday'
                          ? `${filteredZmanim.length} daily solar calculation times ${filterType !== 'all' ? '(filtered)' : ''}`
                          : `${filteredZmanim.length} Shabbos, holiday, and fast day times ${filterType !== 'all' ? '(filtered)' : ''}`}
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {filterType === 'deleted' ? (
                  /* Deleted Zmanim List */
                  deletedLoading ? (
                    <div className="flex justify-center py-8">
                      <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                    </div>
                  ) : deletedZmanim.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Trash2 className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>No deleted zmanim</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {deletedZmanim.map((dz) => (
                        <div
                          key={dz.id}
                          className="p-4 rounded-lg border border-destructive/20 bg-destructive/5"
                        >
                          <div className="flex items-center justify-between">
                            <div>
                              <h4 className="font-medium">
                                {dz.hebrew_name}
                                <span className="text-muted-foreground mx-2">•</span>
                                {dz.english_name}
                              </h4>
                              <p className="text-xs text-muted-foreground mt-1">
                                Deleted {new Date(dz.deleted_at).toLocaleDateString()}
                              </p>
                              <code className="text-xs text-muted-foreground mt-1 block font-mono">
                                {dz.formula_dsl}
                              </code>
                            </div>
                            <div className="flex gap-2">
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => handleRestoreZman(dz.zman_key)}
                                disabled={restoreZman.isPending}
                              >
                                {restoreZman.isPending ? (
                                  <Loader2 className="h-3 w-3 animate-spin mr-1" />
                                ) : (
                                  <RotateCcw className="h-3 w-3 mr-1" />
                                )}
                                Restore
                              </Button>
                              <Button
                                size="sm"
                                variant="destructive"
                                onClick={() => handlePermanentDelete(dz.zman_key)}
                                disabled={permanentDeleteZman.isPending}
                              >
                                <Trash2 className="h-3 w-3 mr-1" />
                                Delete Forever
                              </Button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )
                ) : (
                  /* Regular Zmanim Grid */
                  <ZmanGrid
                    zmanim={filteredZmanim}
                    category="optional" // This is just for styling, actual category comes from zman
                    onEdit={handleEditZman}
                  />
                )}
              </CardContent>
            </Card>
          </div>

          {/* Preview Panel - Shows only everyday zmanim for daily preview */}
          <div className="space-y-6">
            <AlgorithmPreview
              zmanim={everydayZmanim}
              location={previewLocation}
              selectedDate={previewDate}
            />
          </div>
        </div>

        {/* Week View Dialog - Shows all zmanim (event zmanim filtered by day) */}
        <Dialog open={showMonthView} onOpenChange={setShowMonthView}>
          <DialogContent className="max-w-5xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>Week Preview</DialogTitle>
            </DialogHeader>
            <WeekPreview
              zmanim={zmanim}
              getToken={getToken}
              location={previewLocation}
            />
          </DialogContent>
        </Dialog>

        {/* Import Dialog */}
        <Dialog open={showImportDialog} onOpenChange={setShowImportDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Import Zmanim</DialogTitle>
              <DialogDescription>
                Choose how to add zmanim to your algorithm
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <Button
                variant="outline"
                className="w-full justify-start h-auto py-4"
                onClick={handleImportDefaults}
                disabled={importZmanim.isPending}
              >
                <div className="text-left">
                  <div className="font-medium">Import Default Templates</div>
                  <div className="text-sm text-muted-foreground">
                    Add all 18 standard zmanim based on common halachic methods
                  </div>
                </div>
              </Button>
              <Button
                variant="outline"
                className="w-full justify-start h-auto py-4"
                onClick={() => {
                  setShowImportDialog(false);
                  // TODO: Open browse publishers dialog
                }}
              >
                <div className="text-left">
                  <div className="font-medium">Copy from Another Publisher</div>
                  <div className="text-sm text-muted-foreground">
                    Browse and copy algorithms from other publishers
                  </div>
                </div>
              </Button>
            </div>
          </DialogContent>
        </Dialog>

        {/* Master Zman Picker */}
        <MasterZmanPicker
          open={showZmanPicker}
          onOpenChange={setShowZmanPicker}
          existingZmanKeys={existingZmanKeys}
          onSuccess={() => refetch()}
        />

        {/* Restart Wizard Confirmation Dialog */}
        <AlertDialog open={showRestartConfirm} onOpenChange={setShowRestartConfirm}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle className="flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-amber-500" />
                Restart Setup Wizard?
              </AlertDialogTitle>
              <AlertDialogDescription className="space-y-3">
                <p>
                  This will <strong>permanently delete</strong> all your current zmanim and coverage areas.
                  You will start fresh with the setup wizard.
                </p>
                <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-md p-3 text-amber-800 dark:text-amber-200 text-sm">
                  <strong>Warning:</strong> This action cannot be undone. All zmanim and coverage areas will be permanently deleted.
                </div>
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                onClick={handleRestartWizard}
                className="bg-destructive hover:bg-destructive/90"
              >
                Delete & Restart
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}
