'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { MapPin, ChevronRight, Building2, Globe, Loader2 } from 'lucide-react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

interface Country {
  code: string;
  name: string;
  city_count: number;
}

interface Region {
  name: string;
  type: string;
  city_count: number;
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

// localStorage keys
const STORAGE_KEY_COUNTRY = 'zmanim_selected_country';
const STORAGE_KEY_REGION = 'zmanim_selected_region';
const STORAGE_KEY_CITY = 'zmanim_selected_city';

export default function Home() {
  const router = useRouter();

  // Selection state
  const [selectedCountry, setSelectedCountry] = useState<Country | null>(null);
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const [selectedCity, setSelectedCity] = useState<City | null>(null);

  // Data state
  const [countries, setCountries] = useState<Country[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);

  // Loading state
  const [loadingCountries, setLoadingCountries] = useState(true);
  const [loadingRegions, setLoadingRegions] = useState(false);
  const [loadingCities, setLoadingCities] = useState(false);

  const [error, setError] = useState<string | null>(null);

  // Load countries on mount
  useEffect(() => {
    loadCountries();
    loadSavedSelections();
  }, []);

  const loadSavedSelections = () => {
    try {
      const savedCity = localStorage.getItem(STORAGE_KEY_CITY);
      if (savedCity) {
        const city = JSON.parse(savedCity) as City;
        // If we have a saved city, navigate directly to it
        router.push(`/zmanim/${city.id}`);
      }
    } catch {
      // Invalid stored data, ignore
    }
  };

  const loadCountries = async () => {
    try {
      setLoadingCountries(true);
      setError(null);

      const response = await fetch(`${API_BASE}/api/v1/countries`);
      if (!response.ok) throw new Error('Failed to load countries');

      const data = await response.json();
      setCountries(data.data?.countries || data.countries || []);
    } catch (err) {
      console.error('Failed to load countries:', err);
      setError('Failed to load countries. Please try again.');
    } finally {
      setLoadingCountries(false);
    }
  };

  const loadRegions = useCallback(async (countryCode: string) => {
    try {
      setLoadingRegions(true);
      setError(null);
      setRegions([]);
      setCities([]);

      const response = await fetch(`${API_BASE}/api/v1/regions?country=${countryCode}`);
      if (!response.ok) throw new Error('Failed to load regions');

      const data = await response.json();
      const regionList = data.data?.regions || data.regions || [];
      setRegions(regionList);

      // If no regions, load cities directly
      if (regionList.length === 0) {
        loadCities(countryCode, null);
      }
    } catch (err) {
      console.error('Failed to load regions:', err);
      setError('Failed to load regions. Please try again.');
    } finally {
      setLoadingRegions(false);
    }
  }, []);

  const loadCities = async (countryCode: string, regionName: string | null) => {
    try {
      setLoadingCities(true);
      setError(null);

      let url = `${API_BASE}/api/v1/cities?country=${countryCode}&limit=100`;
      if (regionName) {
        url += `&region=${encodeURIComponent(regionName)}`;
      }

      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to load cities');

      const data = await response.json();
      setCities(data.data?.cities || data.cities || []);
    } catch (err) {
      console.error('Failed to load cities:', err);
      setError('Failed to load cities. Please try again.');
    } finally {
      setLoadingCities(false);
    }
  };

  const handleCountrySelect = (country: Country) => {
    setSelectedCountry(country);
    setSelectedRegion(null);
    setSelectedCity(null);
    localStorage.setItem(STORAGE_KEY_COUNTRY, JSON.stringify(country));
    localStorage.removeItem(STORAGE_KEY_REGION);
    localStorage.removeItem(STORAGE_KEY_CITY);
    loadRegions(country.code);
  };

  const handleRegionSelect = (region: Region) => {
    setSelectedRegion(region);
    setSelectedCity(null);
    localStorage.setItem(STORAGE_KEY_REGION, JSON.stringify(region));
    localStorage.removeItem(STORAGE_KEY_CITY);
    if (selectedCountry) {
      loadCities(selectedCountry.code, region.name);
    }
  };

  const handleCitySelect = (city: City) => {
    setSelectedCity(city);
    localStorage.setItem(STORAGE_KEY_CITY, JSON.stringify(city));
    // Navigate to publisher selection
    router.push(`/zmanim/${city.id}`);
  };

  const handleBack = () => {
    if (selectedCity) {
      setSelectedCity(null);
      localStorage.removeItem(STORAGE_KEY_CITY);
    } else if (selectedRegion) {
      setSelectedRegion(null);
      setCities([]);
      localStorage.removeItem(STORAGE_KEY_REGION);
    } else if (selectedCountry) {
      setSelectedCountry(null);
      setRegions([]);
      setCities([]);
      localStorage.removeItem(STORAGE_KEY_COUNTRY);
    }
  };

  // Determine current step
  const getCurrentStep = () => {
    if (!selectedCountry) return 'country';
    if (regions.length > 0 && !selectedRegion) return 'region';
    if (!selectedCity) return 'city';
    return 'done';
  };

  const step = getCurrentStep();

  return (
    <main className="min-h-screen bg-slate-900">
      {/* Header */}
      <div className="bg-slate-800 border-b border-slate-700">
        <div className="container mx-auto px-4 py-12">
          <div className="text-center max-w-3xl mx-auto">
            <h1 className="text-4xl font-bold text-white mb-3">
              Zmanim Lab
            </h1>
            <p className="text-lg text-slate-400">
              Multi-Publisher Zmanim Platform
            </p>
            <p className="text-slate-500 mt-2">
              Select your location to view prayer times from local authorities
            </p>
          </div>
        </div>
      </div>

      {/* Breadcrumb Navigation */}
      <div className="bg-slate-800/50 border-b border-slate-700">
        <div className="container mx-auto px-4 py-3">
          <div className="flex items-center gap-2 text-sm">
            <button
              onClick={() => {
                setSelectedCountry(null);
                setSelectedRegion(null);
                setSelectedCity(null);
                setRegions([]);
                setCities([]);
              }}
              className={`${!selectedCountry ? 'text-blue-400' : 'text-slate-400 hover:text-white'}`}
            >
              <Globe className="w-4 h-4 inline mr-1" />
              Select Location
            </button>

            {selectedCountry && (
              <>
                <ChevronRight className="w-4 h-4 text-slate-600" />
                <button
                  onClick={() => {
                    setSelectedRegion(null);
                    setSelectedCity(null);
                    setCities([]);
                  }}
                  className={`${!selectedRegion && regions.length > 0 ? 'text-blue-400' : 'text-slate-400 hover:text-white'}`}
                >
                  {selectedCountry.name}
                </button>
              </>
            )}

            {selectedRegion && (
              <>
                <ChevronRight className="w-4 h-4 text-slate-600" />
                <button
                  onClick={() => setSelectedCity(null)}
                  className={`${!selectedCity ? 'text-blue-400' : 'text-slate-400 hover:text-white'}`}
                >
                  {selectedRegion.name}
                </button>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-8">
        {error && (
          <div className="mb-6 bg-red-900/50 border border-red-700 rounded-lg p-4">
            <p className="text-red-200">{error}</p>
          </div>
        )}

        {/* Country Selection */}
        {step === 'country' && (
          <div>
            <h2 className="text-2xl font-bold text-white mb-6">Select Country</h2>

            {loadingCountries ? (
              <div className="flex justify-center py-12">
                <Loader2 className="w-8 h-8 text-blue-400 animate-spin" />
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {countries.map((country) => (
                  <button
                    key={country.code}
                    onClick={() => handleCountrySelect(country)}
                    className="flex items-center justify-between p-4 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 hover:border-slate-600 transition-colors text-left"
                  >
                    <div className="flex items-center gap-3">
                      <Globe className="w-5 h-5 text-slate-400" />
                      <div>
                        <div className="text-white font-medium">{country.name}</div>
                        <div className="text-sm text-slate-500">{country.city_count} cities</div>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-slate-500" />
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Region Selection */}
        {step === 'region' && (
          <div>
            <div className="flex items-center gap-4 mb-6">
              <button
                onClick={handleBack}
                className="text-slate-400 hover:text-white"
              >
                ← Back
              </button>
              <h2 className="text-2xl font-bold text-white">
                Select {regions[0]?.type || 'Region'} in {selectedCountry?.name}
              </h2>
            </div>

            {loadingRegions ? (
              <div className="flex justify-center py-12">
                <Loader2 className="w-8 h-8 text-blue-400 animate-spin" />
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {regions.map((region) => (
                  <button
                    key={region.name}
                    onClick={() => handleRegionSelect(region)}
                    className="flex items-center justify-between p-4 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 hover:border-slate-600 transition-colors text-left"
                  >
                    <div className="flex items-center gap-3">
                      <Building2 className="w-5 h-5 text-slate-400" />
                      <div>
                        <div className="text-white font-medium">{region.name}</div>
                        <div className="text-sm text-slate-500">{region.city_count} cities</div>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-slate-500" />
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* City Selection */}
        {step === 'city' && (
          <div>
            <div className="flex items-center gap-4 mb-6">
              <button
                onClick={handleBack}
                className="text-slate-400 hover:text-white"
              >
                ← Back
              </button>
              <h2 className="text-2xl font-bold text-white">
                Select City {selectedRegion ? `in ${selectedRegion.name}` : `in ${selectedCountry?.name}`}
              </h2>
            </div>

            {loadingCities ? (
              <div className="flex justify-center py-12">
                <Loader2 className="w-8 h-8 text-blue-400 animate-spin" />
              </div>
            ) : cities.length === 0 ? (
              <div className="text-center py-12">
                <p className="text-slate-400">No cities found in this location.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {cities.map((city) => (
                  <button
                    key={city.id}
                    onClick={() => handleCitySelect(city)}
                    className="flex items-center justify-between p-4 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 hover:border-slate-600 transition-colors text-left"
                  >
                    <div className="flex items-center gap-3">
                      <MapPin className="w-5 h-5 text-slate-400" />
                      <div>
                        <div className="text-white font-medium">{city.name}</div>
                        <div className="text-sm text-slate-500">
                          {city.region && `${city.region}, `}{city.country}
                        </div>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-slate-500" />
                  </button>
                ))}
              </div>
            )}
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
            Times are calculated based on astronomical and halachic methods.
            Consult your local rabbi for practical guidance.
          </p>
        </div>
      </footer>
    </main>
  );
}
