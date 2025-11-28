'use client';

import { Select } from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import { fixedZmanimOptions } from '../types';

interface FixedZmanFormProps {
  value: string;
  onChange: (value: string) => void;
}

export function FixedZmanForm({
  value,
  onChange,
}: FixedZmanFormProps) {
  return (
    <div className="space-y-4">
      {/* Main selector */}
      <div className="space-y-2" onClick={(e) => e.stopPropagation()}>
        <label className="text-sm font-medium">Astronomical Event</label>
        <Select
          value={value}
          onChange={onChange}
          groups={fixedZmanimOptions}
          placeholder="Select fixed zman..."
        />
        <p className="text-xs text-muted-foreground">
          These are standalone astronomical events calculated from your location and date
        </p>
      </div>

      {/* Quick access buttons */}
      <div className="space-y-2">
        <label className="text-sm text-muted-foreground">Quick select</label>
        <div className="grid grid-cols-2 gap-2">
          {[
            { value: 'sunrise', label: 'Sunrise' },
            { value: 'solar_noon', label: 'Solar Noon' },
            { value: 'sunset', label: 'Sunset' },
            { value: 'midnight', label: 'Midnight' },
          ].map((preset) => (
            <Button
              key={preset.value}
              variant={value === preset.value ? 'default' : 'outline'}
              size="sm"
              onClick={(e) => {
                e.stopPropagation();
                onChange(preset.value);
              }}
            >
              {preset.label}
            </Button>
          ))}
        </div>
      </div>

      {/* Visual indicator */}
      <div className="p-3 bg-muted/50 rounded-lg">
        <p className="text-xs text-muted-foreground">
          <strong>No parameters needed.</strong> Fixed zmanim are calculated directly
          from astronomical algorithms using your location coordinates.
        </p>
      </div>
    </div>
  );
}

export default FixedZmanForm;
