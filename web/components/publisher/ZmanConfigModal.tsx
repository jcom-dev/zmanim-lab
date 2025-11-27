'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

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
  const [methods, setMethods] = useState<Method[]>([]);
  const [selectedMethod, setSelectedMethod] = useState<string>(currentConfig?.method || 'sunrise');
  const [params, setParams] = useState<Record<string, unknown>>(currentConfig?.params || {});
  const [error, setError] = useState<string | null>(null);
  const [methodFilter, setMethodFilter] = useState('');

  useEffect(() => {
    loadMethods();
  }, []);

  useEffect(() => {
    if (currentConfig) {
      setSelectedMethod(currentConfig.method);
      setParams(currentConfig.params);
    }
  }, [currentConfig]);

  const loadMethods = async () => {
    try {
      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm/methods`, {
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      });

      if (response.ok) {
        const data = await response.json();
        setMethods(data.data?.methods || data.methods || []);
      }
    } catch (err) {
      console.error('Failed to load methods:', err);
    }
  };

  const handleMethodChange = (method: string) => {
    setSelectedMethod(method);
    // Reset params when method changes
    setParams({});
    setError(null);
  };

  const handleParamChange = (name: string, value: unknown) => {
    setParams(prev => ({ ...prev, [name]: value }));
  };

  const handleSave = () => {
    const selectedMethodObj = methods.find(m => m.id === selectedMethod);
    if (!selectedMethodObj) {
      setError('Please select a calculation method');
      return;
    }

    // Validate required parameters
    for (const param of selectedMethodObj.parameters) {
      if (param.required && !params[param.name]) {
        setError(`${param.name} is required`);
        return;
      }
    }

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
      <div className="bg-slate-800 rounded-lg p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <h2 className="text-xl font-bold text-white mb-4">
          Configure {displayName}
        </h2>

        {/* Method Selection with Autocomplete */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-slate-300 mb-2">
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
                    : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
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
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Parameters
            </label>
            <div className="space-y-4">
              {selectedMethodObj.parameters.map((param) => (
                <div key={param.name}>
                  <label className="block text-sm text-slate-400 mb-1">
                    {param.name}
                    {param.required && <span className="text-red-400 ml-1">*</span>}
                  </label>
                  {param.type === 'select' ? (
                    <select
                      className="w-full p-2 rounded bg-slate-700 text-white border border-slate-600"
                      value={(params[param.name] as string) || ''}
                      onChange={(e) => handleParamChange(param.name, e.target.value)}
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
                      min={param.min}
                      max={param.max}
                      placeholder={param.description}
                      data-testid={`param-${param.name}`}
                    />
                  )}
                  <p className="text-xs text-slate-500 mt-1">{param.description}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="mb-4 p-3 bg-red-900/50 border border-red-700 rounded text-red-200 text-sm">
            {error}
          </div>
        )}

        {/* Actions */}
        <div className="flex justify-end gap-3">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleSave}>
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}
