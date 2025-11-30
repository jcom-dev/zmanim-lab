import { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MapPin, Search, X, Loader2, Globe, Map } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { OnboardingState, CoverageSelection } from '../OnboardingWizard';

interface CoverageSetupStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

interface City {
  id: string;
  name: string;
  country: string;
  country_code: string;
  region: string | null;
  latitude: number;
  longitude: number;
  timezone: string;
  display_name: string;
}

interface Country {
  code: string;
  name: string;
  city_count: number;
}

interface Region {
  name: string;
  country_code: string;
  country_name: string;
  city_count: number;
}

type CoverageType = 'city' | 'region' | 'country';

// Quick select cities for common locations
const QUICK_SELECT_CITIES = [
  { name: 'Jerusalem', country: 'Israel', countryCode: 'IL' },
  { name: 'New York', country: 'USA', countryCode: 'US' },
  { name: 'Los Angeles', country: 'USA', countryCode: 'US' },
  { name: 'London', country: 'UK', countryCode: 'GB' },
  { name: 'Tel Aviv', country: 'Israel', countryCode: 'IL' },
  { name: 'Miami', country: 'USA', countryCode: 'US' },
];

export function CoverageSetupStep({ state, onUpdate, onNext, onBack }: CoverageSetupStepProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchType, setSearchType] = useState<CoverageType>('city');
  const [cityResults, setCityResults] = useState<City[]>([]);
  const [countryResults, setCountryResults] = useState<Country[]>([]);
  const [regionResults, setRegionResults] = useState<Region[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedItems, setSelectedItems] = useState<CoverageSelection[]>(
    state.data.coverage || []
  );
  const [showDropdown, setShowDropdown] = useState(false);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Search with debounce
  useEffect(() => {
    if (searchQuery.length < 2) {
      setCityResults([]);
      setCountryResults([]);
      setRegionResults([]);
      setShowDropdown(false);
      return;
    }

    const timeoutId = setTimeout(async () => {
      setIsSearching(true);
      setShowDropdown(true);
      const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

      try {
        if (searchType === 'city') {
          const response = await fetch(
            `${apiBase}/api/v1/cities?search=${encodeURIComponent(searchQuery)}&limit=10`
          );
          if (response.ok) {
            const json = await response.json();
            setCityResults(json.data?.cities || json.cities || []);
          }
        } else if (searchType === 'country') {
          const response = await fetch(`${apiBase}/api/v1/countries`);
          if (response.ok) {
            const json = await response.json();
            const countries = json.data?.countries || json.countries || json.data || [];
            // Filter by search query
            const filtered = countries.filter((c: Country) =>
              c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
              c.code.toLowerCase().includes(searchQuery.toLowerCase())
            );
            setCountryResults(filtered.slice(0, 10));
          }
        } else if (searchType === 'region') {
          const response = await fetch(`${apiBase}/api/v1/regions?search=${encodeURIComponent(searchQuery)}&limit=10`);
          if (response.ok) {
            const json = await response.json();
            setRegionResults(json.data?.regions || json.regions || json.data || []);
          }
        }
      } catch (err) {
        console.error('Search failed:', err);
      } finally {
        setIsSearching(false);
      }
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [searchQuery, searchType]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node) &&
        searchInputRef.current &&
        !searchInputRef.current.contains(event.target as Node)
      ) {
        setShowDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const addItem = (item: CoverageSelection) => {
    if (!selectedItems.find((i) => i.id === item.id && i.type === item.type)) {
      const updated = [...selectedItems, item];
      setSelectedItems(updated);
      onUpdate({ coverage: updated });
    }
    setSearchQuery('');
    setCityResults([]);
    setCountryResults([]);
    setRegionResults([]);
    setShowDropdown(false);
  };

  const addCity = (city: City) => {
    addItem({
      type: 'city',
      id: city.id,
      name: city.display_name || `${city.name}, ${city.country}`,
    });
  };

  const addCountry = (country: Country) => {
    addItem({
      type: 'country',
      id: country.code,
      name: country.name,
    });
  };

  const addRegion = (region: Region) => {
    addItem({
      type: 'region',
      id: `${region.country_code}-${region.name}`,
      name: `${region.name}, ${region.country_name}`,
    });
  };

  const addQuickCity = (city: typeof QUICK_SELECT_CITIES[0]) => {
    const cityId = `quick-${city.name.toLowerCase().replace(/\s+/g, '-')}-${city.countryCode}`;
    addItem({
      type: 'city',
      id: cityId,
      name: `${city.name}, ${city.country}`,
    });
  };

  const removeItem = (itemId: string, itemType: CoverageType) => {
    const updated = selectedItems.filter((i) => !(i.id === itemId && i.type === itemType));
    setSelectedItems(updated);
    onUpdate({ coverage: updated });
  };

  const getIcon = (type: CoverageType) => {
    switch (type) {
      case 'country': return <Globe className="w-3 h-3" />;
      case 'region': return <Map className="w-3 h-3" />;
      default: return <MapPin className="w-3 h-3" />;
    }
  };

  const getTypeColor = (type: CoverageType) => {
    switch (type) {
      case 'country': return 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400';
      case 'region': return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400';
      default: return 'bg-primary/10 text-primary';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Set Your Coverage</h2>
        <p className="text-muted-foreground">
          Choose where your zmanim will be available. Add countries, states/regions, or specific cities.
        </p>
      </div>

      {/* Selected items */}
      {selectedItems.length > 0 && (
        <div className="space-y-2">
          <label className="text-sm font-medium">Selected Coverage ({selectedItems.length}):</label>
          <div className="flex flex-wrap gap-2">
            {selectedItems.map((item) => (
              <span
                key={`${item.type}-${item.id}`}
                className={cn(
                  "inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm",
                  getTypeColor(item.type)
                )}
              >
                {getIcon(item.type)}
                {item.name}
                <button
                  type="button"
                  onClick={() => removeItem(item.id, item.type)}
                  className="ml-1 hover:opacity-70 transition-opacity"
                >
                  <X className="w-4 h-4" />
                </button>
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Search type tabs */}
      <div className="space-y-3">
        <label className="text-sm font-medium">Add coverage by:</label>
        <div className="flex gap-2 border-b">
          {[
            { type: 'city' as const, label: 'City', icon: MapPin },
            { type: 'region' as const, label: 'State/Region', icon: Map },
            { type: 'country' as const, label: 'Country', icon: Globe },
          ].map(({ type, label, icon: Icon }) => (
            <button
              key={type}
              type="button"
              onClick={() => {
                setSearchType(type);
                setSearchQuery('');
                setCityResults([]);
                setCountryResults([]);
                setRegionResults([]);
              }}
              className={cn(
                "flex items-center gap-1.5 px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-[2px]",
                searchType === type
                  ? "border-primary text-primary"
                  : "border-transparent text-muted-foreground hover:text-foreground"
              )}
            >
              <Icon className="h-4 w-4" />
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Search input */}
      <div className="relative">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            ref={searchInputRef}
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onFocus={() => searchQuery.length >= 2 && setShowDropdown(true)}
            placeholder={
              searchType === 'city'
                ? "Search cities (e.g., Manchester, Paris...)"
                : searchType === 'region'
                ? "Search states/regions (e.g., California, Ontario...)"
                : "Search countries (e.g., United States, Israel...)"
            }
            className="pl-10 pr-10"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setCityResults([]);
                setCountryResults([]);
                setRegionResults([]);
                setShowDropdown(false);
              }}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        {/* Search results dropdown */}
        {showDropdown && (
          <div
            ref={dropdownRef}
            className="absolute top-full left-0 right-0 mt-1 bg-background border rounded-md shadow-lg z-50 max-h-60 overflow-y-auto"
          >
            {isSearching ? (
              <div className="p-4 text-center text-sm text-muted-foreground">
                <Loader2 className="h-4 w-4 animate-spin mx-auto mb-1" />
                Searching...
              </div>
            ) : searchType === 'city' && cityResults.length > 0 ? (
              <div className="py-1">
                {cityResults.map((city) => {
                  const isSelected = selectedItems.some((i) => i.id === city.id && i.type === 'city');
                  return (
                    <button
                      key={city.id}
                      type="button"
                      onClick={() => !isSelected && addCity(city)}
                      disabled={isSelected}
                      className={cn(
                        "w-full px-3 py-2 text-left text-sm flex items-start gap-2",
                        isSelected ? "bg-muted text-muted-foreground" : "hover:bg-accent"
                      )}
                    >
                      <MapPin className="h-4 w-4 text-muted-foreground shrink-0 mt-0.5" />
                      <div className="flex-1">
                        <div className="font-medium">{city.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {city.region ? `${city.region}, ` : ''}{city.country}
                        </div>
                      </div>
                      {isSelected && <span className="text-xs text-primary">Added</span>}
                    </button>
                  );
                })}
              </div>
            ) : searchType === 'country' && countryResults.length > 0 ? (
              <div className="py-1">
                {countryResults.map((country) => {
                  const isSelected = selectedItems.some((i) => i.id === country.code && i.type === 'country');
                  return (
                    <button
                      key={country.code}
                      type="button"
                      onClick={() => !isSelected && addCountry(country)}
                      disabled={isSelected}
                      className={cn(
                        "w-full px-3 py-2 text-left text-sm flex items-start gap-2",
                        isSelected ? "bg-muted text-muted-foreground" : "hover:bg-accent"
                      )}
                    >
                      <Globe className="h-4 w-4 text-muted-foreground shrink-0 mt-0.5" />
                      <div className="flex-1">
                        <div className="font-medium">{country.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {country.city_count} cities available
                        </div>
                      </div>
                      {isSelected && <span className="text-xs text-primary">Added</span>}
                    </button>
                  );
                })}
              </div>
            ) : searchType === 'region' && regionResults.length > 0 ? (
              <div className="py-1">
                {regionResults.map((region) => {
                  const regionId = `${region.country_code}-${region.name}`;
                  const isSelected = selectedItems.some((i) => i.id === regionId && i.type === 'region');
                  return (
                    <button
                      key={regionId}
                      type="button"
                      onClick={() => !isSelected && addRegion(region)}
                      disabled={isSelected}
                      className={cn(
                        "w-full px-3 py-2 text-left text-sm flex items-start gap-2",
                        isSelected ? "bg-muted text-muted-foreground" : "hover:bg-accent"
                      )}
                    >
                      <Map className="h-4 w-4 text-muted-foreground shrink-0 mt-0.5" />
                      <div className="flex-1">
                        <div className="font-medium">{region.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {region.country_name} · {region.city_count} cities
                        </div>
                      </div>
                      {isSelected && <span className="text-xs text-primary">Added</span>}
                    </button>
                  );
                })}
              </div>
            ) : searchQuery.length >= 2 ? (
              <div className="p-4 text-center text-sm text-muted-foreground">
                No {searchType === 'city' ? 'cities' : searchType === 'region' ? 'regions' : 'countries'} found for "{searchQuery}"
              </div>
            ) : null}
          </div>
        )}
      </div>

      {/* Quick select cities */}
      <div className="space-y-2">
        <label className="text-sm font-medium">Quick add popular cities:</label>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
          {QUICK_SELECT_CITIES.map((city) => {
            const cityId = `quick-${city.name.toLowerCase().replace(/\s+/g, '-')}-${city.countryCode}`;
            const isSelected = selectedItems.some((i) => i.id === cityId);
            return (
              <button
                key={cityId}
                type="button"
                onClick={() => addQuickCity(city)}
                disabled={isSelected}
                className={cn(
                  "p-3 rounded-lg border text-left transition-colors",
                  isSelected
                    ? "bg-primary/10 border-primary cursor-default"
                    : "hover:border-primary hover:bg-muted"
                )}
              >
                <div className="font-medium flex items-center gap-1">
                  <MapPin className="h-3 w-3" />
                  {city.name}
                </div>
                <div className="text-xs text-muted-foreground">
                  {city.country}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Note about adding more */}
      <p className="text-sm text-muted-foreground text-center">
        You can add more coverage areas from your dashboard at any time.
      </p>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button onClick={onNext} disabled={selectedItems.length === 0}>
          Continue
        </Button>
      </div>
    </div>
  );
}
