'use client';

import { useState, useCallback, useEffect, useRef } from 'react';
import { AlertCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

import { MethodCard } from './MethodCard';
import { FixedZmanForm } from './methods/FixedZmanForm';
import { SolarAngleForm } from './methods/SolarAngleForm';
import { FixedOffsetForm } from './methods/FixedOffsetForm';
import { ProportionalHoursForm } from './methods/ProportionalHoursForm';
import {
  type FormulaBuilderState,
  type MethodType,
  type SolarDirection,
  type OffsetDirection,
  type ShaosBase,
  initialState,
  generateFormula,
  parseFormula,
} from './types';
import { ALGORITHM_TOOLTIPS } from '@/lib/tooltip-content';

interface FormulaBuilderProps {
  initialFormula?: string;
  onChange?: (formula: string) => void;
  onParseError?: (error: string) => void;
  className?: string;
}

export function FormulaBuilder({
  initialFormula,
  onChange,
  onParseError,
  className,
}: FormulaBuilderProps) {
  const [state, setState] = useState<FormulaBuilderState>(() => ({
    ...initialState,
    generatedFormula: initialFormula || initialState.generatedFormula,
  }));

  const [parseError, setParseError] = useState<string | null>(null);
  const [lastParsedFormula, setLastParsedFormula] = useState<string | null>(null);
  const isInitialMount = useRef(true);

  // Parse initial formula and auto-select the correct method
  // Re-parse when initialFormula changes (e.g., when data loads asynchronously)
  useEffect(() => {
    // Skip if formula hasn't changed
    if (initialFormula === lastParsedFormula) return;

    setLastParsedFormula(initialFormula || null);

    if (initialFormula && initialFormula.trim()) {
      const result = parseFormula(initialFormula);
      if (result.success && result.state) {
        setState((prev) => ({
          ...prev,
          ...result.state,
          generatedFormula: initialFormula,
        }));
        setParseError(null);
      } else if (!result.success && result.error) {
        setParseError(result.error);
        onParseError?.(result.error);
      }
    }
  }, [initialFormula, lastParsedFormula, onParseError]);

  // Update formula whenever state changes (skip if we haven't parsed initial formula yet)
  useEffect(() => {
    if (lastParsedFormula === null && initialFormula) return;

    const formula = generateFormula(state);
    setState((prev) => ({
      ...prev,
      generatedFormula: formula,
      // Simple validation - actual validation should call the API
      isValid: formula.length > 0,
      validationErrors: [],
    }));

    // Call onChange to update parent (skip on initial mount to avoid overwriting initial formula)
    if (!isInitialMount.current && formula !== initialFormula) {
      onChange?.(formula);
    }
    isInitialMount.current = false;
  }, [
    lastParsedFormula,
    initialFormula,
    onChange,
    state.baseTime,
    state.method,
    state.selectedFixedZman,
    state.solarDegrees,
    state.solarDirection,
    state.offsetMinutes,
    state.offsetDirection,
    state.offsetBase,
    state.shaosHours,
    state.shaosBase,
    state.customStart,
    state.customEnd,
  ]);

  // Handlers
  const handleMethodSelect = useCallback((method: MethodType) => {
    setState((prev) => ({
      ...prev,
      method: prev.method === method ? null : method,
    }));
  }, []);

  const handleFixedZmanChange = useCallback((value: string) => {
    setState((prev) => ({ ...prev, selectedFixedZman: value }));
  }, []);

  const handleSolarDegreesChange = useCallback((value: number) => {
    setState((prev) => ({ ...prev, solarDegrees: value }));
  }, []);

  const handleSolarDirectionChange = useCallback((direction: SolarDirection) => {
    setState((prev) => ({ ...prev, solarDirection: direction }));
  }, []);

  const handleOffsetMinutesChange = useCallback((value: number) => {
    setState((prev) => ({ ...prev, offsetMinutes: value }));
  }, []);

  const handleOffsetDirectionChange = useCallback((direction: OffsetDirection) => {
    setState((prev) => ({ ...prev, offsetDirection: direction }));
  }, []);

  const handleOffsetBaseChange = useCallback((base: string) => {
    setState((prev) => ({ ...prev, offsetBase: base }));
  }, []);

  const handleShaosHoursChange = useCallback((value: number) => {
    setState((prev) => ({ ...prev, shaosHours: value }));
  }, []);

  const handleShaosBaseChange = useCallback((base: ShaosBase) => {
    setState((prev) => ({ ...prev, shaosBase: base }));
  }, []);

  const handleCustomStartChange = useCallback((value: string) => {
    setState((prev) => ({ ...prev, customStart: value }));
  }, []);

  const handleCustomEndChange = useCallback((value: string) => {
    setState((prev) => ({ ...prev, customEnd: value }));
  }, []);

  // If there's a parse error, show disabled state with error message
  if (parseError) {
    return (
      <div className={cn('space-y-6', className)}>
        {/* Header Section */}
        <div className="space-y-1">
          <h2 className="text-xl font-bold">Formula Builder</h2>
          <p className="text-sm text-muted-foreground">
            Build your zman calculation formula using the guided interface below.
          </p>
        </div>

        {/* Error State */}
        <div className="rounded-lg border-2 border-amber-500/50 bg-amber-500/10 p-6">
          <div className="flex items-start gap-3">
            <AlertCircle className="h-6 w-6 text-amber-500 flex-shrink-0 mt-0.5" />
            <div className="space-y-2">
              <h3 className="font-semibold text-amber-600 dark:text-amber-400">Advanced Formula Detected</h3>
              <p className="text-sm text-muted-foreground">
                {parseError}
              </p>
            </div>
          </div>
        </div>

        {/* Greyed out method cards */}
        <div className="space-y-4 opacity-40 pointer-events-none">
          <label className="text-sm font-medium text-muted-foreground uppercase tracking-wide">Calculation Method</label>
          <div className="space-y-3">
            <MethodCard method="fixed_zman" title="Fixed Zmanim" description="Select standalone astronomical events" selected={false} onSelect={() => {}} />
            <MethodCard method="solar" title="Solar Angle" description="Calculate based on sun position" selected={false} onSelect={() => {}} />
            <MethodCard method="fixed" title="Fixed Offset" description="Add or subtract fixed minutes" selected={false} onSelect={() => {}} />
            <MethodCard method="proportional" title="Proportional Hours" description="Calculate using halachic hours" selected={false} onSelect={() => {}} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={cn('space-y-6', className)}>
      {/* Header Section */}
      <div className="space-y-1">
        <h2 className="text-xl font-bold">Formula Builder</h2>
        <p className="text-sm text-muted-foreground">
          Build your zman calculation formula using the guided interface below.
        </p>
      </div>

      {/* Method Selection */}
      <div className="space-y-4">
        <label className="text-sm font-medium text-muted-foreground uppercase tracking-wide">Calculation Method</label>
        <div className="space-y-3">
          <MethodCard
            method="fixed_zman"
            title="Fixed Zmanim"
            description="Select standalone astronomical events (no parameters needed)"
            selected={state.method === 'fixed_zman'}
            onSelect={() => handleMethodSelect('fixed_zman')}
            tooltip={ALGORITHM_TOOLTIPS.fixed_zman}
          >
            <FixedZmanForm
              value={state.selectedFixedZman}
              onChange={handleFixedZmanChange}
            />
          </MethodCard>

          <MethodCard
            method="solar"
            title="Solar Angle"
            description="Calculate based on sun position below horizon"
            selected={state.method === 'solar'}
            onSelect={() => handleMethodSelect('solar')}
            tooltip={ALGORITHM_TOOLTIPS.solar_angle}
          >
            <SolarAngleForm
              degrees={state.solarDegrees}
              direction={state.solarDirection}
              onDegreesChange={handleSolarDegreesChange}
              onDirectionChange={handleSolarDirectionChange}
            />
          </MethodCard>

          <MethodCard
            method="fixed"
            title="Fixed Offset"
            description="Add or subtract fixed clock minutes from a reference time (not proportional)"
            selected={state.method === 'fixed'}
            onSelect={() => handleMethodSelect('fixed')}
            tooltip={ALGORITHM_TOOLTIPS.fixed_offset}
          >
            <FixedOffsetForm
              minutes={state.offsetMinutes}
              direction={state.offsetDirection}
              base={state.offsetBase}
              onMinutesChange={handleOffsetMinutesChange}
              onDirectionChange={handleOffsetDirectionChange}
              onBaseChange={handleOffsetBaseChange}
            />
          </MethodCard>

          <MethodCard
            method="proportional"
            title="Proportional Hours"
            description="Calculate using halachic proportional hours"
            selected={state.method === 'proportional'}
            onSelect={() => handleMethodSelect('proportional')}
            tooltip={ALGORITHM_TOOLTIPS.proportional_hours}
          >
            <ProportionalHoursForm
              hours={state.shaosHours}
              base={state.shaosBase}
              customStart={state.customStart}
              customEnd={state.customEnd}
              onHoursChange={handleShaosHoursChange}
              onBaseChange={handleShaosBaseChange}
              onCustomStartChange={handleCustomStartChange}
              onCustomEndChange={handleCustomEndChange}
            />
          </MethodCard>
        </div>
      </div>
    </div>
  );
}

export default FormulaBuilder;
