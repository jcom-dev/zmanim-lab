import type { CoverageSelection } from '@/components/shared/CoverageSelector';

export interface MapSelection {
  /** ISO country code (ISO 3166-1 alpha-2 or numeric) */
  code: string;
  /** Display name of the country */
  name: string;
}

export interface CoverageMapViewProps {
  /** Currently selected regions on the map */
  selectedRegions: MapSelection[];
  /** Callback when selection changes */
  onSelectionChange: (regions: MapSelection[]) => void;
  /** Existing coverage to highlight (amber) */
  existingCoverage?: string[];
  /** Initial zoom center coordinates [lng, lat] */
  initialCenter?: [number, number];
  /** Initial zoom level (1 = world, 4 = country) */
  initialZoom?: number;
  /** Height of the map container */
  height?: string | number;
  /** Whether the map is in view-only mode */
  viewOnly?: boolean;
}

export interface CoverageMapDialogProps {
  /** Whether the dialog is open */
  open: boolean;
  /** Callback when dialog open state changes */
  onOpenChange: (open: boolean) => void;
  /** Existing coverage country codes to highlight */
  existingCoverage?: string[];
  /** Callback when user confirms selection */
  onConfirm: (selections: CoverageSelection[]) => void;
}

export interface CountryData {
  id: string;
  name: string;
  iso_a2?: string;
  iso_a3?: string;
}

export interface MapThemeColors {
  bg: string;
  land: string;
  borders: string;
  water: string;
  existingFill: string;
  existingStroke: string;
  selectedFill: string;
  selectedStroke: string;
  hoverFill: string;
  hoverStroke: string;
}
