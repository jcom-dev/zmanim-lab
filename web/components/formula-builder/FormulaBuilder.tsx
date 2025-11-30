'use client';

import { useState, useCallback, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Save, AlertCircle } from 'lucide-react';
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
  type ParseResult,
  initialState,
  generateFormula,
  parseFormula,
} from './types';

interface FormulaBuilderProps {
  initialFormula?: string;
  onSave?: (formula: string) => void;
  onParseError?: (error: string) => void;
  className?: string;
}

export function FormulaBuilder({
  initialFormula,
  onSave,
  onParseError,
  className,
}: FormulaBuilderProps) {
  const [state, setState] = useState<FormulaBuilderState>(() => ({
    ...initialState,
    generatedFormula: initialFormula || initialState.generatedFormula,
  }));

  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [parseError, setParseError] = useState<string | null>(null);
  const [lastParsedFormula, setLastParsedFormula] = useState<string | null>(null);

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
  }, [
    lastParsedFormula,
    initialFormula,
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

  const handleSave = useCallback(() => {
    if (initialFormula && initialFormula !== state.generatedFormula) {
      setShowConfirmDialog(true);
    } else {
      onSave?.(state.generatedFormula);
    }
  }, [initialFormula, state.generatedFormula, onSave]);

  const handleConfirmSave = useCallback(() => {
    setShowConfirmDialog(false);
    onSave?.(state.generatedFormula);
  }, [state.generatedFormula, onSave]);

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
            <MethodCard method="proportional" title="Proportional Hours" description="Calculate using shaos zmanios" selected={false} onSelect={() => {}} />
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
            description="Add or subtract fixed minutes from a reference time"
            selected={state.method === 'fixed'}
            onSelect={() => handleMethodSelect('fixed')}
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
            description="Calculate using shaos zmanios (halachic hours)"
            selected={state.method === 'proportional'}
            onSelect={() => handleMethodSelect('proportional')}
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

      {/* Action Buttons - Prominent */}
      <div className="flex gap-4 pt-2">
        {onSave && (
          <Button
            onClick={handleSave}
            disabled={!state.isValid}
            size="lg"
            className="h-12 px-6 text-base font-semibold"
          >
            <Save className="h-5 w-5 mr-2" />
            Save Formula
          </Button>
        )}
      </div>

      {/* Confirmation Dialog */}
      {showConfirmDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-card rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-start gap-3">
              <AlertCircle className="h-6 w-6 text-amber-500 flex-shrink-0" />
              <div>
                <h3 className="font-semibold text-lg">Overwrite Formula?</h3>
                <p className="text-sm text-muted-foreground mt-1">
                  This will replace the existing formula. This action cannot be undone.
                </p>
                <div className="flex gap-3 mt-4">
                  <Button variant="outline" onClick={() => setShowConfirmDialog(false)}>
                    Cancel
                  </Button>
                  <Button onClick={handleConfirmSave}>
                    Overwrite
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default FormulaBuilder;
