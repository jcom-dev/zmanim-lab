'use client';

import { useState, useCallback, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Save, Code2, AlertCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

import { BaseTimeSelector } from './BaseTimeSelector';
import { MethodCard } from './MethodCard';
import { SolarAngleForm } from './methods/SolarAngleForm';
import { FixedOffsetForm } from './methods/FixedOffsetForm';
import { ProportionalHoursForm } from './methods/ProportionalHoursForm';
import { FormulaPreview } from './preview/FormulaPreview';
import { CalculationPreview } from './preview/CalculationPreview';
import { DayArcDiagram } from './preview/DayArcDiagram';
import {
  type FormulaBuilderState,
  type MethodType,
  type SolarDirection,
  type OffsetDirection,
  type ShaosBase,
  initialState,
  generateFormula,
} from './types';

interface FormulaBuilderProps {
  initialFormula?: string;
  onSave?: (formula: string) => void;
  onCopyToAdvanced?: (formula: string) => void;
  latitude?: number;
  longitude?: number;
  locationName?: string;
  className?: string;
}

export function FormulaBuilder({
  initialFormula,
  onSave,
  onCopyToAdvanced,
  latitude,
  longitude,
  locationName,
  className,
}: FormulaBuilderProps) {
  const [state, setState] = useState<FormulaBuilderState>(() => ({
    ...initialState,
    generatedFormula: initialFormula || initialState.generatedFormula,
  }));

  const [showConfirmDialog, setShowConfirmDialog] = useState(false);

  // Update formula whenever state changes
  useEffect(() => {
    const formula = generateFormula(state);
    setState((prev) => ({
      ...prev,
      generatedFormula: formula,
      // Simple validation - actual validation should call the API
      isValid: formula.length > 0,
      validationErrors: [],
    }));
  }, [
    state.baseTime,
    state.method,
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
  const handleBaseTimeChange = useCallback((value: string) => {
    setState((prev) => ({ ...prev, baseTime: value }));
  }, []);

  const handleMethodSelect = useCallback((method: MethodType) => {
    setState((prev) => ({
      ...prev,
      method: prev.method === method ? null : method,
    }));
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

  const handleCopyToAdvanced = useCallback(() => {
    onCopyToAdvanced?.(state.generatedFormula);
  }, [state.generatedFormula, onCopyToAdvanced]);

  return (
    <div className={cn('flex flex-col lg:flex-row gap-6', className)}>
      {/* Left panel - Builder */}
      <div className="flex-1 space-y-6 lg:max-w-[60%]">
        <div className="space-y-2">
          <h2 className="text-xl font-bold">Formula Builder</h2>
          <p className="text-sm text-muted-foreground">
            Build your zman calculation formula using the guided interface below.
          </p>
        </div>

        {/* Base Time Selection */}
        <BaseTimeSelector value={state.baseTime} onChange={handleBaseTimeChange} />

        {/* Method Selection */}
        <div className="space-y-4">
          <label className="text-sm font-medium">Calculation Method</label>
          <div className="space-y-3">
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
              {state.method === 'proportional' && (
                <DayArcDiagram
                  hours={state.shaosHours}
                  base={state.shaosBase}
                  className="mt-4"
                />
              )}
            </MethodCard>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          {onSave && (
            <Button onClick={handleSave} disabled={!state.isValid}>
              <Save className="h-4 w-4 mr-2" />
              Save Formula
            </Button>
          )}
          {onCopyToAdvanced && (
            <Button variant="outline" onClick={handleCopyToAdvanced}>
              <Code2 className="h-4 w-4 mr-2" />
              Copy to Advanced
            </Button>
          )}
        </div>
      </div>

      {/* Right panel - Preview */}
      <div className="lg:w-[40%] space-y-4">
        <FormulaPreview
          formula={state.generatedFormula}
          isValid={state.isValid}
          errors={state.validationErrors}
        />

        <CalculationPreview
          formula={state.generatedFormula}
          isValid={state.isValid}
          latitude={latitude}
          longitude={longitude}
          locationName={locationName}
        />
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
