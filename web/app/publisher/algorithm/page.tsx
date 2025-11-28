'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { useAuthenticatedFetch, ApiError } from '@/lib/hooks/useAuthenticatedFetch';
import { API_BASE } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { ZmanGrid } from '@/components/publisher/ZmanCard';
import { AlgorithmPreview } from '@/components/publisher/AlgorithmPreview';
import { MonthPreview } from '@/components/publisher/MonthPreview';
import { VersionHistory } from '@/components/publisher/VersionHistory';
import { useZmanimList, categorizeZmanim } from '@/lib/hooks/useZmanimList';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { MapPin, Search, Plus, Filter } from 'lucide-react';
import { Badge } from '@/components/ui/badge';

// Default location: Brooklyn, NY
const DEFAULT_LOCATION = {
  latitude: 40.6782,
  longitude: -73.9442,
  timezone: 'America/New_York',
  displayName: 'Brooklyn, NY',
};

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

export default function AlgorithmEditorPage() {
  const router = useRouter();
  const { getToken } = useAuth();
  const { selectedPublisher } = usePublisherContext();
  const { fetchWithAuth } = useAuthenticatedFetch();

  // Fetch zmanim using React Query
  const { data: zmanim = [], isLoading, error: zmanimError } = useZmanimList();

  const [showMonthView, setShowMonthView] = useState(false);
  const [showVersionHistory, setShowVersionHistory] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState<'all' | 'essential' | 'optional' | 'custom'>('all');

  // Location state
  const [previewLocation, setPreviewLocation] = useState<PreviewLocation>(DEFAULT_LOCATION);
  const [coverageCities, setCoverageCities] = useState<CoverageCity[]>([]);
  const [citySearch, setCitySearch] = useState('');
  const [searchResults, setSearchResults] = useState<CoverageCity[]>([]);
  const [showCityDropdown, setShowCityDropdown] = useState(false);

  // Load publisher coverage cities and set default location
  const loadCoverage = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      const data = await fetchWithAuth<{ cities: CoverageCity[] }>('/api/v1/publisher/coverage');
      const cities = data.cities || [];
      setCoverageCities(cities);

      // Set default location from coverage if available
      if (cities.length > 0) {
        const firstCity = cities[0];
        setPreviewLocation({
          latitude: firstCity.latitude,
          longitude: firstCity.longitude,
          timezone: firstCity.timezone,
          displayName: `${firstCity.name}${firstCity.region ? `, ${firstCity.region}` : ''}, ${firstCity.country}`,
        });
      }
    } catch (err) {
      console.error('Failed to load coverage:', err);
      // Keep default location on error
    }
  }, [fetchWithAuth, selectedPublisher]);

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

    // If no coverage matches, search all cities
    try {
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/cities/search?q=${encodeURIComponent(query)}`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        setSearchResults(data.data?.cities || data.cities || []);
        setShowCityDropdown(true);
      }
    } catch (err) {
      console.error('Failed to search cities:', err);
    }
  };

  const selectCity = (city: CoverageCity) => {
    setPreviewLocation({
      latitude: city.latitude,
      longitude: city.longitude,
      timezone: city.timezone,
      displayName: `${city.name}${city.region ? `, ${city.region}` : ''}, ${city.country}`,
    });
    setCitySearch('');
    setSearchResults([]);
    setShowCityDropdown(false);
  };

  // Categorize and filter zmanim
  const { essential, optional, custom } = useMemo(() => {
    const categorized = categorizeZmanim(zmanim);

    if (searchQuery.trim() === '') {
      return categorized;
    }

    const query = searchQuery.toLowerCase();
    const filterFn = (z: typeof zmanim[0]) =>
      z.hebrew_name.toLowerCase().includes(query) ||
      z.english_name.toLowerCase().includes(query) ||
      z.zman_key.toLowerCase().includes(query);

    return {
      essential: categorized.essential.filter(filterFn),
      optional: categorized.optional.filter(filterFn),
      custom: categorized.custom.filter(filterFn),
    };
  }, [zmanim, searchQuery]);

  // Navigate to editor
  const handleEditZman = (zmanKey: string) => {
    router.push(`/publisher/algorithm/edit/${zmanKey}`);
  };

  const handleAddCustomZman = () => {
    router.push('/publisher/algorithm/edit/new');
  };

  // Calculate counts
  const totalCount = zmanim.length;
  const enabledCount = zmanim.filter(z => z.is_enabled).length;
  const visibleCount = zmanim.filter(z => z.is_visible).length;

  if (isLoading) {
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

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8 flex justify-between items-start">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-3xl font-bold text-foreground">Algorithm Editor</h1>
              <Badge variant="outline" className="text-sm">
                {totalCount} Zmanim
              </Badge>
              <Badge variant="secondary" className="text-sm">
                {enabledCount} Enabled
              </Badge>
            </div>
            <p className="text-muted-foreground">Configure your zmanim calculation formulas</p>
          </div>
          <div className="flex gap-4">
            <Button
              variant="outline"
              onClick={() => setShowVersionHistory(!showVersionHistory)}
            >
              {showVersionHistory ? 'Hide History' : 'Version History'}
            </Button>
            <Button
              variant="outline"
              onClick={() => setShowMonthView(true)}
            >
              View Month
            </Button>
            <Button
              variant="outline"
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

        {/* Location Selector */}
        <Card className="mb-6">
          <CardContent className="py-4">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 text-muted-foreground">
                <MapPin className="h-4 w-4" />
                <span className="text-sm font-medium">Preview Location:</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-foreground font-medium">{previewLocation.displayName}</span>
              </div>
              <div className="relative flex-1 max-w-xs">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    placeholder="Search for a city..."
                    value={citySearch}
                    onChange={(e) => handleCitySearch(e.target.value)}
                    onFocus={() => citySearch.length >= 2 && setShowCityDropdown(true)}
                    onBlur={() => setTimeout(() => setShowCityDropdown(false), 200)}
                    className="pl-10"
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
              {coverageCities.length > 0 && (
                <div className="text-xs text-muted-foreground">
                  {coverageCities.length} coverage {coverageCities.length === 1 ? 'city' : 'cities'}
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Editor Panel */}
          <div className="lg:col-span-2 space-y-6">
            {/* Search and Filter Bar */}
            <Card>
              <CardContent className="py-4">
                <div className="flex gap-3">
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
                    variant="default"
                    onClick={handleAddCustomZman}
                    className="flex items-center gap-2"
                  >
                    <Plus className="h-4 w-4" />
                    Add Custom Zman
                  </Button>
                </div>
              </CardContent>
            </Card>

            {/* Essential Zmanim */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Essential Zmanim</CardTitle>
                    <CardDescription>
                      Required zmanim that cannot be deleted
                    </CardDescription>
                  </div>
                  <Badge variant="secondary">{essential.length}</Badge>
                </div>
              </CardHeader>
              <CardContent>
                <ZmanGrid
                  zmanim={essential}
                  category="essential"
                  onEdit={handleEditZman}
                />
              </CardContent>
            </Card>

            {/* Optional Zmanim */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Optional Zmanim</CardTitle>
                    <CardDescription>
                      Common zmanim that can be hidden or customized
                    </CardDescription>
                  </div>
                  <Badge variant="secondary">{optional.length}</Badge>
                </div>
              </CardHeader>
              <CardContent>
                <ZmanGrid
                  zmanim={optional}
                  category="optional"
                  onEdit={handleEditZman}
                />
              </CardContent>
            </Card>

            {/* Custom Zmanim */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Custom Zmanim</CardTitle>
                    <CardDescription>
                      Your custom zmanim created for specific needs
                    </CardDescription>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant="secondary">{custom.length}</Badge>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={handleAddCustomZman}
                      className="flex items-center gap-1 h-8"
                    >
                      <Plus className="h-3 w-3" />
                      Add
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <ZmanGrid
                  zmanim={custom}
                  category="custom"
                  onEdit={handleEditZman}
                />
              </CardContent>
            </Card>
          </div>

          {/* Preview Panel */}
          <div className="space-y-6">
            <AlgorithmPreview
              configuration={{
                name: 'Current Algorithm',
                description: 'Live preview of zmanim calculations',
                zmanim: {}, // Legacy prop, not used for new system
              }}
              getToken={getToken}
              location={previewLocation}
            />
          </div>
        </div>

        {/* Month View Dialog */}
        <Dialog open={showMonthView} onOpenChange={setShowMonthView}>
          <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>Month Preview</DialogTitle>
            </DialogHeader>
            <MonthPreview
              configuration={{
                name: 'Current Algorithm',
                description: 'Monthly preview',
                zmanim: {},
              }}
              getToken={getToken}
              location={previewLocation}
            />
          </DialogContent>
        </Dialog>

        {/* Version History */}
        {showVersionHistory && (
          <div className="mt-6">
            <VersionHistory onClose={() => setShowVersionHistory(false)} getToken={getToken} />
          </div>
        )}
      </div>
    </div>
  );
}
