// Formula builder state and types

export type MethodType = 'solar' | 'fixed' | 'proportional' | null;
export type SolarDirection = 'before_sunrise' | 'after_sunset';
export type OffsetDirection = 'before' | 'after';
export type ShaosBase = 'gra' | 'mga' | 'custom';

export interface FormulaBuilderState {
  // Base time selection
  baseTime: string;

  // Selected method
  method: MethodType;

  // Solar angle parameters
  solarDegrees: number;
  solarDirection: SolarDirection;

  // Fixed offset parameters
  offsetMinutes: number;
  offsetDirection: OffsetDirection;
  offsetBase: string;

  // Proportional hours parameters
  shaosHours: number;
  shaosBase: ShaosBase;
  customStart?: string;
  customEnd?: string;

  // Derived state
  generatedFormula: string;
  validationErrors: string[];
  isValid: boolean;
}

export const initialState: FormulaBuilderState = {
  baseTime: 'sunrise',
  method: null,
  solarDegrees: 16.1,
  solarDirection: 'before_sunrise',
  offsetMinutes: 72,
  offsetDirection: 'before',
  offsetBase: 'sunrise',
  shaosHours: 3,
  shaosBase: 'gra',
  generatedFormula: 'sunrise',
  validationErrors: [],
  isValid: true,
};

// Base time primitives organized by category
export const baseTimeOptions = [
  {
    label: 'Dawn',
    options: [
      { value: 'alos_hashachar', label: 'Alos HaShachar', description: 'Dawn (72 min before sunrise)' },
      { value: 'misheyakir', label: 'Misheyakir', description: 'Earliest tallis/tefillin' },
    ],
  },
  {
    label: 'Day',
    options: [
      { value: 'sunrise', label: 'Sunrise', description: 'Netz HaChama' },
      { value: 'solar_noon', label: 'Solar Noon', description: 'Chatzos HaYom' },
    ],
  },
  {
    label: 'Dusk',
    options: [
      { value: 'sunset', label: 'Sunset', description: 'Shkias HaChama' },
      { value: 'bein_hashmashos', label: 'Bein HaShmashos', description: 'Between the suns' },
    ],
  },
  {
    label: 'Night',
    options: [
      { value: 'tzeis_hakochavim', label: 'Tzeis HaKochavim', description: 'Nightfall (stars visible)' },
      { value: 'midnight', label: 'Midnight', description: 'Chatzos HaLailah' },
    ],
  },
];

// Common solar angle presets
export const solarAnglePresets = [
  { value: 16.1, label: '16.1°', description: 'Standard dawn/dusk' },
  { value: 18, label: '18°', description: 'Astronomical twilight' },
  { value: 19.8, label: '19.8°', description: '90 minute equivalent' },
  { value: 26, label: '26°', description: 'R\' Tam (72 equinox minutes)' },
];

// Generate DSL formula from state
export function generateFormula(state: FormulaBuilderState): string {
  if (!state.method) {
    return state.baseTime;
  }

  switch (state.method) {
    case 'solar':
      return `solar(${state.solarDegrees}, ${state.solarDirection})`;

    case 'fixed': {
      const op = state.offsetDirection === 'before' ? '-' : '+';
      return `${state.offsetBase} ${op} ${state.offsetMinutes}min`;
    }

    case 'proportional':
      if (state.shaosBase === 'custom' && state.customStart && state.customEnd) {
        return `shaos(${state.shaosHours}, custom(@${state.customStart}, @${state.customEnd}))`;
      }
      return `shaos(${state.shaosHours}, ${state.shaosBase})`;

    default:
      return state.baseTime;
  }
}
