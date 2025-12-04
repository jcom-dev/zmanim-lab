'use client';

import { useMemo } from 'react';
import { useTheme } from 'next-themes';
import type { MapThemeColors } from '../types';

/**
 * Returns theme-aware color palette for the map.
 * Follows the cartographic elegance design direction.
 */
export function useMapTheme(): MapThemeColors {
  const { resolvedTheme } = useTheme();
  const isDark = resolvedTheme === 'dark';

  return useMemo(() => {
    if (isDark) {
      return {
        // Dark theme - deep charcoal base with subtle contrast
        bg: '#0c0f14',
        land: '#1a1f2a',
        borders: '#2d3548',
        water: '#080a0e',
        // Existing coverage - warm amber glow
        existingFill: 'rgba(245, 158, 11, 0.25)',
        existingStroke: '#f59e0b',
        // New selection - fresh green
        selectedFill: 'rgba(34, 197, 94, 0.35)',
        selectedStroke: '#22c55e',
        // Hover - cool blue
        hoverFill: 'rgba(59, 130, 246, 0.25)',
        hoverStroke: '#3b82f6',
      };
    }

    return {
      // Light theme - soft white base with subtle gray land
      bg: '#f8fafc',
      land: '#e2e8f0',
      borders: '#cbd5e1',
      water: '#dbeafe',
      // Existing coverage - warm amber
      existingFill: 'rgba(245, 158, 11, 0.3)',
      existingStroke: '#d97706',
      // New selection - fresh green
      selectedFill: 'rgba(34, 197, 94, 0.35)',
      selectedStroke: '#16a34a',
      // Hover - cool blue
      hoverFill: 'rgba(59, 130, 246, 0.2)',
      hoverStroke: '#2563eb',
    };
  }, [isDark]);
}
