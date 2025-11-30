'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  ArrowLeft,
  Save,
  Sparkles,
  BookOpen,
  Calendar,
  Code2,
  GripVertical,
  Loader2,
  AlertCircle,
  Wand2,
} from 'lucide-react';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';
import { useApi } from '@/lib/api-client';

import { DSLEditor } from '@/components/editor/DSLEditor';
import { FormulaBuilder } from '@/components/formula-builder/FormulaBuilder';
import { BilingualInput } from '@/components/shared/BilingualInput';
import { HighlightedFormula } from '@/components/shared/HighlightedFormula';
import { AIFormulaGenerator } from '@/components/algorithm/AIFormulaGenerator';
import { BrowseTemplatesDialog } from '@/components/algorithm/BrowseTemplatesDialog';
import { WeeklyPreviewDialog } from '@/components/algorithm/WeeklyPreviewDialog';
import {
  useZmanDetails,
  useUpdateZman,
  useCreateZman,
  usePreviewFormula,
  useValidateFormula,
  useZmanimList,
  type PreviewResult,
} from '@/lib/hooks/useZmanimList';

// Default Brooklyn location
const DEFAULT_LOCATION = {
  latitude: 40.6782,
  longitude: -73.9442,
  timezone: 'America/New_York',
  displayName: 'Brooklyn, NY',
};

type EditorMode = 'guided' | 'advanced';

export default function ZmanEditorPage() {
  const router = useRouter();
  const params = useParams();
  const zmanKey = params.zman_key as string;
  const isNewZman = zmanKey === 'new';

  // Panel resizing
  const [leftWidth, setLeftWidth] = useState(50);
  const [isResizing, setIsResizing] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Editor state
  const [mode, setMode] = useState<EditorMode>('guided');
  const [hebrewName, setHebrewName] = useState('');
  const [englishName, setEnglishName] = useState('');
  const [formula, setFormula] = useState('');
  const [aiExplanation, setAiExplanation] = useState('');
  const [publisherComment, setPublisherComment] = useState('');
  const [hasChanges, setHasChanges] = useState(false);

  // Preview state
  const [previewDate, setPreviewDate] = useState(() =>
    new Date().toISOString().split('T')[0]
  );
  const [previewResult, setPreviewResult] = useState<PreviewResult | null>(null);
  const [showWeeklyDialog, setShowWeeklyDialog] = useState(false);

  // Dialog state
  const [showAIGenerator, setShowAIGenerator] = useState(false);
  const [showBrowseTemplates, setShowBrowseTemplates] = useState(false);
  const [generatingExplanation, setGeneratingExplanation] = useState(false);

  // API client
  const api = useApi();

  // Fetch data
  const { data: zman, isLoading: loadingZman } = useZmanDetails(isNewZman ? null : zmanKey);
  const { data: allZmanim = [] } = useZmanimList();
  const updateZman = useUpdateZman(zmanKey);
  const createZman = useCreateZman();
  const previewFormula = usePreviewFormula();
  const validateFormula = useValidateFormula();

  // Load existing zman data
  useEffect(() => {
    if (zman) {
      setHebrewName(zman.hebrew_name);
      setEnglishName(zman.english_name);
      setFormula(zman.formula_dsl);
      setAiExplanation(zman.ai_explanation || '');
      setPublisherComment(zman.publisher_comment || '');
      setHasChanges(false);
    }
  }, [zman]);

  // Track changes
  useEffect(() => {
    if (!zman) return;
    const changed =
      hebrewName !== zman.hebrew_name ||
      englishName !== zman.english_name ||
      formula !== zman.formula_dsl ||
      aiExplanation !== (zman.ai_explanation || '') ||
      publisherComment !== (zman.publisher_comment || '');
    setHasChanges(changed);
  }, [hebrewName, englishName, formula, aiExplanation, publisherComment, zman]);

  // Live preview with debounce
  useEffect(() => {
    if (!formula.trim()) {
      setPreviewResult(null);
      return;
    }

    const timeout = setTimeout(async () => {
      try {
        const result = await previewFormula.mutateAsync({
          formula,
          date: previewDate,
          location: DEFAULT_LOCATION,
        });
        setPreviewResult(result);
      } catch {
        setPreviewResult(null);
      }
    }, 300);

    return () => clearTimeout(timeout);
  }, [formula, previewDate]);

  // Handle resize
  const handleMouseDown = useCallback(() => {
    setIsResizing(true);
  }, []);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isResizing || !containerRef.current) return;
      const containerRect = containerRef.current.getBoundingClientRect();
      const newWidth = ((e.clientX - containerRect.left) / containerRect.width) * 100;
      setLeftWidth(Math.min(Math.max(newWidth, 30), 70));
    };

    const handleMouseUp = () => {
      setIsResizing(false);
    };

    if (isResizing) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isResizing]);

  // Validation handler for DSLEditor
  const handleValidation = useCallback(async (formulaToValidate: string) => {
    try {
      const result = await validateFormula.mutateAsync(formulaToValidate);
      return {
        valid: result.valid,
        errors: result.errors?.map(e => ({ message: e.message })) || [],
      };
    } catch {
      return { valid: false, errors: [{ message: 'Validation failed' }] };
    }
  }, [validateFormula]);

  // Generate AI explanation handler
  const handleGenerateExplanation = async () => {
    if (!formula.trim()) {
      toast.error('Please enter a formula first');
      return;
    }

    setGeneratingExplanation(true);
    try {
      const response = await api.post<{ explanation: string; language: string; source: string }>(
        '/ai/explain-formula',
        { body: JSON.stringify({ formula, language: 'en' }) }
      );
      setAiExplanation(response.explanation);
      setHasChanges(true);
      toast.success('AI explanation generated');
    } catch (error) {
      console.error('Failed to generate explanation:', error);
      toast.error('Failed to generate AI explanation. The AI service may not be configured.');
    } finally {
      setGeneratingExplanation(false);
    }
  };

  // Save handler
  const handleSave = async () => {
    if (!hebrewName.trim() || !englishName.trim() || !formula.trim()) {
      toast.error('Please fill in all required fields');
      return;
    }

    try {
      if (isNewZman) {
        // Generate zman_key from english name
        const newKey = englishName.toLowerCase().replace(/[^a-z0-9]+/g, '_');
        await createZman.mutateAsync({
          zman_key: newKey,
          hebrew_name: hebrewName,
          english_name: englishName,
          formula_dsl: formula,
          ai_explanation: aiExplanation || undefined,
          publisher_comment: publisherComment || undefined,
        });
        toast.success('Zman created successfully');
      } else {
        await updateZman.mutateAsync({
          hebrew_name: hebrewName,
          english_name: englishName,
          formula_dsl: formula,
          ai_explanation: aiExplanation || undefined,
          publisher_comment: publisherComment || undefined,
        });
        toast.success('Zman updated successfully');
      }
      router.push('/publisher/algorithm');
    } catch (error) {
      toast.error(isNewZman ? 'Failed to create zman' : 'Failed to update zman');
      console.error('Save error:', error);
    }
  };

  // Handle AI formula acceptance
  const handleAIFormulaAccept = useCallback((newFormula: string, explanation: string) => {
    setFormula(newFormula);
    if (explanation) {
      setAiExplanation(explanation);
    }
  }, []);

  // Handle template selection
  const handleTemplateSelect = useCallback((selectedFormula: string) => {
    setFormula(selectedFormula);
  }, []);

  // Handle formula from builder
  const handleBuilderSave = useCallback((newFormula: string) => {
    setFormula(newFormula);
  }, []);

  const handleCopyToAdvanced = useCallback((newFormula: string) => {
    setFormula(newFormula);
    setMode('advanced');
  }, []);

  // Get zman keys for autocomplete
  const zmanimKeys = allZmanim.map(z => z.zman_key);

  if (loadingZman && !isNewZman) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col bg-background">
      {/* Header */}
      <header className="border-b bg-card p-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => router.push('/publisher/algorithm')}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to List
          </Button>
          <div className="h-6 w-px bg-border" />
          <h1 className="text-xl font-bold">
            {isNewZman ? 'New Custom Zman' : (
              <>
                <span className="font-hebrew">{zman?.hebrew_name}</span>
                <span className="mx-2 text-muted-foreground">•</span>
                <span>{zman?.english_name}</span>
              </>
            )}
          </h1>
          {zman?.category && (
            <Badge variant={zman.category === 'essential' ? 'default' : 'secondary'}>
              {zman.category}
            </Badge>
          )}
        </div>
        <div className="flex items-center gap-2">
          {/* AI Assistant */}
          <Button variant="outline" size="sm" onClick={() => setShowAIGenerator(true)}>
            <Sparkles className="h-4 w-4 mr-2" />
            AI Assistant
          </Button>

          {/* Browse Templates */}
          <Button variant="outline" size="sm" onClick={() => setShowBrowseTemplates(true)}>
            <BookOpen className="h-4 w-4 mr-2" />
            Browse Templates
          </Button>

          {/* Save */}
          <Button
            onClick={handleSave}
            disabled={
              !hasChanges && !isNewZman ||
              updateZman.isPending ||
              createZman.isPending
            }
          >
            {(updateZman.isPending || createZman.isPending) ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-2" />
            )}
            {isNewZman ? 'Create' : 'Save'}
          </Button>
        </div>
      </header>

      {/* Main Content: Split View */}
      <div
        ref={containerRef}
        className="flex-1 flex overflow-hidden"
        style={{ cursor: isResizing ? 'col-resize' : 'default' }}
      >
        {/* Left: Editor Panel */}
        <div
          style={{ width: `${leftWidth}%` }}
          className="flex flex-col border-r overflow-hidden"
          role="region"
          aria-label="Formula editor"
        >
          <div className="flex-1 overflow-y-auto p-6 space-y-6">
            {/* Mode Toggle */}
            <Tabs value={mode} onValueChange={(v) => setMode(v as EditorMode)}>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="guided">
                  <Wand2 className="h-4 w-4 mr-2" />
                  Guided Builder
                </TabsTrigger>
                <TabsTrigger value="advanced">
                  <Code2 className="h-4 w-4 mr-2" />
                  Advanced DSL
                </TabsTrigger>
              </TabsList>
            </Tabs>

            {/* Bilingual Name Inputs */}
            <BilingualInput
              nameHebrew={hebrewName}
              nameEnglish={englishName}
              onHebrewChange={setHebrewName}
              onEnglishChange={setEnglishName}
            />

            {/* Formula Editor */}
            {mode === 'guided' ? (
              <FormulaBuilder
                initialFormula={formula}
                onSave={handleBuilderSave}
                onCopyToAdvanced={handleCopyToAdvanced}
                latitude={DEFAULT_LOCATION.latitude}
                longitude={DEFAULT_LOCATION.longitude}
                locationName={DEFAULT_LOCATION.displayName}
              />
            ) : (
              <DSLEditor
                value={formula}
                onChange={setFormula}
                onValidate={handleValidation}
                zmanimKeys={zmanimKeys}
              />
            )}

            {/* AI Explanation */}
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-base">AI Explanation</CardTitle>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={handleGenerateExplanation}
                    disabled={generatingExplanation || !formula.trim()}
                  >
                    {generatingExplanation ? (
                      <Loader2 className="h-4 w-4 mr-1 animate-spin" />
                    ) : (
                      <Sparkles className="h-4 w-4 mr-1" />
                    )}
                    {generatingExplanation ? 'Generating...' : 'Generate'}
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <Textarea
                  value={aiExplanation}
                  onChange={(e) => setAiExplanation(e.target.value)}
                  placeholder="An AI-generated explanation of this formula will appear here..."
                  rows={4}
                />
              </CardContent>
            </Card>

            {/* Publisher Comment */}
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-base">Publisher Comment</CardTitle>
              </CardHeader>
              <CardContent>
                <Textarea
                  value={publisherComment}
                  onChange={(e) => setPublisherComment(e.target.value)}
                  placeholder="Add a note for users viewing this zman (e.g., halachic source, custom minhag)..."
                  rows={3}
                />
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Resizer */}
        <div
          role="separator"
          aria-orientation="vertical"
          aria-valuenow={Math.round(leftWidth)}
          aria-valuemin={30}
          aria-valuemax={70}
          aria-label="Resize panels"
          tabIndex={0}
          className={cn(
            'w-2 bg-border hover:bg-primary/50 cursor-col-resize flex items-center justify-center transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2',
            isResizing && 'bg-primary'
          )}
          onMouseDown={handleMouseDown}
          onKeyDown={(e) => {
            if (e.key === 'ArrowLeft') {
              e.preventDefault();
              setLeftWidth((w) => Math.max(30, w - 5));
            } else if (e.key === 'ArrowRight') {
              e.preventDefault();
              setLeftWidth((w) => Math.min(70, w + 5));
            }
          }}
        >
          <GripVertical className="h-4 w-4 text-muted-foreground" aria-hidden="true" />
        </div>

        {/* Right: Preview Panel */}
        <div
          style={{ width: `${100 - leftWidth}%` }}
          className="flex flex-col overflow-hidden bg-muted/30"
          role="region"
          aria-label="Formula preview and calculation"
        >
          <div className="flex-1 overflow-y-auto p-6 space-y-6">
            {/* Formula Preview */}
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-base">Formula</CardTitle>
              </CardHeader>
              <CardContent>
                {formula.trim() ? (
                  <HighlightedFormula formula={formula} />
                ) : (
                  <p className="text-sm text-muted-foreground italic">
                    Enter a formula to see the syntax highlighted preview
                  </p>
                )}
              </CardContent>
            </Card>

            {/* Calculated Result */}
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-base">Calculated Result</CardTitle>
                  {previewFormula.isPending && (
                    <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                  )}
                </div>
              </CardHeader>
              <CardContent>
                {previewResult ? (
                  <div className="animate-in fade-in-0 duration-200">
                    <div
                      className="text-4xl font-bold font-mono transition-all duration-300"
                      role="status"
                      aria-live="polite"
                      aria-label={`Calculated time: ${previewResult.result}`}
                    >
                      {previewResult.result}
                    </div>
                    <div className="text-sm text-muted-foreground mt-2">
                      {previewDate} • {DEFAULT_LOCATION.displayName}
                    </div>
                  </div>
                ) : previewFormula.isError ? (
                  <div className="flex items-center gap-2 text-destructive" role="alert">
                    <AlertCircle className="h-4 w-4" aria-hidden="true" />
                    <span className="text-sm">Error calculating result</span>
                  </div>
                ) : (
                  <p className="text-sm text-muted-foreground italic">
                    Enter a valid formula to see the calculated time
                  </p>
                )}
              </CardContent>
            </Card>

            {/* Calculation Breakdown */}
            {previewResult?.breakdown && previewResult.breakdown.length > 0 && (
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Calculation Steps</CardTitle>
                </CardHeader>
                <CardContent>
                  <ol className="space-y-2">
                    {previewResult.breakdown.map((step, i) => (
                      <li key={i} className="text-sm flex items-start gap-2">
                        <span className="font-medium text-muted-foreground">
                          {step.step}.
                        </span>
                        <span className="flex-1">{step.description}</span>
                        <code className="bg-muted px-2 py-0.5 rounded text-xs font-mono">
                          {step.value}
                        </code>
                      </li>
                    ))}
                  </ol>
                </CardContent>
              </Card>
            )}

            {/* Test Controls */}
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-base">Test Controls</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="preview-date">Date</Label>
                  <Input
                    id="preview-date"
                    type="date"
                    value={previewDate}
                    onChange={(e) => setPreviewDate(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Location</Label>
                  <div className="text-sm text-muted-foreground">
                    {DEFAULT_LOCATION.displayName}
                  </div>
                </div>
                <Button
                  variant="outline"
                  className="w-full"
                  onClick={() => setShowWeeklyDialog(true)}
                  disabled={!formula.trim()}
                >
                  <Calendar className="h-4 w-4 mr-2" />
                  Preview Week
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>

      {/* AI Formula Generator */}
      <AIFormulaGenerator
        open={showAIGenerator}
        onOpenChange={setShowAIGenerator}
        onAccept={handleAIFormulaAccept}
        currentFormula={formula}
      />

      {/* Browse Templates Dialog */}
      <BrowseTemplatesDialog
        open={showBrowseTemplates}
        onOpenChange={setShowBrowseTemplates}
        onSelectFormula={handleTemplateSelect}
        currentZmanKey={zmanKey}
      />

      {/* Weekly Preview Dialog */}
      <WeeklyPreviewDialog
        open={showWeeklyDialog}
        onOpenChange={setShowWeeklyDialog}
        formula={formula}
        location={DEFAULT_LOCATION}
        zmanName={englishName || zman?.english_name}
      />
    </div>
  );
}
