'use client';

import { Button } from '@/components/ui/button';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface ZmanListProps {
  zmanim: Record<string, ZmanConfig>;
  onZmanClick: (key: string) => void;
  onZmanRemove: (key: string) => void;
}

// Display names for zmanim
const ZMAN_DISPLAY_NAMES: Record<string, string> = {
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

// Standard order for zmanim
const ZMAN_ORDER = [
  'alos_hashachar',
  'misheyakir',
  'sunrise',
  'sof_zman_shma_gra',
  'sof_zman_shma_mga',
  'sof_zman_tefilla_gra',
  'sof_zman_tefilla_mga',
  'chatzos',
  'mincha_gedola',
  'mincha_ketana',
  'plag_hamincha',
  'sunset',
  'tzeis_hakochavim',
  'tzeis_72',
];

// Method display names
const METHOD_DISPLAY_NAMES: Record<string, string> = {
  sunrise: 'Sunrise',
  sunset: 'Sunset',
  solar_angle: 'Solar Angle',
  fixed_minutes: 'Fixed Minutes',
  proportional: 'Proportional Hours',
  midpoint: 'Midpoint',
};

function getMethodDescription(config: ZmanConfig): string {
  const method = config.method;
  const params = config.params;

  switch (method) {
    case 'sunrise':
      return 'Standard sunrise';
    case 'sunset':
      return 'Standard sunset';
    case 'solar_angle':
      return `${params.degrees || 0}° below horizon`;
    case 'fixed_minutes': {
      const minutes = params.minutes as number;
      const from = params.from as string;
      const sign = minutes >= 0 ? 'after' : 'before';
      return `${Math.abs(minutes)} min ${sign} ${from}`;
    }
    case 'proportional': {
      const hours = params.hours as number;
      const base = params.base as string;
      return `${hours} hours (${base.toUpperCase()})`;
    }
    case 'midpoint': {
      const start = params.start as string;
      const end = params.end as string;
      return `Midpoint: ${start} - ${end}`;
    }
    default:
      return METHOD_DISPLAY_NAMES[method] || method;
  }
}

export function ZmanList({ zmanim, onZmanClick, onZmanRemove }: ZmanListProps) {
  // Sort zmanim by standard order
  const sortedKeys = Object.keys(zmanim).sort((a, b) => {
    const indexA = ZMAN_ORDER.indexOf(a);
    const indexB = ZMAN_ORDER.indexOf(b);
    if (indexA === -1 && indexB === -1) return a.localeCompare(b);
    if (indexA === -1) return 1;
    if (indexB === -1) return -1;
    return indexA - indexB;
  });

  if (sortedKeys.length === 0) {
    return (
      <div className="text-center py-8 text-slate-400">
        <p>No zmanim configured. Select a template above to get started.</p>
      </div>
    );
  }

  return (
    <div className="space-y-2" data-testid="zman-list">
      {sortedKeys.map((key) => {
        const config = zmanim[key];
        const displayName = ZMAN_DISPLAY_NAMES[key] || key;
        const description = getMethodDescription(config);

        return (
          <div
            key={key}
            className="flex items-center justify-between p-3 bg-slate-800 rounded-lg hover:bg-slate-700 cursor-pointer transition-colors"
            onClick={() => onZmanClick(key)}
            data-testid={`zman-item-${key}`}
          >
            <div className="flex-1">
              <div className="font-medium text-white">{displayName}</div>
              <div className="text-sm text-slate-400">{description}</div>
            </div>
            <div className="flex items-center gap-2">
              <span className="px-2 py-1 bg-slate-700 rounded text-xs text-slate-300">
                {METHOD_DISPLAY_NAMES[config.method] || config.method}
              </span>
              <Button
                variant="ghost"
                size="sm"
                className="text-red-400 hover:text-red-300 hover:bg-red-900/20"
                onClick={(e) => {
                  e.stopPropagation();
                  onZmanRemove(key);
                }}
              >
                Remove
              </Button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
