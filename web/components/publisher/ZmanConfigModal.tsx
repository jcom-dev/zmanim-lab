'use client';
import { useApi } from '@/lib/api-client';

import { useState, useEffect, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { AlertTriangle } from 'lucide-react';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface Method {
  id: string;
  name: string;
  description: string;
  parameters: Array<{
    name: string;
    type: string;
    description: string;
    required: boolean;
    options?: string[];
    min?: number;
    max?: number;
  }>;
}

interface ZmanConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  zmanKey: string;
  currentConfig?: ZmanConfig;
  onSave: (config: ZmanConfig) => void;
  /** @deprecated No longer needed - component uses useApi internally */
  getToken?: () => Promise<string | null>;
}

// Display names for zmanim
const ZMAN_DISPLAY_NAMES: Record<string, string> = {
  alos_hashachar: 'Alos HaShachar',
  misheyakir: 'Misheyakir',
  sunrise: 'Sunrise (Netz HaChama)',
  sof_zman_shma_gra: 'Sof Zman Shma (GRA)',
  sof_zman_shma_mga: 'Sof Zman Shma (MGA)',
  sof_zman_tefilla_gra: 'Sof Zman Tefilla (GRA)',
  sof_zman_tefilla_mga: 'Sof Zman Tefilla (MGA)',
  chatzos: 'Chatzos (Midday)',
  mincha_gedola: 'Mincha Gedola',
  mincha_ketana: 'Mincha Ketana',
  plag_hamincha: 'Plag HaMincha',
  sunset: 'Sunset (Shkiah)',
  tzeis_hakochavim: 'Tzeis HaKochavim',
  tzeis_72: 'Tzeis (72 minutes)',
};

export function ZmanConfigModal({
  isOpen,
  onClose,
  zmanKey,
  currentConfig,
  onSave,
}: ZmanConfigModalProps) {
  const api = useApi();
  const [methods, setMethods] = useState<Method[]>([]);
  const [selectedMethod, setSelectedMethod] = useState<string>(currentConfig?.method || 'sunrise');
  const [params, setParams] = useState<Record<string, unknown>>(currentConfig?.params || {});
  const [error, setError] = useState<string | null>(null);
  const [methodFilter, setMethodFilter] = useState('');
  const [paramErrors, setParamErrors] = useState<Record<string, string>>({});

  const loadMethods = useCallback(async () => {
    try {
      const data = await api.get<{ methods: Method[] }>('/publisher/algorithm/methods');
      setMethods(data?.methods || []);
    } catch (err) {
      console.error('Failed to load methods:', err);
    }
  }, [api]);

  useEffect(() => {
    loadMethods();
  }, [loadMethods]);

  useEffect(() => {
    if (currentConfig) {
      setSelectedMethod(currentConfig.method);
      setParams(currentConfig.params);
    }
  }, [currentConfig]);

  const handleMethodChange = (method: string) => {
    setSelectedMethod(method);
    // Reset params when method changes
    setParams({});
    setError(null);
    setParamErrors({});
  };

  // Validate a single parameter
  const validateParam = (param: Method['parameters'][0], value: unknown): string | null => {
    if (param.required && (value === undefined || value === null || value === '')) {
      return `${param.name} is required`;
    }

    if (param.type === 'number' && value !== undefined && value !== '') {
      const numValue = typeof value === 'number' ? value : parseFloat(value as string);
      if (isNaN(numValue)) {
        return 'Must be a valid number';
      }
      if (param.min !== undefined && numValue < param.min) {
        return `Must be at least ${param.min}`;
      }
      if (param.max !== undefined && numValue > param.max) {
        return `Must be at most ${param.max}`;
      }
    }

    return null;
  };

  const handleParamChange = (name: string, value: unknown) => {
    setParams(prev => ({ ...prev, [name]: value }));
    // Clear error for this param when user changes it
    if (paramErrors[name]) {
      setParamErrors(prev => {
        const next = { ...prev };
        delete next[name];
        return next;
      });
    }
  };

  const handleParamBlur = (param: Method['parameters'][0], value: unknown) => {
    const error = validateParam(param, value);
    if (error) {
      setParamErrors(prev => ({ ...prev, [param.name]: error }));
    }
  };

  const handleSave = () => {
    const selectedMethodObj = methods.find(m => m.id === selectedMethod);
    if (!selectedMethodObj) {
      setError('Please select a calculation method');
      return;
    }

    // Validate all parameters
    const errors: Record<string, string> = {};
    for (const param of selectedMethodObj.parameters) {
      const error = validateParam(param, params[param.name]);
      if (error) {
        errors[param.name] = error;
      }
    }

    if (Object.keys(errors).length > 0) {
      setParamErrors(errors);
      setError('Please fix the errors above');
      return;
    }

    setError(null);
    setParamErrors({});
    onSave({
      method: selectedMethod,
      params,
    });
  };

  if (!isOpen) return null;

  const displayName = ZMAN_DISPLAY_NAMES[zmanKey] || zmanKey;
  const selectedMethodObj = methods.find(m => m.id === selectedMethod);
  const filteredMethods = methodFilter
    ? methods.filter(m =>
        m.name.toLowerCase().includes(methodFilter.toLowerCase()) ||
        m.id.toLowerCase().includes(methodFilter.toLowerCase())
      )
    : methods;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" data-testid="zman-config-modal">
      <div className="bg-card rounded-lg p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <h2 className="text-xl font-bold text-foreground mb-4">
          Configure {displayName}
        </h2>

        {/* Method Selection with Autocomplete */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-muted-foreground mb-2">
            Calculation Method
          </label>
          <Input
            type="text"
            placeholder="Search methods..."
            value={methodFilter}
            onChange={(e) => setMethodFilter(e.target.value)}
            className="mb-2"
            data-testid="method-autocomplete"
          />
          <div className="space-y-2 max-h-48 overflow-y-auto">
            {filteredMethods.map((method) => (
              <div
                key={method.id}
                className={`p-3 rounded-lg cursor-pointer transition-colors ${
                  selectedMethod === method.id
                    ? 'bg-blue-600 text-white'
                    : 'bg-secondary text-muted-foreground hover:bg-muted'
                }`}
                onClick={() => handleMethodChange(method.id)}
                data-testid={`method-option-${method.id}`}
              >
                <div className="font-medium">{method.name}</div>
                <div className="text-sm opacity-75">{method.description}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Parameters */}
        {selectedMethodObj && selectedMethodObj.parameters.length > 0 && (
          <div className="mb-6">
            <label className="block text-sm font-medium text-muted-foreground mb-2">
              Parameters
            </label>
            <div className="space-y-4">
              {selectedMethodObj.parameters.map((param) => (
                <div key={param.name}>
                  <label className="block text-sm text-muted-foreground mb-1">
                    {param.name}
                    {param.required && <span className="text-destructive ml-1">*</span>}
                  </label>
                  {param.type === 'select' ? (
                    <select
                      className={`w-full p-2 rounded bg-secondary text-foreground border ${
                        paramErrors[param.name] ? 'border-red-500' : 'border-border'
                      }`}
                      value={(params[param.name] as string) || ''}
                      onChange={(e) => handleParamChange(param.name, e.target.value)}
                      onBlur={() => handleParamBlur(param, params[param.name])}
                      data-testid={`param-${param.name}`}
                    >
                      <option value="">Select...</option>
                      {param.options?.map((opt) => (
                        <option key={opt} value={opt}>{opt}</option>
                      ))}
                    </select>
                  ) : (
                    <Input
                      type={param.type === 'number' ? 'number' : 'text'}
                      value={(params[param.name] as string | number) || ''}
                      onChange={(e) => {
                        const value = param.type === 'number'
                          ? parseFloat(e.target.value)
                          : e.target.value;
                        handleParamChange(param.name, value);
                      }}
                      onBlur={(e) => {
                        const value = param.type === 'number'
                          ? parseFloat(e.target.value)
                          : e.target.value;
                        handleParamBlur(param, value);
                      }}
                      min={param.min}
                      max={param.max}
                      placeholder={param.description}
                      className={paramErrors[param.name] ? 'border-red-500 focus-visible:ring-red-500' : ''}
                      data-testid={`param-${param.name}`}
                    />
                  )}
                  {paramErrors[param.name] ? (
                    <p className="text-xs text-red-600 mt-1 flex items-center gap-1">
                      <AlertTriangle className="h-3 w-3" />
                      {paramErrors[param.name]}
                    </p>
                  ) : (
                    <p className="text-xs text-muted-foreground mt-1">{param.description}</p>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Actions and Error */}
        <div className="space-y-3">
          {/* Error */}
          {error && (
            <div className="flex items-center gap-2 p-3 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-200">
              <AlertTriangle className="h-4 w-4 flex-shrink-0" />
              <span className="text-sm">{error}</span>
            </div>
          )}

          {/* Actions */}
          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button
              onClick={handleSave}
              disabled={Object.keys(paramErrors).length > 0}
            >
              Save
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
