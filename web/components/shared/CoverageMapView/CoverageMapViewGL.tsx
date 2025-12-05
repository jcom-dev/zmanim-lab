'use client';

import {
  memo,
  useCallback,
  useState,
  useRef,
  useMemo,
  forwardRef,
  useImperativeHandle,
  useEffect,
} from 'react';
import MapGL, {
  NavigationControl,
  Source,
  Layer,
  MapRef,
  MapLayerMouseEvent,
  Marker,
} from 'react-map-gl/maplibre';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useTheme } from 'next-themes';
import type { FillLayerSpecification, LineLayerSpecification } from 'maplibre-gl';
import { cn } from '@/lib/utils';
import { API_BASE } from '@/lib/api-client';
import type { CoverageMapViewProps, MapSelection } from './types';

// Zoom level thresholds for different selection granularity
const ZOOM_THRESHOLDS = {
  REGION: 4,     // Above this zoom, show region boundaries and allow region selection
  DISTRICT: 6,   // Above this zoom, show district boundaries and allow district selection
  CITY: 8,       // Above this zoom, clicking searches for cities
  MIN_ZOOM: 1,   // Minimum zoom level allowed
};

// Pre-built map style URLs (CORS-friendly)
const MAP_STYLES = {
  light: 'https://tiles.openfreemap.org/styles/liberty',
  dark: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
};

function getMapStyleUrl(isDark: boolean): string {
  return isDark ? MAP_STYLES.dark : MAP_STYLES.light;
}

// Selection colors
const COLORS = {
  existing: { fill: '#f59e0b', stroke: '#f59e0b' },   // Amber
  selected: { fill: '#22c55e', stroke: '#22c55e' },   // Green
};

// GeoJSON types matching server response
interface CountryFeature {
  type: 'Feature';
  id: number;
  properties: {
    id: number;
    code: string;
    name: string;
    continent_code: string;
    continent_name: string;
    area_km2?: number;
    centroid?: [number, number];
  };
  geometry: GeoJSON.Geometry;
}

interface CountryCollection {
  type: 'FeatureCollection';
  features: CountryFeature[];
}

interface RegionFeature {
  type: 'Feature';
  id: number;
  properties: {
    id: number;
    code: string;
    name: string;
    country_code: string;
    country_name: string;
    area_km2?: number;
    centroid?: [number, number];
  };
  geometry: GeoJSON.Geometry;
}

interface RegionCollection {
  type: 'FeatureCollection';
  features: RegionFeature[];
}

interface DistrictFeature {
  type: 'Feature';
  id: number;
  properties: {
    id: number;
    code: string;
    name: string;
    region_id: number;
    region_code: string;
    region_name: string;
    country_code: string;
    country_name: string;
    area_km2?: number;
    centroid?: [number, number];
  };
  geometry: GeoJSON.Geometry;
}

interface DistrictCollection {
  type: 'FeatureCollection';
  features: DistrictFeature[];
}

// Helper to build dynamic paint expressions based on selected/existing codes
function buildFillPaint(
  selectedCodes: string[],
  existingCodes: string[]
): FillLayerSpecification['paint'] {
  // If no codes, return simple transparent values (case expression requires at least one condition)
  if (selectedCodes.length === 0 && existingCodes.length === 0) {
    return {
      'fill-color': 'transparent',
      'fill-opacity': 0,
    };
  }

  const colorExpr: unknown[] = ['case'];
  const opacityExpr: unknown[] = ['case'];

  if (selectedCodes.length > 0) {
    colorExpr.push(['in', ['get', 'code'], ['literal', selectedCodes]]);
    colorExpr.push(COLORS.selected.fill);
    opacityExpr.push(['in', ['get', 'code'], ['literal', selectedCodes]]);
    opacityExpr.push(0.5);
  }
  if (existingCodes.length > 0) {
    colorExpr.push(['in', ['get', 'code'], ['literal', existingCodes]]);
    colorExpr.push(COLORS.existing.fill);
    opacityExpr.push(['in', ['get', 'code'], ['literal', existingCodes]]);
    opacityExpr.push(0.4);
  }
  colorExpr.push('transparent');
  opacityExpr.push(0);

  return {
    'fill-color': colorExpr,
    'fill-opacity': opacityExpr,
  } as FillLayerSpecification['paint'];
}

function buildLinePaint(
  selectedCodes: string[],
  existingCodes: string[]
): LineLayerSpecification['paint'] {
  // If no codes, return simple transparent values (case expression requires at least one condition)
  if (selectedCodes.length === 0 && existingCodes.length === 0) {
    return {
      'line-color': 'transparent',
      'line-width': 2,
      'line-opacity': 0,
    };
  }

  const colorExpr: unknown[] = ['case'];
  const opacityExpr: unknown[] = ['case'];

  if (selectedCodes.length > 0) {
    colorExpr.push(['in', ['get', 'code'], ['literal', selectedCodes]]);
    colorExpr.push(COLORS.selected.stroke);
    opacityExpr.push(['in', ['get', 'code'], ['literal', selectedCodes]]);
    opacityExpr.push(1);
  }
  if (existingCodes.length > 0) {
    colorExpr.push(['in', ['get', 'code'], ['literal', existingCodes]]);
    colorExpr.push(COLORS.existing.stroke);
    opacityExpr.push(['in', ['get', 'code'], ['literal', existingCodes]]);
    opacityExpr.push(1);
  }
  colorExpr.push('transparent');
  opacityExpr.push(0);

  return {
    'line-color': colorExpr,
    'line-width': 2,
    'line-opacity': opacityExpr,
  } as LineLayerSpecification['paint'];
}

/**
 * Interactive map using MapLibre GL for coverage region selection.
 * Fetches country boundaries from the server-side API for reliable ID matching.
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
    const [currentZoom, setCurrentZoom] = useState(initialZoom);
    const [countriesGeoJSON, setCountriesGeoJSON] = useState<CountryCollection | null>(null);
    const [regionsGeoJSON, setRegionsGeoJSON] = useState<RegionCollection | null>(null);
    const [districtsGeoJSON, setDistrictsGeoJSON] = useState<DistrictCollection | null>(null);
    const [visibleCountryCode, setVisibleCountryCode] = useState<string | null>(null);
    const [visibleRegionId, setVisibleRegionId] = useState<number | null>(null);
    const [mapLoaded, setMapLoaded] = useState(false);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Map from ISO code to feature numeric ID for setFeatureState
    const isoToFeatureId = useRef<Map<string, number>>(new Map());

    // Expose the map ref to parent components
    useImperativeHandle(ref, () => mapRef.current as MapRef);

    // Load GeoJSON countries data from server API
    useEffect(() => {
      setIsLoading(true);
      setError(null);

      fetch(`${API_BASE}/api/v1/geo/boundaries/countries`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((geojsonData: CountryCollection) => {
          // Server returns GeoJSON with 'code' in properties (ISO alpha-2)
          const isoMap = new Map<string, number>();
          geojsonData.features.forEach((f, index) => {
            const code = f.properties.code?.toUpperCase();
            if (code) {
              isoMap.set(code, index);
            }
          });

          isoToFeatureId.current = isoMap;
          console.log(`Loaded ${geojsonData.features.length} countries from API`);
          setCountriesGeoJSON(geojsonData);
          setIsLoading(false);
        })
        .catch((err) => {
          console.error('Failed to load countries from API:', err);
          setError('Failed to load map data');
          setIsLoading(false);
        });
    }, []);

    // Load region boundaries when zoomed into a specific country
    useEffect(() => {
      if (!visibleCountryCode || currentZoom < ZOOM_THRESHOLDS.REGION) {
        setRegionsGeoJSON(null);
        setDistrictsGeoJSON(null);
        setVisibleRegionId(null);
        return;
      }

      fetch(`${API_BASE}/api/v1/geo/boundaries/regions?country_code=${visibleCountryCode}`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((geojsonData: RegionCollection) => {
          if (geojsonData.features.length > 0) {
            console.log(`Loaded ${geojsonData.features.length} regions for ${visibleCountryCode}`);
            setRegionsGeoJSON(geojsonData);
          } else {
            setRegionsGeoJSON(null);
          }
        })
        .catch((err) => {
          console.error('Failed to load regions:', err);
          setRegionsGeoJSON(null);
        });
    }, [visibleCountryCode, currentZoom]);

    // Load district boundaries when zoomed into a specific region
    useEffect(() => {
      if (!visibleCountryCode || currentZoom < ZOOM_THRESHOLDS.DISTRICT) {
        setDistrictsGeoJSON(null);
        return;
      }

      // Fetch all districts for the country (API supports country_code parameter)
      fetch(`${API_BASE}/api/v1/geo/boundaries/districts?country_code=${visibleCountryCode}`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((geojsonData: DistrictCollection) => {
          if (geojsonData.features.length > 0) {
            console.log(`Loaded ${geojsonData.features.length} districts for ${visibleCountryCode}`);
            setDistrictsGeoJSON(geojsonData);
          } else {
            setDistrictsGeoJSON(null);
          }
        })
        .catch((err) => {
          console.error('Failed to load districts:', err);
          setDistrictsGeoJSON(null);
        });
    }, [visibleCountryCode, currentZoom]);

    // Detect which country is in view when zoomed in
    useEffect(() => {
      const map = mapRef.current?.getMap();
      if (!map || !mapLoaded || currentZoom < ZOOM_THRESHOLDS.REGION) {
        setVisibleCountryCode(null);
        return;
      }

      // Get center of viewport and determine country
      const center = map.getCenter();
      fetch(`${API_BASE}/api/v1/geo/boundaries/lookup?lng=${center.lng}&lat=${center.lat}`)
        .then((res) => res.json())
        .then((data) => {
          const countryCode = data.data?.country?.code;
          if (countryCode && countryCode !== visibleCountryCode) {
            setVisibleCountryCode(countryCode);
          }
        })
        .catch(() => {
          // Ignore lookup failures
        });
    }, [currentZoom, mapLoaded, visibleCountryCode]);

    const mapStyleUrl = useMemo(() => getMapStyleUrl(isDark), [isDark]);

    const existingSet = useMemo(
      () => new Set(existingCoverage.map((c) => c.toUpperCase())),
      [existingCoverage]
    );

    const selectedSet = useMemo(
      () => new Set(selectedRegions.map((r) => r.code.toUpperCase())),
      [selectedRegions]
    );

    // Build paint expressions based on current selection
    const fillLayerPaint = useMemo(
      () => buildFillPaint(Array.from(selectedSet), Array.from(existingSet)),
      [selectedSet, existingSet]
    );

    const lineLayerPaint = useMemo(
      () => buildLinePaint(Array.from(selectedSet), Array.from(existingSet)),
      [selectedSet, existingSet]
    );

    // Update feature states when selection/existing coverage changes
    useEffect(() => {
      const map = mapRef.current?.getMap();
      if (!map || !mapLoaded || !countriesGeoJSON) return;

      // Update feature state for all countries
      for (const [isoCode, featureId] of isoToFeatureId.current.entries()) {
        const isSelected = selectedSet.has(isoCode);
        const isExisting = existingSet.has(isoCode);

        map.setFeatureState(
          { source: 'countries-source', id: featureId },
          { selected: isSelected, existing: isExisting }
        );
      }
    }, [selectedSet, existingSet, mapLoaded, countriesGeoJSON]);

    // Handle map click for selection - zoom-aware (country at low zoom, city search at high zoom)
    const handleClick = useCallback(
      async (event: MapLayerMouseEvent) => {
        if (viewOnly) return;

        const { lng, lat } = event.lngLat;

        // At high zoom levels, search for nearby cities instead of selecting the country
        if (currentZoom >= ZOOM_THRESHOLDS.CITY) {
          try {
            // Use the nearest cities API to find cities near the click point
            const radius = 50000; // 50km radius
            const response = await fetch(
              `${API_BASE}/api/v1/cities/nearby?lng=${lng}&lat=${lat}&radius=${radius}&limit=1`
            );
            if (response.ok) {
              const data = await response.json();
              const city = data.data?.city;
              if (city) {
                const citySelection: MapSelection = {
                  type: 'city',
                  code: city.id,
                  name: `${city.name}, ${city.region || city.country}`,
                  countryCode: city.country_code,
                  coordinates: [city.longitude, city.latitude],
                };
                const isCurrentlySelected = selectedRegions.some(
                  (r) => r.type === 'city' && r.code === city.id
                );
                if (isCurrentlySelected) {
                  onSelectionChange(selectedRegions.filter((r) => r.code !== city.id));
                } else {
                  onSelectionChange([...selectedRegions, citySelection]);
                }
                return;
              }
            }
          } catch (err) {
            console.error('Failed to lookup nearby city:', err);
          }
          // Fall through to country selection if city lookup fails
        }

        // At district zoom level, try to select district first
        if (currentZoom >= ZOOM_THRESHOLDS.DISTRICT && districtsGeoJSON) {
          const districtFeatures = event.features?.filter(
            (f) => f.layer?.id === 'districts-fill'
          );
          if (districtFeatures?.length) {
            const clickedDistrict = districtFeatures[0];
            const districtProps = clickedDistrict.properties;
            const districtId = districtProps?.id;
            const districtName = districtProps?.name || 'Unknown';
            const regionName = districtProps?.region_name || '';
            const countryCode = districtProps?.country_code || '';

            if (districtId) {
              const districtSelection: MapSelection = {
                type: 'district',
                code: String(districtId),
                name: `${districtName}, ${regionName}`,
                countryCode,
              };
              const isCurrentlySelected = selectedRegions.some(
                (r) => r.type === 'district' && r.code === String(districtId)
              );
              if (isCurrentlySelected) {
                onSelectionChange(selectedRegions.filter((r) => r.code !== String(districtId)));
              } else {
                onSelectionChange([...selectedRegions, districtSelection]);
              }
              return;
            }
          }
        }

        // At region zoom level (between REGION and DISTRICT), try to select region
        if (currentZoom >= ZOOM_THRESHOLDS.REGION && currentZoom < ZOOM_THRESHOLDS.DISTRICT && regionsGeoJSON) {
          // Check if we clicked on a region
          const regionFeatures = event.features?.filter(
            (f) => f.layer?.id === 'regions-fill'
          );
          if (regionFeatures?.length) {
            const clickedRegion = regionFeatures[0];
            const regionProps = clickedRegion.properties;
            const regionCode = regionProps?.code || '';
            const regionName = regionProps?.name || 'Unknown';
            const countryCode = regionProps?.country_code || '';

            if (regionCode) {
              const regionSelection: MapSelection = {
                type: 'region',
                code: regionCode,
                name: `${regionName}, ${countryCode}`,
                countryCode,
              };
              const isCurrentlySelected = selectedRegions.some(
                (r) => r.type === 'region' && r.code === regionCode
              );
              if (isCurrentlySelected) {
                onSelectionChange(selectedRegions.filter((r) => r.code !== regionCode));
              } else {
                onSelectionChange([...selectedRegions, regionSelection]);
              }
              return;
            }
          }
        }

        // At lower zoom levels or if region click failed, select the country
        const features = event.features?.filter((f) => f.layer?.id === 'countries-fill');
        if (!features?.length) return;

        const clickedFeature = features[0];
        const props = clickedFeature.properties;
        const countryCode = (props?.code || '').toUpperCase();
        const countryName = props?.name || 'Unknown';

        if (!countryCode) return;

        const region: MapSelection = { type: 'country', code: countryCode, name: countryName };
        const isCurrentlySelected = selectedSet.has(countryCode);

        if (isCurrentlySelected) {
          onSelectionChange(selectedRegions.filter((r) => r.code.toUpperCase() !== countryCode));
        } else {
          onSelectionChange([...selectedRegions, region]);
        }
      },
      [viewOnly, selectedRegions, onSelectionChange, selectedSet, currentZoom, regionsGeoJSON, districtsGeoJSON]
    );

    const handleZoom = useCallback(() => {
      if (mapRef.current) {
        setCurrentZoom(mapRef.current.getZoom());
      }
    }, []);

    const handleMapLoad = useCallback(() => {
      console.log('Map loaded');
      setMapLoaded(true);
    }, []);

    return (
      <div className="relative w-full overflow-hidden rounded-lg" style={{ height }}>
        {/* Loading overlay */}
        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-background/50 z-10">
            <div className="text-muted-foreground">Loading map...</div>
          </div>
        )}

        {/* Error overlay */}
        {error && (
          <div className="absolute inset-0 flex items-center justify-center bg-background/50 z-10">
            <div className="text-destructive">{error}</div>
          </div>
        )}

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
          onZoom={handleZoom}
          interactiveLayerIds={viewOnly ? [] : ['countries-fill', 'regions-fill', 'districts-fill']}
          style={{ width: '100%', height: '100%' }}
          cursor={viewOnly ? 'default' : 'pointer'}
          attributionControl={false}
        >
          <NavigationControl position="top-right" showCompass={false} />

          {/* Countries overlay layer */}
          {mapLoaded && countriesGeoJSON && (
            <Source
              id="countries-source"
              type="geojson"
              data={countriesGeoJSON}
              generateId={false}
            >
              {/* Fill layer */}
              <Layer id="countries-fill" type="fill" paint={fillLayerPaint} />
              {/* Stroke layer */}
              <Layer id="countries-stroke" type="line" paint={lineLayerPaint} />
            </Source>
          )}

          {/* Regions overlay layer - shown when zoomed into a country */}
          {mapLoaded && regionsGeoJSON && currentZoom >= ZOOM_THRESHOLDS.REGION && (
            <Source
              id="regions-source"
              type="geojson"
              data={regionsGeoJSON}
              generateId={false}
            >
              {/* Region fill - purple/violet for distinction */}
              <Layer
                id="regions-fill"
                type="fill"
                paint={{
                  'fill-color': [
                    'case',
                    ['in', ['get', 'code'], ['literal', selectedRegions.filter(r => r.type === 'region').map(r => r.code)]],
                    '#8b5cf6', // Violet for selected
                    'transparent',
                  ],
                  'fill-opacity': [
                    'case',
                    ['in', ['get', 'code'], ['literal', selectedRegions.filter(r => r.type === 'region').map(r => r.code)]],
                    0.4,
                    0,
                  ],
                }}
              />
              {/* Region stroke - always visible for boundaries */}
              <Layer
                id="regions-stroke"
                type="line"
                paint={{
                  'line-color': [
                    'case',
                    ['in', ['get', 'code'], ['literal', selectedRegions.filter(r => r.type === 'region').map(r => r.code)]],
                    '#8b5cf6', // Violet for selected
                    '#9ca3af', // Gray for unselected
                  ],
                  'line-width': [
                    'case',
                    ['in', ['get', 'code'], ['literal', selectedRegions.filter(r => r.type === 'region').map(r => r.code)]],
                    2.5,
                    1,
                  ],
                  'line-opacity': [
                    'case',
                    ['in', ['get', 'code'], ['literal', selectedRegions.filter(r => r.type === 'region').map(r => r.code)]],
                    1,
                    0.5,
                  ],
                }}
              />
            </Source>
          )}

          {/* Districts overlay layer - shown when zoomed deeper */}
          {mapLoaded && districtsGeoJSON && currentZoom >= ZOOM_THRESHOLDS.DISTRICT && (
            <Source
              id="districts-source"
              type="geojson"
              data={districtsGeoJSON}
              generateId={false}
            >
              {/* District fill - orange for distinction */}
              <Layer
                id="districts-fill"
                type="fill"
                paint={{
                  'fill-color': [
                    'case',
                    ['in', ['to-string', ['get', 'id']], ['literal', selectedRegions.filter(r => r.type === 'district').map(r => r.code)]],
                    '#f97316', // Orange for selected
                    'transparent',
                  ],
                  'fill-opacity': [
                    'case',
                    ['in', ['to-string', ['get', 'id']], ['literal', selectedRegions.filter(r => r.type === 'district').map(r => r.code)]],
                    0.4,
                    0,
                  ],
                }}
              />
              {/* District stroke - always visible for boundaries */}
              <Layer
                id="districts-stroke"
                type="line"
                paint={{
                  'line-color': [
                    'case',
                    ['in', ['to-string', ['get', 'id']], ['literal', selectedRegions.filter(r => r.type === 'district').map(r => r.code)]],
                    '#f97316', // Orange for selected
                    '#d4d4d4', // Light gray for unselected
                  ],
                  'line-width': [
                    'case',
                    ['in', ['to-string', ['get', 'id']], ['literal', selectedRegions.filter(r => r.type === 'district').map(r => r.code)]],
                    2.5,
                    0.5,
                  ],
                  'line-opacity': [
                    'case',
                    ['in', ['to-string', ['get', 'id']], ['literal', selectedRegions.filter(r => r.type === 'district').map(r => r.code)]],
                    1,
                    0.4,
                  ],
                }}
              />
            </Source>
          )}

          {/* City coverage circles and markers for selected cities */}
          {selectedRegions.filter((r) => r.type === 'city' && r.coordinates).length > 0 && (
            <Source
              id="cities-source"
              type="geojson"
              data={{
                type: 'FeatureCollection',
                features: selectedRegions
                  .filter((r) => r.type === 'city' && r.coordinates)
                  .map((city) => ({
                    type: 'Feature' as const,
                    properties: { name: city.name, id: city.code },
                    geometry: {
                      type: 'Point' as const,
                      coordinates: city.coordinates!,
                    },
                  })),
              }}
            >
              {/* City coverage circle - 15km radius visual indicator */}
              <Layer
                id="cities-circle"
                type="circle"
                paint={{
                  'circle-radius': [
                    'interpolate',
                    ['exponential', 2],
                    ['zoom'],
                    6, 20,
                    10, 80,
                    14, 320,
                  ],
                  'circle-color': '#3b82f6',
                  'circle-opacity': 0.25,
                  'circle-stroke-width': 2,
                  'circle-stroke-color': '#3b82f6',
                  'circle-stroke-opacity': 0.8,
                }}
              />
              {/* City center marker */}
              <Layer
                id="cities-center"
                type="circle"
                paint={{
                  'circle-radius': 6,
                  'circle-color': '#3b82f6',
                  'circle-stroke-width': 2,
                  'circle-stroke-color': '#ffffff',
                }}
              />
            </Source>
          )}
        </MapGL>

        {/* Zoom level and selection mode indicator */}
        <div className="absolute bottom-4 right-4 px-2 py-1 text-xs font-mono bg-card/80 rounded text-muted-foreground">
          {currentZoom >= ZOOM_THRESHOLDS.CITY
            ? '🏙️ City'
            : currentZoom >= ZOOM_THRESHOLDS.DISTRICT
              ? '🏘️ District'
              : currentZoom >= ZOOM_THRESHOLDS.REGION
                ? '🗺️ Region'
                : '🌍 Country'}
          {process.env.NODE_ENV === 'development' && ` (z: ${currentZoom.toFixed(1)})`}
        </div>

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
                    backgroundColor: `${COLORS.existing.fill}66`,
                    borderColor: COLORS.existing.stroke,
                  }}
                />
                <span className="text-muted-foreground font-medium">Existing coverage</span>
              </div>
            )}
            {selectedRegions.filter((r) => r.type === 'country').length > 0 && (
              <div className="flex items-center gap-3">
                <span
                  className="w-4 h-4 rounded-md border-2"
                  style={{
                    backgroundColor: `${COLORS.selected.fill}80`,
                    borderColor: COLORS.selected.stroke,
                  }}
                />
                <span className="text-muted-foreground font-medium">
                  Countries ({selectedRegions.filter((r) => r.type === 'country').length})
                </span>
              </div>
            )}
            {selectedRegions.filter((r) => r.type === 'region').length > 0 && (
              <div className="flex items-center gap-3">
                <span className="w-4 h-4 rounded-md bg-violet-500/60 border-2 border-violet-500" />
                <span className="text-muted-foreground font-medium">
                  Regions ({selectedRegions.filter((r) => r.type === 'region').length})
                </span>
              </div>
            )}
            {selectedRegions.filter((r) => r.type === 'district').length > 0 && (
              <div className="flex items-center gap-3">
                <span className="w-4 h-4 rounded-md bg-orange-500/60 border-2 border-orange-500" />
                <span className="text-muted-foreground font-medium">
                  Districts ({selectedRegions.filter((r) => r.type === 'district').length})
                </span>
              </div>
            )}
            {selectedRegions.filter((r) => r.type === 'city').length > 0 && (
              <div className="flex items-center gap-3">
                <span className="w-4 h-4 rounded-full bg-blue-500/80 border-2 border-blue-600" />
                <span className="text-muted-foreground font-medium">
                  Cities ({selectedRegions.filter((r) => r.type === 'city').length})
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
