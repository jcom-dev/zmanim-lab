'use client';

import { useState, useCallback, useRef } from 'react';
import { useSpring, config } from '@react-spring/web';

interface MapZoomState {
  center: [number, number];
  zoom: number;
}

interface UseMapZoomOptions {
  initialCenter?: [number, number];
  initialZoom?: number;
  minZoom?: number;
  maxZoom?: number;
}

/**
 * Hook for managing map zoom and pan with smooth spring animations.
 */
export function useMapZoom(options: UseMapZoomOptions = {}) {
  const {
    initialCenter = [0, 20],
    initialZoom = 1,
    minZoom = 1,
    maxZoom = 8,
  } = options;

  const [state, setState] = useState<MapZoomState>({
    center: initialCenter,
    zoom: initialZoom,
  });

  // Animated spring values for smooth transitions
  const [springProps, springApi] = useSpring(() => ({
    center: initialCenter,
    zoom: initialZoom,
    config: { ...config.gentle, tension: 200, friction: 30 },
  }));

  // Track if user is dragging (to prevent animation interference)
  const isDragging = useRef(false);

  const setCenter = useCallback(
    (center: [number, number], animated = true) => {
      if (isDragging.current) return;
      setState((prev) => ({ ...prev, center }));
      if (animated) {
        springApi.start({ center });
      } else {
        springApi.set({ center });
      }
    },
    [springApi]
  );

  const setZoom = useCallback(
    (zoom: number, animated = true) => {
      if (isDragging.current) return;
      const clampedZoom = Math.max(minZoom, Math.min(maxZoom, zoom));
      setState((prev) => ({ ...prev, zoom: clampedZoom }));
      if (animated) {
        springApi.start({ zoom: clampedZoom });
      } else {
        springApi.set({ zoom: clampedZoom });
      }
    },
    [springApi, minZoom, maxZoom]
  );

  const zoomIn = useCallback(() => {
    setZoom(state.zoom * 1.5);
  }, [state.zoom, setZoom]);

  const zoomOut = useCallback(() => {
    setZoom(state.zoom / 1.5);
  }, [state.zoom, setZoom]);

  const reset = useCallback(() => {
    setState({ center: initialCenter, zoom: initialZoom });
    springApi.start({ center: initialCenter, zoom: initialZoom });
  }, [initialCenter, initialZoom, springApi]);

  const flyTo = useCallback(
    (center: [number, number], zoom?: number) => {
      setState({ center, zoom: zoom ?? state.zoom });
      springApi.start({
        center,
        zoom: zoom ?? state.zoom,
        config: { tension: 150, friction: 25 },
      });
    },
    [state.zoom, springApi]
  );

  const fitToBounds = useCallback(
    (bounds: [[number, number], [number, number]]) => {
      // Calculate center from bounds
      const [[minLng, minLat], [maxLng, maxLat]] = bounds;
      const centerLng = (minLng + maxLng) / 2;
      const centerLat = (minLat + maxLat) / 2;

      // Calculate zoom to fit bounds
      const lngSpan = maxLng - minLng;
      const latSpan = maxLat - minLat;
      const maxSpan = Math.max(lngSpan, latSpan);

      // Rough zoom calculation (adjust based on projection)
      let zoom = 1;
      if (maxSpan < 10) zoom = 6;
      else if (maxSpan < 30) zoom = 4;
      else if (maxSpan < 60) zoom = 3;
      else if (maxSpan < 120) zoom = 2;

      flyTo([centerLng, centerLat], Math.min(zoom, maxZoom));
    },
    [flyTo, maxZoom]
  );

  // Handle drag state
  const onMoveStart = useCallback(() => {
    isDragging.current = true;
  }, []);

  const onMoveEnd = useCallback((position: { coordinates: [number, number]; zoom: number }) => {
    isDragging.current = false;
    setState({ center: position.coordinates, zoom: position.zoom });
    springApi.set({ center: position.coordinates, zoom: position.zoom });
  }, [springApi]);

  return {
    center: state.center,
    zoom: state.zoom,
    springProps,
    setCenter,
    setZoom,
    zoomIn,
    zoomOut,
    reset,
    flyTo,
    fitToBounds,
    onMoveStart,
    onMoveEnd,
    canZoomIn: state.zoom < maxZoom,
    canZoomOut: state.zoom > minZoom,
  };
}
