'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { TemplateSelector } from '@/components/publisher/TemplateSelector';
import { ZmanList } from '@/components/publisher/ZmanList';
import { ZmanConfigModal } from '@/components/publisher/ZmanConfigModal';
import { AlgorithmPreview } from '@/components/publisher/AlgorithmPreview';
import { MonthPreview } from '@/components/publisher/MonthPreview';

interface ZmanConfig {
  method: string;
  params: Record<string, unknown>;
}

interface AlgorithmConfig {
  name: string;
  description?: string;
  zmanim: Record<string, ZmanConfig>;
}

interface Algorithm {
  id: string;
  name: string;
  description: string;
  configuration: AlgorithmConfig;
  status: string;
  is_active: boolean;
}

export default function AlgorithmEditorPage() {
  const router = useRouter();
  const [algorithm, setAlgorithm] = useState<Algorithm | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false);
  const [selectedZman, setSelectedZman] = useState<string | null>(null);
  const [showMonthView, setShowMonthView] = useState(false);

  // Warn before leaving with unsaved changes
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (hasUnsavedChanges) {
        e.preventDefault();
        e.returnValue = '';
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [hasUnsavedChanges]);

  const loadAlgorithm = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm`, {
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      });

      if (!response.ok) {
        throw new Error('Failed to load algorithm');
      }

      const data = await response.json();
      setAlgorithm(data.data || data);
    } catch (err) {
      console.error('Failed to load algorithm:', err);
      setError('Failed to load algorithm. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAlgorithm();
  }, [loadAlgorithm]);

  const handleSave = async () => {
    if (!algorithm) return;

    try {
      setSaving(true);
      setError(null);
      setSuccess(false);

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBaseUrl}/api/v1/publisher/algorithm`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          name: algorithm.configuration.name,
          description: algorithm.configuration.description,
          configuration: algorithm.configuration,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || 'Failed to save algorithm');
      }

      const data = await response.json();
      setAlgorithm(data.data || data);
      setHasUnsavedChanges(false);
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error('Failed to save algorithm:', err);
      setError(err instanceof Error ? err.message : 'Failed to save algorithm');
    } finally {
      setSaving(false);
    }
  };

  const handleTemplateSelect = (template: AlgorithmConfig) => {
    setAlgorithm(prev => prev ? {
      ...prev,
      configuration: template,
    } : {
      id: '',
      name: template.name,
      description: template.description || '',
      configuration: template,
      status: 'draft',
      is_active: false,
    });
    setHasUnsavedChanges(true);
  };

  const handleZmanUpdate = (zmanKey: string, config: ZmanConfig) => {
    if (!algorithm) return;

    setAlgorithm({
      ...algorithm,
      configuration: {
        ...algorithm.configuration,
        zmanim: {
          ...algorithm.configuration.zmanim,
          [zmanKey]: config,
        },
      },
    });
    setHasUnsavedChanges(true);
  };

  const handleZmanRemove = (zmanKey: string) => {
    if (!algorithm) return;

    const newZmanim = { ...algorithm.configuration.zmanim };
    delete newZmanim[zmanKey];

    setAlgorithm({
      ...algorithm,
      configuration: {
        ...algorithm.configuration,
        zmanim: newZmanim,
      },
    });
    setHasUnsavedChanges(true);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="flex justify-center items-center h-64">
            <div className="text-white">Loading algorithm...</div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-900 p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8 flex justify-between items-start">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Algorithm Editor</h1>
            <p className="text-slate-400">Configure your zmanim calculation algorithm</p>
          </div>
          <div className="flex gap-4">
            <Button
              variant="outline"
              onClick={() => setShowMonthView(!showMonthView)}
            >
              {showMonthView ? 'Hide Month View' : 'View Month'}
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                if (hasUnsavedChanges && !confirm('You have unsaved changes. Are you sure you want to leave?')) {
                  return;
                }
                router.push('/publisher/dashboard');
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleSave}
              disabled={saving || !hasUnsavedChanges}
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </Button>
          </div>
        </div>

        {/* Unsaved changes warning */}
        {hasUnsavedChanges && (
          <div className="mb-6 bg-yellow-900/50 border border-yellow-700 rounded-md p-4">
            <p className="text-yellow-200 text-sm">You have unsaved changes</p>
          </div>
        )}

        {/* Error message */}
        {error && (
          <div className="mb-6 bg-red-900/50 border border-red-700 rounded-md p-4">
            <p className="text-red-200 text-sm">{error}</p>
          </div>
        )}

        {/* Success message */}
        {success && (
          <div className="mb-6 bg-green-900/50 border border-green-700 rounded-md p-4">
            <p className="text-green-200 text-sm">Algorithm saved successfully!</p>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Editor Panel */}
          <div className="lg:col-span-2 space-y-6">
            {/* Template Selector */}
            <Card>
              <CardHeader>
                <CardTitle>Algorithm Templates</CardTitle>
                <CardDescription>
                  Choose a template to start from or create a custom algorithm
                </CardDescription>
              </CardHeader>
              <CardContent>
                <TemplateSelector onSelect={handleTemplateSelect} />
              </CardContent>
            </Card>

            {/* Zman List */}
            {algorithm && (
              <Card>
                <CardHeader>
                  <CardTitle>Zmanim Configuration</CardTitle>
                  <CardDescription>
                    Click on any zman to configure its calculation method
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <ZmanList
                    zmanim={algorithm.configuration.zmanim}
                    onZmanClick={setSelectedZman}
                    onZmanRemove={handleZmanRemove}
                  />
                </CardContent>
              </Card>
            )}
          </div>

          {/* Preview Panel */}
          <div className="space-y-6">
            {algorithm && (
              <AlgorithmPreview configuration={algorithm.configuration} />
            )}
          </div>
        </div>

        {/* Month View */}
        {showMonthView && algorithm && (
          <div className="mt-6">
            <MonthPreview configuration={algorithm.configuration} />
          </div>
        )}

        {/* Zman Configuration Modal */}
        {selectedZman && algorithm && (
          <ZmanConfigModal
            isOpen={!!selectedZman}
            onClose={() => setSelectedZman(null)}
            zmanKey={selectedZman}
            currentConfig={algorithm.configuration.zmanim[selectedZman]}
            onSave={(config) => {
              handleZmanUpdate(selectedZman, config);
              setSelectedZman(null);
            }}
          />
        )}
      </div>
    </div>
  );
}
