import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { OnboardingState, CoverageSelection } from '../OnboardingWizard';

interface CoverageSetupStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

// Popular cities for suggestions
const POPULAR_CITIES = [
  { id: 'jerusalem', name: 'Jerusalem', nameHebrew: 'ירושלים', country: 'Israel' },
  { id: 'new-york', name: 'New York', nameHebrew: 'ניו יורק', country: 'USA' },
  { id: 'los-angeles', name: 'Los Angeles', nameHebrew: 'לוס אנג\'לס', country: 'USA' },
  { id: 'london', name: 'London', nameHebrew: 'לונדון', country: 'UK' },
  { id: 'tel-aviv', name: 'Tel Aviv', nameHebrew: 'תל אביב', country: 'Israel' },
  { id: 'miami', name: 'Miami', nameHebrew: 'מיאמי', country: 'USA' },
];

export function CoverageSetupStep({ state, onUpdate, onNext, onBack }: CoverageSetupStepProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCities, setSelectedCities] = useState<CoverageSelection[]>(
    state.data.coverage || []
  );

  const addCity = (city: typeof POPULAR_CITIES[0]) => {
    if (!selectedCities.find((c) => c.id === city.id)) {
      const newSelection: CoverageSelection = {
        type: 'city',
        id: city.id,
        name: city.name,
      };
      const updated = [...selectedCities, newSelection];
      setSelectedCities(updated);
      onUpdate({ coverage: updated });
    }
  };

  const removeCity = (cityId: string) => {
    const updated = selectedCities.filter((c) => c.id !== cityId);
    setSelectedCities(updated);
    onUpdate({ coverage: updated });
  };

  const filteredCities = POPULAR_CITIES.filter(
    (city) =>
      city.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      city.nameHebrew.includes(searchQuery)
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Set Your Coverage</h2>
        <p className="text-muted-foreground">
          Choose the cities where your zmanim will be available. You can add more later.
        </p>
      </div>

      {/* Selected cities */}
      {selectedCities.length > 0 && (
        <div className="space-y-2">
          <label className="text-sm font-medium">Selected Cities:</label>
          <div className="flex flex-wrap gap-2">
            {selectedCities.map((city) => (
              <span
                key={city.id}
                className="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-primary/10 text-primary text-sm"
              >
                {city.name}
                <button
                  type="button"
                  onClick={() => removeCity(city.id)}
                  className="ml-1 hover:text-red-500"
                >
                  <XIcon className="w-4 h-4" />
                </button>
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Search */}
      <div>
        <label className="text-sm font-medium">Search for a city:</label>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Type a city name..."
          className="w-full mt-1 px-3 py-2 border rounded-lg"
        />
      </div>

      {/* City suggestions */}
      <div className="space-y-2">
        <label className="text-sm font-medium">Popular cities:</label>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
          {filteredCities.map((city) => {
            const isSelected = selectedCities.some((c) => c.id === city.id);
            return (
              <button
                key={city.id}
                type="button"
                onClick={() => addCity(city)}
                disabled={isSelected}
                className={`p-3 rounded-lg border text-left transition-colors ${
                  isSelected
                    ? 'bg-primary/10 border-primary cursor-default'
                    : 'hover:border-primary hover:bg-muted'
                }`}
              >
                <div className="font-medium">{city.name}</div>
                <div className="text-xs text-muted-foreground">
                  {city.country} · <span dir="rtl">{city.nameHebrew}</span>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Note about adding more */}
      <p className="text-sm text-muted-foreground text-center">
        You can add more cities and regions from your dashboard at any time.
      </p>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button onClick={onNext} disabled={selectedCities.length === 0}>
          Continue
        </Button>
      </div>
    </div>
  );
}

function XIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M18 6 6 18M6 6l12 12" />
    </svg>
  );
}
