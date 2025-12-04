'use client';

import { useState, useCallback } from 'react';
import type { MapSelection } from '../types';

/**
 * Hook for managing multi-select region state on the map.
 */
export function useRegionSelection(
  initialSelection: MapSelection[] = [],
  onChange?: (regions: MapSelection[]) => void
) {
  const [selectedRegions, setSelectedRegions] = useState<MapSelection[]>(initialSelection);

  const toggleRegion = useCallback(
    (region: MapSelection) => {
      setSelectedRegions((prev) => {
        const exists = prev.some((r) => r.code === region.code);
        const next = exists
          ? prev.filter((r) => r.code !== region.code)
          : [...prev, region];
        onChange?.(next);
        return next;
      });
    },
    [onChange]
  );

  const addRegion = useCallback(
    (region: MapSelection) => {
      setSelectedRegions((prev) => {
        if (prev.some((r) => r.code === region.code)) return prev;
        const next = [...prev, region];
        onChange?.(next);
        return next;
      });
    },
    [onChange]
  );

  const removeRegion = useCallback(
    (code: string) => {
      setSelectedRegions((prev) => {
        const next = prev.filter((r) => r.code !== code);
        onChange?.(next);
        return next;
      });
    },
    [onChange]
  );

  const clearSelection = useCallback(() => {
    setSelectedRegions([]);
    onChange?.([]);
  }, [onChange]);

  const isSelected = useCallback(
    (code: string) => selectedRegions.some((r) => r.code === code),
    [selectedRegions]
  );

  return {
    selectedRegions,
    setSelectedRegions,
    toggleRegion,
    addRegion,
    removeRegion,
    clearSelection,
    isSelected,
    selectionCount: selectedRegions.length,
  };
}
