'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useParams, useRouter } from 'next/navigation';
import { MapPin, User, Building, ChevronRight, Loader2, AlertCircle, ArrowLeft } from 'lucide-react';
import Link from 'next/link';
import { API_BASE } from '@/lib/api';

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

interface Publisher {
  id: string;
  name: string;
  organization: string | null;
  description: string | null;
  logo_url: string | null;
  website: string | null;
  priority: number;
  is_verified: boolean;
}

interface CityPublishersResponse {
  city: City;
  publishers: Publisher[];
  has_coverage: boolean;
}

export default function CityPublishersPage() {
  const params = useParams();
  const router = useRouter();
  const cityId = params.cityId as string;

  const [data, setData] = useState<CityPublishersResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (cityId) {
      loadPublishers();
    }
  }, [cityId]);

  const loadPublishers = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch(`${API_BASE}/api/v1/cities/${cityId}/publishers`);
      if (!response.ok) {
        if (response.status === 404) {
          throw new Error('City not found');
        }
        throw new Error('Failed to load publishers');
      }

      const result = await response.json();
      setData(result.data || result);
    } catch (err) {
      console.error('Failed to load publishers:', err);
      setError(err instanceof Error ? err.message : 'Failed to load publishers');
    } finally {
      setLoading(false);
    }
  };

  const handlePublisherSelect = (publisher: Publisher) => {
    // Save selection and navigate to zmanim view
    localStorage.setItem('zmanim_selected_publisher', JSON.stringify(publisher));
    router.push(`/zmanim/${cityId}/${publisher.id}`);
  };

  const handleUseDefault = () => {
    // Navigate with no publisher (default calculation)
    router.push(`/zmanim/${cityId}/default`);
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
              href="/"
              className="inline-flex items-center gap-2 text-blue-400 hover:text-blue-300"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to location selection
            </Link>
          </div>
        </div>
      </main>
    );
  }

  const city = data?.city;
  const publishers = data?.publishers || [];
  const hasCoverage = data?.has_coverage || publishers.length > 0;

  return (
    <main className="min-h-screen bg-background">
      {/* Header */}
      <div className="bg-card border-b border-border">
        <div className="container mx-auto px-4 py-8">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Change location
          </Link>

          <div className="flex items-center gap-3">
            <MapPin className="w-8 h-8 text-blue-400" />
            <div>
              <h1 className="text-2xl font-bold text-foreground">{city?.name}</h1>
              <p className="text-muted-foreground">
                {city?.region && `${city.region}, `}{city?.country}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-8">
        <h2 className="text-xl font-bold text-foreground mb-6">
          {hasCoverage ? 'Select Publisher' : 'No Local Authority'}
        </h2>

        {/* No Coverage Warning */}
        {!hasCoverage && (
          <div className="mb-8 bg-yellow-900/30 border border-yellow-700 rounded-lg p-6">
            <div className="flex items-start gap-4">
              <AlertCircle className="w-6 h-6 text-yellow-600 dark:text-yellow-400 flex-shrink-0 mt-1" />
              <div>
                <h3 className="text-lg font-semibold text-yellow-600 dark:text-yellow-200 mb-2">
                  No Local Authority Covers This Area
                </h3>
                <p className="text-yellow-100/80 mb-4">
                  There is no halachic authority registered for this location yet.
                  You can view default zmanim calculated using standard algorithms,
                  but these are not endorsed by a local rabbi.
                </p>
                <button
                  onClick={handleUseDefault}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-yellow-600 hover:bg-yellow-700 text-foreground rounded-lg transition-colors"
                >
                  View Default Zmanim
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Publisher List */}
        {publishers.length > 0 && (
          <div className="space-y-4">
            {publishers.map((publisher) => (
              <button
                key={publisher.id}
                onClick={() => handlePublisherSelect(publisher)}
                className="w-full flex items-center gap-4 p-6 bg-card border border-border rounded-lg hover:bg-muted hover:border-border transition-colors text-left"
              >
                {/* Logo */}
                <div className="relative w-16 h-16 bg-muted rounded-lg flex items-center justify-center flex-shrink-0">
                  {publisher.logo_url ? (
                    <Image
                      src={publisher.logo_url}
                      alt={publisher.name}
                      fill
                      className="object-cover rounded-lg"
                      unoptimized
                    />
                  ) : (
                    <User className="w-8 h-8 text-muted-foreground" />
                  )}
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-lg font-semibold text-foreground truncate">
                      {publisher.name}
                    </h3>
                    {publisher.is_verified && (
                      <span className="px-2 py-0.5 text-xs bg-green-600 dark:text-green-400 text-foreground rounded">
                        Verified
                      </span>
                    )}
                  </div>
                  {publisher.organization && (
                    <div className="flex items-center gap-2 text-muted-foreground mb-1">
                      <Building className="w-4 h-4" />
                      <span className="truncate">{publisher.organization}</span>
                    </div>
                  )}
                  {publisher.description && (
                    <p className="text-sm text-muted-foreground line-clamp-2">
                      {publisher.description}
                    </p>
                  )}
                </div>

                {/* Arrow */}
                <ChevronRight className="w-6 h-6 text-muted-foreground flex-shrink-0" />
              </button>
            ))}
          </div>
        )}

        {/* Alternative: Use Default */}
        {hasCoverage && (
          <div className="mt-8 pt-8 border-t border-border">
            <button
              onClick={handleUseDefault}
              className="text-muted-foreground hover:text-foreground text-sm"
            >
              Or use default calculations without a specific publisher →
            </button>
          </div>
        )}
      </div>

      {/* Footer */}
      <footer className="mt-auto border-t border-border bg-card/50">
        <div className="container mx-auto px-4 py-8 text-center">
          <p className="text-sm text-muted-foreground">
            Zmanim Lab - Multi-Publisher Prayer Times Platform
          </p>
        </div>
      </footer>
    </main>
  );
}
