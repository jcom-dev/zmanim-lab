'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '@clerk/nextjs';
import { usePublisherContext } from '@/providers/PublisherContext';
import { MapPin, Globe, Building2, Plus, Trash2, ChevronRight, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
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
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import { API_BASE } from '@/lib/api';

interface Coverage {
  id: string;
  publisher_id: string;
  coverage_level: 'country' | 'region' | 'city';
  country_code: string | null;
  region: string | null;
  city_id: string | null;
  display_name: string;
  city_name: string;
  country: string;
  priority: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

interface Country {
  code: string;
  name: string;
  city_count: number;
}

interface Region {
  name: string;
  type: string | null;
  city_count: number;
}

interface City {
  id: string;
  name: string;
  country: string;
  region: string | null;
}

export default function PublisherCoveragePage() {
  const { getToken } = useAuth();
  const { selectedPublisher, isLoading: contextLoading } = usePublisherContext();

  const [coverage, setCoverage] = useState<Coverage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Add dialog state
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [countries, setCountries] = useState<Country[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [selectedCountry, setSelectedCountry] = useState<Country | null>(null);
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const [loadingCountries, setLoadingCountries] = useState(false);
  const [loadingRegions, setLoadingRegions] = useState(false);
  const [loadingCities, setLoadingCities] = useState(false);
  const [addingCoverage, setAddingCoverage] = useState(false);

  const fetchCoverage = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setIsLoading(true);
      setError(null);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/coverage`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch coverage');
      }

      const data = await response.json();
      setCoverage(data.data?.coverage || data.coverage || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load coverage');
    } finally {
      setIsLoading(false);
    }
  }, [getToken, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      fetchCoverage();
    }
  }, [selectedPublisher, fetchCoverage]);

  const fetchCountries = async () => {
    try {
      setLoadingCountries(true);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/countries`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) throw new Error('Failed to fetch countries');

      const data = await response.json();
      setCountries(data.data?.countries || data.countries || []);
    } catch (err) {
      console.error('Failed to fetch countries:', err);
    } finally {
      setLoadingCountries(false);
    }
  };

  const fetchRegions = async (countryCode: string) => {
    try {
      setLoadingRegions(true);
      setRegions([]);
      setCities([]);
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/regions?country_code=${countryCode}`, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) throw new Error('Failed to fetch regions');

      const data = await response.json();
      const regionList = data.data?.regions || data.regions || [];
      setRegions(regionList);

      // If no regions, load cities directly
      if (regionList.length === 0) {
        fetchCities(countryCode, null);
      }
    } catch (err) {
      console.error('Failed to fetch regions:', err);
    } finally {
      setLoadingRegions(false);
    }
  };

  const fetchCities = async (countryCode: string, regionName: string | null) => {
    try {
      setLoadingCities(true);
      const token = await getToken();

      let url = `${API_BASE}/api/v1/cities?country_code=${countryCode}&limit=100`;
      if (regionName) {
        url += `&region=${encodeURIComponent(regionName)}`;
      }

      const response = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) throw new Error('Failed to fetch cities');

      const data = await response.json();
      setCities(data.data?.cities || data.cities || []);
    } catch (err) {
      console.error('Failed to fetch cities:', err);
    } finally {
      setLoadingCities(false);
    }
  };

  const handleOpenAddDialog = () => {
    setAddDialogOpen(true);
    setSelectedCountry(null);
    setSelectedRegion(null);
    setRegions([]);
    setCities([]);
    fetchCountries();
  };

  const handleSelectCountry = (country: Country) => {
    setSelectedCountry(country);
    setSelectedRegion(null);
    fetchRegions(country.code);
  };

  const handleSelectRegion = (region: Region) => {
    setSelectedRegion(region);
    if (selectedCountry) {
      fetchCities(selectedCountry.code, region.name);
    }
  };

  const handleAddCoverage = async (level: 'country' | 'region' | 'city', cityId?: string) => {
    if (!selectedPublisher) return;

    try {
      setAddingCoverage(true);
      const token = await getToken();

      const body: Record<string, unknown> = { coverage_level: level };

      if (level === 'country' && selectedCountry) {
        body.country_code = selectedCountry.code;
      } else if (level === 'region' && selectedCountry && selectedRegion) {
        body.country_code = selectedCountry.code;
        body.region = selectedRegion.name;
      } else if (level === 'city' && cityId) {
        body.city_id = cityId;
      }

      const response = await fetch(`${API_BASE}/api/v1/publisher/coverage`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || data.message || 'Failed to add coverage');
      }

      await fetchCoverage();
      setAddDialogOpen(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add coverage');
    } finally {
      setAddingCoverage(false);
    }
  };

  const handleDeleteCoverage = async (coverageId: string) => {
    if (!selectedPublisher) return;

    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/coverage/${coverageId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to delete coverage');
      }

      await fetchCoverage();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete coverage');
    }
  };

  const handleToggleActive = async (coverageItem: Coverage) => {
    if (!selectedPublisher) return;

    try {
      const token = await getToken();

      const response = await fetch(`${API_BASE}/api/v1/publisher/coverage/${coverageItem.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
        body: JSON.stringify({ is_active: !coverageItem.is_active }),
      });

      if (!response.ok) {
        throw new Error('Failed to update coverage');
      }

      await fetchCoverage();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update coverage');
    }
  };

  const getLevelIcon = (level: string) => {
    switch (level) {
      case 'country':
        return <Globe className="w-4 h-4" />;
      case 'region':
        return <Building2 className="w-4 h-4" />;
      case 'city':
        return <MapPin className="w-4 h-4" />;
      default:
        return <MapPin className="w-4 h-4" />;
    }
  };

  const getLevelBadgeColor = (level: string) => {
    switch (level) {
      case 'country':
        return 'bg-blue-500/20 text-blue-400 border-blue-500/50';
      case 'region':
        return 'bg-green-500/20 text-green-400 border-green-500/50';
      case 'city':
        return 'bg-purple-500/20 text-purple-400 border-purple-500/50';
      default:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/50';
    }
  };

  if (contextLoading || isLoading) {
    return (
      <div className="p-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center py-12">
            <Loader2 className="w-8 h-8 text-blue-600 dark:text-blue-400 animate-spin mx-auto" />
            <p className="mt-4 text-muted-foreground">Loading coverage...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold">Coverage Areas</h1>
            <p className="text-muted-foreground mt-1">
              Define where users can find your zmanim
            </p>
          </div>
          <Button onClick={handleOpenAddDialog}>
            <Plus className="w-4 h-4 mr-2" />
            Add Coverage
          </Button>
        </div>

        {error && (
          <div className="mb-6 bg-red-900/50 border border-red-700 dark:bg-red-950 dark:border-red-700 rounded-lg p-4">
            <p className="text-red-200 dark:text-red-300">{error}</p>
          </div>
        )}

        {/* Coverage List */}
        {coverage.length === 0 ? (
          <div className="bg-card rounded-lg border border-border p-12 text-center">
            <MapPin className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="text-lg font-semibold mb-2">No Coverage Areas</h3>
            <p className="text-muted-foreground mb-4">
              Add coverage areas to define where users can find your zmanim.
            </p>
            <Button onClick={handleOpenAddDialog}>
              <Plus className="w-4 h-4 mr-2" />
              Add Coverage
            </Button>
          </div>
        ) : (
          <div className="space-y-3">
            {coverage.map((item) => (
              <div
                key={item.id}
                className={`bg-card rounded-lg border p-4 flex items-center justify-between ${
                  item.is_active ? 'border-border' : 'border-border opacity-60'
                }`}
              >
                <div className="flex items-center gap-4">
                  <div className={`p-2 rounded-lg ${getLevelBadgeColor(item.coverage_level)}`}>
                    {getLevelIcon(item.coverage_level)}
                  </div>
                  <div>
                    <div className="font-medium">{item.display_name || item.city_name || item.country}</div>
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <span className={`px-2 py-0.5 rounded-full border text-xs ${getLevelBadgeColor(item.coverage_level)}`}>
                        {item.coverage_level}
                      </span>
                      <span>Priority: {item.priority}</span>
                      {!item.is_active && <span className="text-yellow-600 dark:text-yellow-400">Inactive</span>}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleToggleActive(item)}
                  >
                    {item.is_active ? 'Deactivate' : 'Activate'}
                  </Button>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button variant="ghost" size="sm" className="text-red-400 hover:text-red-300">
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Delete Coverage</AlertDialogTitle>
                        <AlertDialogDescription>
                          Are you sure you want to remove this coverage area?
                          Users in this area will no longer see your zmanim.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={() => handleDeleteCoverage(item.id)}>
                          Delete
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Add Coverage Dialog */}
        <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
          <DialogContent className="max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
            <DialogHeader>
              <DialogTitle>Add Coverage Area</DialogTitle>
              <DialogDescription>
                Select a country, region, or city to add to your coverage.
              </DialogDescription>
            </DialogHeader>

            {/* Breadcrumb */}
            <div className="flex items-center gap-2 text-sm py-2 border-b border-border">
              <button
                onClick={() => {
                  setSelectedCountry(null);
                  setSelectedRegion(null);
                  setRegions([]);
                  setCities([]);
                }}
                className={!selectedCountry ? 'text-blue-600 dark:text-blue-400' : 'text-muted-foreground hover:text-foreground'}
              >
                Countries
              </button>
              {selectedCountry && (
                <>
                  <ChevronRight className="w-4 h-4 text-muted-foreground" />
                  <button
                    onClick={() => {
                      setSelectedRegion(null);
                      setCities([]);
                    }}
                    className={selectedCountry && !selectedRegion ? 'text-blue-600 dark:text-blue-400' : 'text-muted-foreground hover:text-foreground'}
                  >
                    {selectedCountry.name}
                  </button>
                </>
              )}
              {selectedRegion && (
                <>
                  <ChevronRight className="w-4 h-4 text-muted-foreground" />
                  <span className="text-blue-600 dark:text-blue-400">{selectedRegion.name}</span>
                </>
              )}
            </div>

            {/* Add at current level button */}
            {selectedCountry && (
              <div className="py-2 border-b border-border">
                {!selectedRegion ? (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleAddCoverage('country')}
                    disabled={addingCoverage}
                  >
                    {addingCoverage ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <Plus className="w-4 h-4 mr-2" />}
                    Add entire {selectedCountry.name}
                  </Button>
                ) : (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleAddCoverage('region')}
                    disabled={addingCoverage}
                  >
                    {addingCoverage ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <Plus className="w-4 h-4 mr-2" />}
                    Add entire {selectedRegion.name}
                  </Button>
                )}
              </div>
            )}

            {/* Selection Area */}
            <div className="flex-1 overflow-y-auto min-h-[300px]">
              {/* Country Selection */}
              {!selectedCountry && (
                loadingCountries ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-blue-600 dark:text-blue-400 animate-spin" />
                  </div>
                ) : (
                  <div className="grid gap-2 py-2">
                    {countries.map((country) => (
                      <button
                        key={country.code}
                        onClick={() => handleSelectCountry(country)}
                        className="flex items-center justify-between p-3 bg-secondary/50 hover:bg-secondary rounded-lg text-left transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <Globe className="w-5 h-5 text-muted-foreground" />
                          <div>
                            <div className="font-medium">{country.name}</div>
                            <div className="text-sm text-muted-foreground">{country.city_count} cities</div>
                          </div>
                        </div>
                        <ChevronRight className="w-5 h-5 text-muted-foreground" />
                      </button>
                    ))}
                  </div>
                )
              )}

              {/* Region Selection */}
              {selectedCountry && !selectedRegion && regions.length > 0 && (
                loadingRegions ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-blue-600 dark:text-blue-400 animate-spin" />
                  </div>
                ) : (
                  <div className="grid gap-2 py-2">
                    {regions.map((region) => (
                      <button
                        key={region.name}
                        onClick={() => handleSelectRegion(region)}
                        className="flex items-center justify-between p-3 bg-secondary/50 hover:bg-secondary rounded-lg text-left transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <Building2 className="w-5 h-5 text-muted-foreground" />
                          <div>
                            <div className="font-medium">{region.name}</div>
                            <div className="text-sm text-muted-foreground">
                              {region.type && `${region.type} • `}{region.city_count} cities
                            </div>
                          </div>
                        </div>
                        <ChevronRight className="w-5 h-5 text-muted-foreground" />
                      </button>
                    ))}
                  </div>
                )
              )}

              {/* City Selection */}
              {(selectedRegion || (selectedCountry && regions.length === 0)) && (
                loadingCities ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-blue-600 dark:text-blue-400 animate-spin" />
                  </div>
                ) : cities.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground">
                    No cities found in this area.
                  </div>
                ) : (
                  <div className="grid gap-2 py-2">
                    {cities.map((city) => (
                      <button
                        key={city.id}
                        onClick={() => handleAddCoverage('city', city.id)}
                        disabled={addingCoverage}
                        className="flex items-center justify-between p-3 bg-secondary/50 hover:bg-secondary rounded-lg text-left transition-colors disabled:opacity-50"
                      >
                        <div className="flex items-center gap-3">
                          <MapPin className="w-5 h-5 text-muted-foreground" />
                          <div>
                            <div className="font-medium">{city.name}</div>
                            <div className="text-sm text-muted-foreground">
                              {city.region && `${city.region}, `}{city.country}
                            </div>
                          </div>
                        </div>
                        <Plus className="w-5 h-5 text-muted-foreground" />
                      </button>
                    ))}
                  </div>
                )
              )}
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}
