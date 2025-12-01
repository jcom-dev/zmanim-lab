'use client';

import { useState, useEffect, useCallback } from 'react';
import { usePublisherContext } from '@/providers/PublisherContext';
import { MapPin, Globe, Building2, Plus, Trash2, ChevronRight, Loader2, Mountain } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
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
import { useApi } from '@/lib/api-client';
import { getCoverageBadgeClasses } from '@/lib/wcag-colors';

interface Coverage {
  id: string;
  publisher_id: string;
  coverage_level: 'continent' | 'country' | 'region' | 'city';
  continent_code: string | null;
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

interface Continent {
  code: string;
  name: string;
  city_count: number;
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
  const api = useApi();
  const { selectedPublisher, isLoading: contextLoading } = usePublisherContext();

  const [coverage, setCoverage] = useState<Coverage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Add dialog state
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [continents, setContinents] = useState<Continent[]>([]);
  const [countries, setCountries] = useState<Country[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [selectedContinent, setSelectedContinent] = useState<Continent | null>(null);
  const [selectedCountry, setSelectedCountry] = useState<Country | null>(null);
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const [loadingContinents, setLoadingContinents] = useState(false);
  const [loadingCountries, setLoadingCountries] = useState(false);
  const [loadingRegions, setLoadingRegions] = useState(false);
  const [loadingCities, setLoadingCities] = useState(false);
  const [addingCoverage, setAddingCoverage] = useState(false);

  const fetchCoverage = useCallback(async () => {
    if (!selectedPublisher) return;

    try {
      setIsLoading(true);
      setError(null);

      const data = await api.get<{ coverage: Coverage[] }>('/publisher/coverage');
      setCoverage(data.coverage || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load coverage');
    } finally {
      setIsLoading(false);
    }
  }, [api, selectedPublisher]);

  useEffect(() => {
    if (selectedPublisher) {
      fetchCoverage();
    }
  }, [selectedPublisher, fetchCoverage]);

  const fetchContinents = async () => {
    try {
      setLoadingContinents(true);

      const data = await api.get<{ continents: Continent[] }>('/continents', { skipPublisherId: true });
      setContinents(data.continents || []);
    } catch (err) {
      console.error('Failed to fetch continents:', err);
    } finally {
      setLoadingContinents(false);
    }
  };

  const fetchCountries = async (continentCode: string) => {
    try {
      setLoadingCountries(true);
      setCountries([]);
      setRegions([]);
      setCities([]);

      const data = await api.get<{ countries: Country[] }>(`/countries?continent=${continentCode}`, { skipPublisherId: true });
      setCountries(data.countries || []);
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

      const data = await api.get<{ regions: Region[] }>(`/regions?country_code=${countryCode}`, { skipPublisherId: true });
      const regionList = data.regions || [];
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

      let url = `/cities?country_code=${countryCode}&limit=100`;
      if (regionName) {
        url += `&region=${encodeURIComponent(regionName)}`;
      }

      const data = await api.get<{ cities: City[] }>(url, { skipPublisherId: true });
      setCities(data.cities || []);
    } catch (err) {
      console.error('Failed to fetch cities:', err);
    } finally {
      setLoadingCities(false);
    }
  };

  const handleOpenAddDialog = () => {
    setAddDialogOpen(true);
    setSelectedContinent(null);
    setSelectedCountry(null);
    setSelectedRegion(null);
    setContinents([]);
    setCountries([]);
    setRegions([]);
    setCities([]);
    fetchContinents();
  };

  const handleSelectContinent = (continent: Continent) => {
    setSelectedContinent(continent);
    setSelectedCountry(null);
    setSelectedRegion(null);
    fetchCountries(continent.code);
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

  const handleAddCoverage = async (level: 'continent' | 'country' | 'region' | 'city', cityId?: string) => {
    if (!selectedPublisher) return;

    try {
      setAddingCoverage(true);

      const body: Record<string, unknown> = { coverage_level: level };

      if (level === 'continent' && selectedContinent) {
        body.continent_code = selectedContinent.code;
      } else if (level === 'country' && selectedCountry) {
        body.country_code = selectedCountry.code;
      } else if (level === 'region' && selectedCountry && selectedRegion) {
        body.country_code = selectedCountry.code;
        body.region = selectedRegion.name;
      } else if (level === 'city' && cityId) {
        body.city_id = cityId;
      }

      await api.post('/publisher/coverage', {
        body: JSON.stringify(body),
      });

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
      await api.delete(`/publisher/coverage/${coverageId}`);
      await fetchCoverage();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete coverage');
    }
  };

  const handleToggleActive = async (coverageItem: Coverage) => {
    if (!selectedPublisher) return;

    try {
      await api.put(`/publisher/coverage/${coverageItem.id}`, {
        body: JSON.stringify({ is_active: !coverageItem.is_active }),
      });
      await fetchCoverage();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update coverage');
    }
  };

  const getLevelIcon = (level: string) => {
    switch (level) {
      case 'continent':
        return <Mountain className="w-4 h-4" />;
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
    return getCoverageBadgeClasses(level);
  };

  const resetToStep = (step: 'continents' | 'countries' | 'regions') => {
    if (step === 'continents') {
      setSelectedContinent(null);
      setSelectedCountry(null);
      setSelectedRegion(null);
      setCountries([]);
      setRegions([]);
      setCities([]);
    } else if (step === 'countries') {
      setSelectedCountry(null);
      setSelectedRegion(null);
      setRegions([]);
      setCities([]);
    } else if (step === 'regions') {
      setSelectedRegion(null);
      setCities([]);
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
    <div className="p-4 sm:p-6 lg:p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6 sm:mb-8">
          <div>
            <h1 className="text-2xl sm:text-3xl font-bold">Coverage Areas</h1>
            <p className="text-sm sm:text-base text-muted-foreground mt-1">
              Define where users can find your zmanim
            </p>
          </div>
          <Button onClick={handleOpenAddDialog} className="w-full sm:w-auto">
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
          <div className="bg-card rounded-lg border border-border p-8 sm:p-12 text-center">
            <MapPin className="w-10 h-10 sm:w-12 sm:h-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="text-base sm:text-lg font-semibold mb-2">No Coverage Areas</h3>
            <p className="text-sm sm:text-base text-muted-foreground mb-4">
              Add coverage areas to define where users can find your zmanim.
            </p>
            <Button onClick={handleOpenAddDialog} className="w-full sm:w-auto">
              <Plus className="w-4 h-4 mr-2" />
              Add Coverage
            </Button>
          </div>
        ) : (
          <div className="space-y-3">
            {coverage.map((item) => (
              <div
                key={item.id}
                className={`bg-card rounded-lg border p-3 sm:p-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 ${
                  item.is_active ? 'border-border' : 'border-border opacity-60'
                }`}
              >
                <div className="flex items-center gap-3 sm:gap-4 min-w-0">
                  <div className={`p-2 rounded-lg flex-shrink-0 ${getLevelBadgeColor(item.coverage_level)}`}>
                    {getLevelIcon(item.coverage_level)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm sm:text-base truncate">{item.display_name || item.city_name || item.country}</div>
                    <div className="flex items-center gap-2 text-xs sm:text-sm text-muted-foreground flex-wrap">
                      <span className={`px-2 py-0.5 rounded-full border text-xs ${getLevelBadgeColor(item.coverage_level)}`}>
                        {item.coverage_level}
                      </span>
                      <span className="whitespace-nowrap">Priority: {item.priority}</span>
                      {!item.is_active && <span className="text-yellow-600 dark:text-yellow-400 whitespace-nowrap">Inactive</span>}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 self-end sm:self-auto">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleToggleActive(item)}
                    className="text-xs sm:text-sm"
                  >
                    {item.is_active ? 'Deactivate' : 'Activate'}
                  </Button>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button variant="ghost" size="sm" className="text-red-400 hover:text-red-300">
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent className="max-w-[90vw] sm:max-w-lg">
                      <AlertDialogHeader>
                        <AlertDialogTitle>Delete Coverage</AlertDialogTitle>
                        <AlertDialogDescription className="text-sm">
                          Are you sure you want to remove this coverage area?
                          Users in this area will no longer see your zmanim.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter className="flex-col sm:flex-row gap-2">
                        <AlertDialogCancel className="w-full sm:w-auto">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={() => handleDeleteCoverage(item.id)} className="w-full sm:w-auto">
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
          <DialogContent className="max-w-[95vw] sm:max-w-2xl max-h-[90vh] sm:max-h-[80vh] overflow-hidden flex flex-col">
            <DialogHeader>
              <DialogTitle className="text-lg sm:text-xl">Add Coverage Area</DialogTitle>
              <DialogDescription className="text-sm sm:text-base">
                Select a continent, country, region, or city to add to your coverage.
              </DialogDescription>
            </DialogHeader>

            {/* Breadcrumb Navigation */}
            <div className="flex items-center gap-1 sm:gap-2 text-xs sm:text-sm py-2 border-b border-border overflow-x-auto">
              <button
                onClick={() => resetToStep('continents')}
                className={`whitespace-nowrap ${!selectedContinent ? 'text-primary font-medium' : 'text-muted-foreground hover:text-foreground'}`}
                aria-label="Go to continent selection"
              >
                Continent
              </button>
              <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-muted-foreground flex-shrink-0" />
              {selectedContinent ? (
                <>
                  <button
                    onClick={() => resetToStep('countries')}
                    className={`whitespace-nowrap ${selectedContinent && !selectedCountry ? 'text-primary font-medium' : 'text-muted-foreground hover:text-foreground'}`}
                    aria-label="Go to country selection"
                  >
                    Country
                  </button>
                  <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-muted-foreground flex-shrink-0" />
                </>
              ) : (
                <>
                  <span className="text-muted-foreground whitespace-nowrap">Country</span>
                  <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-muted-foreground flex-shrink-0" />
                </>
              )}
              {selectedCountry ? (
                <>
                  <button
                    onClick={() => resetToStep('regions')}
                    className={`whitespace-nowrap ${selectedCountry && !selectedRegion ? 'text-primary font-medium' : 'text-muted-foreground hover:text-foreground'}`}
                    aria-label="Go to region selection"
                  >
                    Region
                  </button>
                  <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-muted-foreground flex-shrink-0" />
                </>
              ) : (
                <>
                  <span className="text-muted-foreground whitespace-nowrap">Region</span>
                  <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-muted-foreground flex-shrink-0" />
                </>
              )}
              {selectedRegion ? (
                <span className="text-primary font-medium whitespace-nowrap">City</span>
              ) : (
                <span className="text-muted-foreground whitespace-nowrap">City</span>
              )}
            </div>

            {/* Add at current level button */}
            {selectedContinent && !selectedCountry && (
              <div className="py-2 border-b border-border">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleAddCoverage('continent')}
                  disabled={addingCoverage}
                  className="w-full sm:w-auto text-xs sm:text-sm"
                >
                  {addingCoverage ? <Loader2 className="w-3 h-3 sm:w-4 sm:h-4 animate-spin mr-2" /> : <Plus className="w-3 h-3 sm:w-4 sm:h-4 mr-2" />}
                  <span className="truncate">Add entire {selectedContinent.name}</span>
                </Button>
              </div>
            )}
            {selectedCountry && (
              <div className="py-2 border-b border-border">
                {!selectedRegion ? (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleAddCoverage('country')}
                    disabled={addingCoverage}
                    className="w-full sm:w-auto text-xs sm:text-sm"
                  >
                    {addingCoverage ? <Loader2 className="w-3 h-3 sm:w-4 sm:h-4 animate-spin mr-2" /> : <Plus className="w-3 h-3 sm:w-4 sm:h-4 mr-2" />}
                    <span className="truncate">Add entire {selectedCountry.name}</span>
                  </Button>
                ) : (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleAddCoverage('region')}
                    disabled={addingCoverage}
                    className="w-full sm:w-auto text-xs sm:text-sm"
                  >
                    {addingCoverage ? <Loader2 className="w-3 h-3 sm:w-4 sm:h-4 animate-spin mr-2" /> : <Plus className="w-3 h-3 sm:w-4 sm:h-4 mr-2" />}
                    <span className="truncate">Add entire {selectedRegion.name}</span>
                  </Button>
                )}
              </div>
            )}

            {/* Selection Area */}
            <ScrollArea className="flex-1 min-h-[250px] sm:min-h-[300px]">
              {/* Continent Selection */}
              {!selectedContinent && (
                loadingContinents ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-primary animate-spin" />
                  </div>
                ) : (
                  <div className="grid gap-2 py-2 pr-2 sm:pr-4">
                    {continents.map((continent) => (
                      <button
                        key={continent.code}
                        onClick={() => handleSelectContinent(continent)}
                        className="flex items-center justify-between p-2 sm:p-3 bg-secondary/50 hover:bg-secondary rounded-lg text-left transition-colors"
                        aria-label={`Select ${continent.name} continent with ${continent.city_count.toLocaleString()} cities`}
                      >
                        <div className="flex items-center gap-2 sm:gap-3 min-w-0">
                          <Mountain className="w-4 h-4 sm:w-5 sm:h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                          <div className="min-w-0">
                            <div className="font-medium text-sm sm:text-base truncate">{continent.name}</div>
                            <div className="text-xs sm:text-sm text-muted-foreground">{continent.city_count.toLocaleString()} cities</div>
                          </div>
                        </div>
                        <ChevronRight className="w-4 h-4 sm:w-5 sm:h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                      </button>
                    ))}
                  </div>
                )
              )}

              {/* Country Selection */}
              {selectedContinent && !selectedCountry && (
                loadingCountries ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-primary animate-spin" />
                  </div>
                ) : countries.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground">
                    No countries found in this continent.
                  </div>
                ) : (
                  <div className="grid gap-2 py-2 pr-2 sm:pr-4">
                    {countries.map((country) => (
                      <button
                        key={country.code}
                        onClick={() => handleSelectCountry(country)}
                        className="flex items-center justify-between p-2 sm:p-3 bg-secondary/50 hover:bg-secondary rounded-lg text-left transition-colors"
                        aria-label={`Select ${country.name} with ${country.city_count.toLocaleString()} cities`}
                      >
                        <div className="flex items-center gap-2 sm:gap-3 min-w-0">
                          <Globe className="w-4 h-4 sm:w-5 sm:h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                          <div className="min-w-0">
                            <div className="font-medium text-sm sm:text-base truncate">{country.name}</div>
                            <div className="text-xs sm:text-sm text-muted-foreground">{country.city_count.toLocaleString()} cities</div>
                          </div>
                        </div>
                        <ChevronRight className="w-4 h-4 sm:w-5 sm:h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                      </button>
                    ))}
                  </div>
                )
              )}

              {/* Region Selection */}
              {selectedCountry && !selectedRegion && regions.length > 0 && (
                loadingRegions ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="w-6 h-6 text-primary animate-spin" />
                  </div>
                ) : (
                  <div className="grid gap-2 py-2 pr-4">
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
                              {region.type && `${region.type} • `}{region.city_count.toLocaleString()} cities
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
                    <Loader2 className="w-6 h-6 text-primary animate-spin" />
                  </div>
                ) : cities.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground">
                    No cities found in this area.
                  </div>
                ) : (
                  <div className="grid gap-2 py-2 pr-4">
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
            </ScrollArea>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}
