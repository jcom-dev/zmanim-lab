'use client';

import { memo, useCallback, useState, useMemo } from 'react';
import {
  ComposableMap,
  Geographies,
  Geography,
  ZoomableGroup,
  type GeographyType,
} from 'react-simple-maps';
import { useMapTheme } from './hooks/useMapTheme';
import { useMapZoom } from './hooks/useMapZoom';
import type { CoverageMapViewProps, MapSelection } from './types';
import { cn } from '@/lib/utils';

const GEO_URL = '/geo/world-countries-110m.json';

// ISO numeric to ISO alpha-2 mapping for common countries
// react-simple-maps TopoJSON uses numeric IDs
const ISO_NUMERIC_TO_ALPHA2: Record<string, string> = {
  '004': 'AF', '008': 'AL', '012': 'DZ', '020': 'AD', '024': 'AO',
  '028': 'AG', '032': 'AR', '036': 'AU', '040': 'AT', '044': 'BS',
  '048': 'BH', '050': 'BD', '051': 'AM', '052': 'BB', '056': 'BE',
  '064': 'BT', '068': 'BO', '070': 'BA', '072': 'BW', '076': 'BR',
  '084': 'BZ', '090': 'SB', '096': 'BN', '100': 'BG', '104': 'MM',
  '108': 'BI', '112': 'BY', '116': 'KH', '120': 'CM', '124': 'CA',
  '140': 'CF', '144': 'LK', '148': 'TD', '152': 'CL', '156': 'CN',
  '158': 'TW', '170': 'CO', '178': 'CG', '180': 'CD', '188': 'CR',
  '191': 'HR', '192': 'CU', '196': 'CY', '203': 'CZ', '204': 'BJ',
  '208': 'DK', '214': 'DO', '218': 'EC', '222': 'SV', '226': 'GQ',
  '231': 'ET', '232': 'ER', '233': 'EE', '238': 'FK', '242': 'FJ',
  '246': 'FI', '250': 'FR', '260': 'TF', '262': 'DJ', '266': 'GA',
  '268': 'GE', '270': 'GM', '275': 'PS', '276': 'DE', '288': 'GH',
  '300': 'GR', '304': 'GL', '320': 'GT', '324': 'GN', '328': 'GY',
  '332': 'HT', '340': 'HN', '348': 'HU', '352': 'IS', '356': 'IN',
  '360': 'ID', '364': 'IR', '368': 'IQ', '372': 'IE', '376': 'IL',
  '380': 'IT', '384': 'CI', '388': 'JM', '392': 'JP', '398': 'KZ',
  '400': 'JO', '404': 'KE', '408': 'KP', '410': 'KR', '414': 'KW',
  '417': 'KG', '418': 'LA', '422': 'LB', '426': 'LS', '428': 'LV',
  '430': 'LR', '434': 'LY', '440': 'LT', '442': 'LU', '450': 'MG',
  '454': 'MW', '458': 'MY', '466': 'ML', '478': 'MR', '484': 'MX',
  '496': 'MN', '498': 'MD', '499': 'ME', '504': 'MA', '508': 'MZ',
  '512': 'OM', '516': 'NA', '524': 'NP', '528': 'NL', '540': 'NC',
  '548': 'VU', '554': 'NZ', '558': 'NI', '562': 'NE', '566': 'NG',
  '578': 'NO', '586': 'PK', '591': 'PA', '598': 'PG', '600': 'PY',
  '604': 'PE', '608': 'PH', '616': 'PL', '620': 'PT', '624': 'GW',
  '626': 'TL', '630': 'PR', '634': 'QA', '642': 'RO', '643': 'RU',
  '646': 'RW', '682': 'SA', '686': 'SN', '688': 'RS', '694': 'SL',
  '702': 'SG', '703': 'SK', '704': 'VN', '705': 'SI', '706': 'SO',
  '710': 'ZA', '716': 'ZW', '724': 'ES', '728': 'SS', '729': 'SD',
  '732': 'EH', '740': 'SR', '748': 'SZ', '752': 'SE', '756': 'CH',
  '760': 'SY', '762': 'TJ', '764': 'TH', '768': 'TG', '780': 'TT',
  '784': 'AE', '788': 'TN', '792': 'TR', '795': 'TM', '800': 'UG',
  '804': 'UA', '807': 'MK', '818': 'EG', '826': 'GB', '834': 'TZ',
  '840': 'US', '854': 'BF', '858': 'UY', '860': 'UZ', '862': 'VE',
  '887': 'YE', '894': 'ZM',
};

function getIsoAlpha2(geoId: string | number): string {
  const id = String(geoId).padStart(3, '0');
  return ISO_NUMERIC_TO_ALPHA2[id] || id;
}

/**
 * Interactive world map for selecting coverage regions.
 * Features smooth zoom animations, theme-aware styling, and multi-select.
 */
export const CoverageMapView = memo(function CoverageMapView({
  selectedRegions,
  onSelectionChange,
  existingCoverage = [],
  initialCenter = [0, 20],
  initialZoom = 1,
  height = '100%',
  viewOnly = false,
}: CoverageMapViewProps) {
  const colors = useMapTheme();
  const [hoveredRegion, setHoveredRegion] = useState<string | null>(null);
  const [hoveredName, setHoveredName] = useState<string | null>(null);

  const {
    center,
    zoom,
    zoomIn,
    zoomOut,
    reset,
    onMoveEnd,
    canZoomIn,
    canZoomOut,
  } = useMapZoom({
    initialCenter,
    initialZoom,
    minZoom: 1,
    maxZoom: 8,
  });

  // Convert existingCoverage to Set for O(1) lookup
  const existingSet = useMemo(
    () => new Set(existingCoverage.map((c) => c.toUpperCase())),
    [existingCoverage]
  );

  const isSelected = useCallback(
    (code: string) => selectedRegions.some((r) => r.code.toUpperCase() === code.toUpperCase()),
    [selectedRegions]
  );

  const isExisting = useCallback(
    (code: string) => existingSet.has(code.toUpperCase()),
    [existingSet]
  );

  const handleClick = useCallback(
    (geo: GeographyType) => {
      if (viewOnly) return;

      const numericId = geo.id;
      const alpha2 = numericId ? getIsoAlpha2(numericId) : null;
      const name = geo.properties?.name || 'Unknown';

      if (!alpha2) return;

      const region: MapSelection = { code: alpha2, name };
      const exists = isSelected(alpha2);

      if (exists) {
        onSelectionChange(selectedRegions.filter((r) => r.code.toUpperCase() !== alpha2.toUpperCase()));
      } else {
        onSelectionChange([...selectedRegions, region]);
      }
    },
    [viewOnly, isSelected, selectedRegions, onSelectionChange]
  );

  const handleMouseEnter = useCallback((geo: GeographyType) => {
    const numericId = geo.id;
    const alpha2 = numericId ? getIsoAlpha2(numericId) : null;
    if (alpha2) {
      setHoveredRegion(alpha2);
      setHoveredName(geo.properties?.name || null);
    }
  }, []);

  const handleMouseLeave = useCallback(() => {
    setHoveredRegion(null);
    setHoveredName(null);
  }, []);

  const getRegionStyle = useCallback(
    (geo: GeographyType) => {
      const numericId = geo.id;
      const alpha2 = numericId ? getIsoAlpha2(numericId) : null;
      if (!alpha2) return {};

      const existing = isExisting(alpha2);
      const selected = isSelected(alpha2);
      const hovered = hoveredRegion === alpha2;

      // Priority: selected > existing > hover > default
      let fill = colors.land;
      let stroke = colors.borders;
      let strokeWidth = 0.5;

      if (existing && !selected) {
        fill = colors.existingFill;
        stroke = colors.existingStroke;
        strokeWidth = 1;
      }

      if (selected) {
        fill = colors.selectedFill;
        stroke = colors.selectedStroke;
        strokeWidth = 1.5;
      }

      if (hovered && !viewOnly) {
        fill = selected ? colors.selectedFill : colors.hoverFill;
        stroke = selected ? colors.selectedStroke : colors.hoverStroke;
        strokeWidth = 2;
      }

      return {
        default: {
          fill,
          stroke,
          strokeWidth,
          outline: 'none',
          transition: 'all 0.2s ease-out',
          cursor: viewOnly ? 'default' : 'pointer',
        },
        hover: {
          fill: selected ? colors.selectedFill : colors.hoverFill,
          stroke: selected ? colors.selectedStroke : colors.hoverStroke,
          strokeWidth: 2,
          outline: 'none',
          cursor: viewOnly ? 'default' : 'pointer',
        },
        pressed: {
          fill: colors.selectedFill,
          stroke: colors.selectedStroke,
          strokeWidth: 2,
          outline: 'none',
        },
      };
    },
    [colors, isExisting, isSelected, hoveredRegion, viewOnly]
  );

  return (
    <div
      className="relative w-full overflow-hidden rounded-lg"
      style={{ height, backgroundColor: colors.bg }}
    >
      {/* Map Container */}
      <ComposableMap
        projection="geoMercator"
        projectionConfig={{
          scale: 140,
          center: [0, 20],
        }}
        style={{ width: '100%', height: '100%' }}
      >
        <ZoomableGroup
          center={center}
          zoom={zoom}
          onMoveEnd={onMoveEnd}
          minZoom={1}
          maxZoom={8}
        >
          <Geographies geography={GEO_URL}>
            {({ geographies }) =>
              geographies.map((geo) => (
                <Geography
                  key={geo.rsmKey}
                  geography={geo}
                  onClick={() => handleClick(geo)}
                  onMouseEnter={() => handleMouseEnter(geo)}
                  onMouseLeave={handleMouseLeave}
                  style={getRegionStyle(geo)}
                />
              ))
            }
          </Geographies>
        </ZoomableGroup>
      </ComposableMap>

      {/* Hover Tooltip */}
      {hoveredName && !viewOnly && (
        <div
          className={cn(
            'absolute top-4 left-4 px-3 py-2 rounded-lg shadow-lg text-sm font-medium',
            'bg-card/95 backdrop-blur-sm border border-border',
            'pointer-events-none animate-in fade-in-0 zoom-in-95 duration-150'
          )}
        >
          <span className="text-foreground">{hoveredName}</span>
          {hoveredRegion && (
            <span className="ml-2 text-xs text-muted-foreground">
              ({hoveredRegion})
            </span>
          )}
        </div>
      )}

      {/* Zoom Controls */}
      <div className="absolute right-4 top-4 flex flex-col gap-1">
        <button
          onClick={zoomIn}
          disabled={!canZoomIn}
          className={cn(
            'w-8 h-8 rounded-md flex items-center justify-center',
            'bg-card/90 backdrop-blur-sm border border-border shadow-sm',
            'text-foreground hover:bg-accent transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed'
          )}
          aria-label="Zoom in"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button
          onClick={zoomOut}
          disabled={!canZoomOut}
          className={cn(
            'w-8 h-8 rounded-md flex items-center justify-center',
            'bg-card/90 backdrop-blur-sm border border-border shadow-sm',
            'text-foreground hover:bg-accent transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed'
          )}
          aria-label="Zoom out"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
          </svg>
        </button>
        <button
          onClick={reset}
          className={cn(
            'w-8 h-8 rounded-md flex items-center justify-center',
            'bg-card/90 backdrop-blur-sm border border-border shadow-sm',
            'text-foreground hover:bg-accent transition-colors'
          )}
          aria-label="Reset view"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
        </button>
      </div>

      {/* Legend */}
      {(existingCoverage.length > 0 || selectedRegions.length > 0) && (
        <div
          className={cn(
            'absolute bottom-4 left-4 px-3 py-2 rounded-lg',
            'bg-card/90 backdrop-blur-sm border border-border shadow-sm',
            'text-xs space-y-1'
          )}
        >
          {existingCoverage.length > 0 && (
            <div className="flex items-center gap-2">
              <span
                className="w-3 h-3 rounded-sm border"
                style={{
                  backgroundColor: colors.existingFill,
                  borderColor: colors.existingStroke,
                }}
              />
              <span className="text-muted-foreground">Existing coverage</span>
            </div>
          )}
          {selectedRegions.length > 0 && (
            <div className="flex items-center gap-2">
              <span
                className="w-3 h-3 rounded-sm border"
                style={{
                  backgroundColor: colors.selectedFill,
                  borderColor: colors.selectedStroke,
                }}
              />
              <span className="text-muted-foreground">New selection</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
});
