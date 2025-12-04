'use client';

import { memo, useCallback, useState, useRef, useMemo, forwardRef, useImperativeHandle, useEffect } from 'react';
import MapGL, {
  NavigationControl,
  Source,
  Layer,
  MapRef,
  MapLayerMouseEvent,
} from 'react-map-gl/maplibre';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useTheme } from 'next-themes';
import { feature } from 'topojson-client';
import type { Topology, GeometryCollection } from 'topojson-specification';
import { cn } from '@/lib/utils';
import type { CoverageMapViewProps, MapSelection } from './types';

// ISO numeric to ISO alpha-2 mapping for common countries
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

// Country name mapping for ISO codes
const COUNTRY_NAMES: Record<string, string> = {
  US: 'United States', GB: 'United Kingdom', CA: 'Canada', AU: 'Australia',
  IL: 'Israel', FR: 'France', DE: 'Germany', IT: 'Italy', ES: 'Spain',
  NL: 'Netherlands', BE: 'Belgium', CH: 'Switzerland', AT: 'Austria',
  SE: 'Sweden', NO: 'Norway', DK: 'Denmark', FI: 'Finland', PL: 'Poland',
  CZ: 'Czech Republic', HU: 'Hungary', RO: 'Romania', BG: 'Bulgaria',
  GR: 'Greece', PT: 'Portugal', IE: 'Ireland', NZ: 'New Zealand',
  ZA: 'South Africa', BR: 'Brazil', AR: 'Argentina', MX: 'Mexico',
  JP: 'Japan', KR: 'South Korea', CN: 'China', IN: 'India', RU: 'Russia',
  TR: 'Turkey', SA: 'Saudi Arabia', AE: 'United Arab Emirates', EG: 'Egypt',
  MA: 'Morocco', NG: 'Nigeria', KE: 'Kenya', TH: 'Thailand', VN: 'Vietnam',
  ID: 'Indonesia', MY: 'Malaysia', SG: 'Singapore', PH: 'Philippines',
};

function getIsoAlpha2(numericId: string | number): string {
  const id = String(numericId).padStart(3, '0');
  return ISO_NUMERIC_TO_ALPHA2[id] || id;
}

// Pre-built map style URLs (CORS-friendly)
const MAP_STYLES = {
  light: 'https://tiles.openfreemap.org/styles/liberty',
  dark: 'https://tiles.openfreemap.org/styles/dark',
};

function getMapStyleUrl(isDark: boolean): string {
  return isDark ? MAP_STYLES.dark : MAP_STYLES.light;
}

// Selection colors
const SELECTION_COLORS = {
  existing: { fill: 'rgba(245, 158, 11, 0.3)', stroke: '#f59e0b' },
  selected: { fill: 'rgba(34, 197, 94, 0.4)', stroke: '#22c55e' },
  hover: { fill: 'rgba(59, 130, 246, 0.3)', stroke: '#3b82f6' },
  default: { fill: 'rgba(100, 116, 139, 0.1)', stroke: 'rgba(100, 116, 139, 0.3)' },
};

interface HoverInfo {
  code: string;
  name: string;
  x: number;
  y: number;
}

// GeoJSON FeatureCollection type
interface CountryFeature {
  type: 'Feature';
  id: string;
  properties: { name: string; iso_a2?: string };
  geometry: GeoJSON.Geometry;
}

interface CountryCollection {
  type: 'FeatureCollection';
  features: CountryFeature[];
}

/**
 * Interactive map using MapLibre GL for coverage region selection.
 * Features smooth WebGL rendering and premium styling.
 */
export const CoverageMapViewGL = memo(
  forwardRef<MapRef, CoverageMapViewProps>(function CoverageMapViewGL(
    {
      selectedRegions,
      onSelectionChange,
      existingCoverage = [],
      initialCenter = [0, 20],
      initialZoom = 1.5,
      height = '100%',
      viewOnly = false,
    },
    ref
  ) {
    const { resolvedTheme } = useTheme();
    const isDark = resolvedTheme === 'dark';
    const mapRef = useRef<MapRef>(null);
    const [hoverInfo, setHoverInfo] = useState<HoverInfo | null>(null);
    const [hoveredCountry, setHoveredCountry] = useState<string | null>(null);
    const [currentZoom, setCurrentZoom] = useState(initialZoom);
    const [countriesGeoJSON, setCountriesGeoJSON] = useState<CountryCollection | null>(null);
    const [mapLoaded, setMapLoaded] = useState(false);

    // Expose the map ref to parent components
    useImperativeHandle(ref, () => mapRef.current as MapRef);

    // Load GeoJSON countries data
    useEffect(() => {
      fetch('/geo/world-countries-110m.json')
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((topoData: Topology<{ countries: GeometryCollection }>) => {
          if (!topoData.objects?.countries) {
            throw new Error('Invalid TopoJSON: missing countries object');
          }

          // Convert TopoJSON to GeoJSON
          const geojson = feature(
            topoData,
            topoData.objects.countries
          ) as unknown as CountryCollection;

          // Add ISO alpha-2 codes to features (ID can be number or string)
          geojson.features = geojson.features.map((f) => {
            const numericId = String(f.id);
            const alpha2 = getIsoAlpha2(numericId);
            return {
              ...f,
              properties: {
                ...f.properties,
                iso_a2: alpha2,
              },
            };
          });

          console.log(`Loaded ${geojson.features.length} countries`);
          setCountriesGeoJSON(geojson);
        })
        .catch((err) => console.error('Failed to load countries GeoJSON:', err));
    }, []);

    const mapStyleUrl = useMemo(() => getMapStyleUrl(isDark), [isDark]);

    const existingSet = useMemo(
      () => new Set(existingCoverage.map((c) => c.toUpperCase())),
      [existingCoverage]
    );

    const selectedSet = useMemo(
      () => new Set(selectedRegions.map((r) => r.code.toUpperCase())),
      [selectedRegions]
    );

    // Handle country click for selection
    const handleClick = useCallback(
      (event: MapLayerMouseEvent) => {
        if (viewOnly) return;

        const features = event.features;
        if (!features?.length) return;

        const feature = features[0];
        const props = feature.properties;
        const countryCode = (props?.iso_a2 || '').toUpperCase();
        const countryName = props?.name || COUNTRY_NAMES[countryCode] || 'Unknown';

        if (!countryCode) return;

        const region: MapSelection = { code: countryCode, name: countryName };
        const isCurrentlySelected = selectedSet.has(countryCode);

        if (isCurrentlySelected) {
          onSelectionChange(selectedRegions.filter((r) => r.code.toUpperCase() !== countryCode));
        } else {
          onSelectionChange([...selectedRegions, region]);
        }
      },
      [viewOnly, selectedRegions, onSelectionChange, selectedSet]
    );

    // Handle hover for tooltip
    const handleMouseMove = useCallback(
      (event: MapLayerMouseEvent) => {
        if (viewOnly) return;

        const features = event.features;
        if (!features?.length) {
          setHoverInfo(null);
          setHoveredCountry(null);
          return;
        }

        const feature = features[0];
        const props = feature.properties;
        const code = (props?.iso_a2 || '').toUpperCase();
        const name = props?.name || COUNTRY_NAMES[code] || 'Unknown';

        if (code) {
          setHoveredCountry(code);
          setHoverInfo({ code, name, x: event.point.x, y: event.point.y });
        }
      },
      [viewOnly]
    );

    const handleMouseLeave = useCallback(() => {
      setHoverInfo(null);
      setHoveredCountry(null);
    }, []);

    const handleZoom = useCallback(() => {
      if (mapRef.current) {
        setCurrentZoom(mapRef.current.getZoom());
      }
    }, []);

    const handleMapLoad = useCallback(() => {
      console.log('Map loaded');
      setMapLoaded(true);
    }, []);

    // Create fill color expression for countries
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fillColorExpression = useMemo((): any => {
      const conditions: unknown[] = ['case'];

      // Add selected countries (green)
      if (selectedSet.size > 0) {
        conditions.push(['in', ['get', 'iso_a2'], ['literal', Array.from(selectedSet)]]);
        conditions.push(SELECTION_COLORS.selected.fill);
      }

      // Add existing coverage (amber)
      if (existingSet.size > 0) {
        conditions.push(['in', ['get', 'iso_a2'], ['literal', Array.from(existingSet)]]);
        conditions.push(SELECTION_COLORS.existing.fill);
      }

      // Add hovered country (blue)
      if (hoveredCountry && !selectedSet.has(hoveredCountry) && !existingSet.has(hoveredCountry)) {
        conditions.push(['==', ['get', 'iso_a2'], hoveredCountry]);
        conditions.push(SELECTION_COLORS.hover.fill);
      }

      // Default fill
      conditions.push(SELECTION_COLORS.default.fill);

      return conditions;
    }, [selectedSet, existingSet, hoveredCountry]);

    // Create stroke color expression
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const strokeColorExpression = useMemo((): any => {
      const conditions: unknown[] = ['case'];

      if (selectedSet.size > 0) {
        conditions.push(['in', ['get', 'iso_a2'], ['literal', Array.from(selectedSet)]]);
        conditions.push(SELECTION_COLORS.selected.stroke);
      }

      if (existingSet.size > 0) {
        conditions.push(['in', ['get', 'iso_a2'], ['literal', Array.from(existingSet)]]);
        conditions.push(SELECTION_COLORS.existing.stroke);
      }

      if (hoveredCountry) {
        conditions.push(['==', ['get', 'iso_a2'], hoveredCountry]);
        conditions.push(SELECTION_COLORS.hover.stroke);
      }

      conditions.push(SELECTION_COLORS.default.stroke);

      return conditions;
    }, [selectedSet, existingSet, hoveredCountry]);

    return (
      <div className="relative w-full overflow-hidden rounded-lg" style={{ height }}>
        <MapGL
          ref={mapRef}
          initialViewState={{
            longitude: initialCenter[0],
            latitude: initialCenter[1],
            zoom: initialZoom,
          }}
          mapStyle={mapStyleUrl}
          onLoad={handleMapLoad}
          onClick={handleClick}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
          onZoom={handleZoom}
          interactiveLayerIds={viewOnly ? [] : ['countries-fill']}
          style={{ width: '100%', height: '100%' }}
          cursor={viewOnly ? 'default' : hoveredCountry ? 'pointer' : 'grab'}
          attributionControl={false}
        >
          <NavigationControl position="top-right" showCompass={false} />

          {/* Countries overlay layer - rendered above base map */}
          {mapLoaded && countriesGeoJSON && (
            <Source id="countries-source" type="geojson" data={countriesGeoJSON}>
              {/* Fill layer */}
              <Layer
                id="countries-fill"
                type="fill"
                paint={{
                  // eslint-disable-next-line @typescript-eslint/no-explicit-any
                  'fill-color': fillColorExpression as any,
                  'fill-opacity': 0.6,
                }}
              />
              {/* Stroke layer */}
              <Layer
                id="countries-stroke"
                type="line"
                paint={{
                  // eslint-disable-next-line @typescript-eslint/no-explicit-any
                  'line-color': strokeColorExpression as any,
                  'line-width': 1,
                }}
              />
            </Source>
          )}
        </MapGL>

        {/* Premium tooltip */}
        {hoverInfo && !viewOnly && (
          <div
            className={cn(
              'absolute pointer-events-none z-10 px-4 py-3 rounded-xl shadow-2xl',
              'bg-card/95 backdrop-blur-md border border-border/50',
              'animate-in fade-in-0 zoom-in-95 duration-150',
              'transform -translate-x-1/2'
            )}
            style={{ left: hoverInfo.x, top: Math.max(60, hoverInfo.y - 60) }}
          >
            <div className="flex items-center gap-3">
              <div
                className={cn(
                  'w-2.5 h-2.5 rounded-full',
                  existingSet.has(hoverInfo.code)
                    ? 'bg-amber-500'
                    : selectedSet.has(hoverInfo.code)
                      ? 'bg-green-500'
                      : 'bg-blue-500'
                )}
              />
              <div>
                <div className="font-semibold text-foreground tracking-tight">{hoverInfo.name}</div>
                <div className="text-xs text-muted-foreground font-mono">{hoverInfo.code}</div>
              </div>
            </div>
          </div>
        )}

        {/* Zoom level indicator */}
        {process.env.NODE_ENV === 'development' && (
          <div className="absolute bottom-4 right-4 px-2 py-1 text-xs font-mono bg-card/80 rounded text-muted-foreground">
            z: {currentZoom.toFixed(1)}
          </div>
        )}

        {/* Legend */}
        {(existingCoverage.length > 0 || selectedRegions.length > 0) && (
          <div
            className={cn(
              'absolute bottom-4 left-4 px-4 py-3 rounded-xl',
              'bg-card/90 backdrop-blur-md border border-border/50 shadow-lg',
              'text-xs space-y-2'
            )}
          >
            {existingCoverage.length > 0 && (
              <div className="flex items-center gap-3">
                <span
                  className="w-4 h-4 rounded-md border-2"
                  style={{
                    backgroundColor: SELECTION_COLORS.existing.fill,
                    borderColor: SELECTION_COLORS.existing.stroke,
                  }}
                />
                <span className="text-muted-foreground font-medium">Existing coverage</span>
              </div>
            )}
            {selectedRegions.length > 0 && (
              <div className="flex items-center gap-3">
                <span
                  className="w-4 h-4 rounded-md border-2"
                  style={{
                    backgroundColor: SELECTION_COLORS.selected.fill,
                    borderColor: SELECTION_COLORS.selected.stroke,
                  }}
                />
                <span className="text-muted-foreground font-medium">
                  New selection ({selectedRegions.length})
                </span>
              </div>
            )}
          </div>
        )}
      </div>
    );
  })
);

export default CoverageMapViewGL;
