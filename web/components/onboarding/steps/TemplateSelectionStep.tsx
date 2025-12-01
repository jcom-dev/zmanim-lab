'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Search, Users, Sparkles, Check } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import type { OnboardingState } from '../OnboardingWizard';

interface TemplateSelectionStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

interface PublisherInfo {
  id: string;
  name: string;
  organization_name?: string;
  zmanim_count: number;
}

// Standard zmanim included in the default template
const DEFAULT_ZMANIM_PREVIEW = [
  'Alos HaShachar (Dawn)',
  'Sunrise',
  'Latest Shema',
  'Latest Tefillah',
  'Midday (Chatzos)',
  'Earliest Mincha',
  'Sunset',
  'Nightfall (Tzeis)',
  'Candle Lighting',
  'Shabbos Ends',
];

export function TemplateSelectionStep({ state, onUpdate, onNext, onBack }: TemplateSelectionStepProps) {
  const selectedTemplate = state.data.template;
  const [showPublisherBrowser, setShowPublisherBrowser] = useState(false);
  const [publishers, setPublishers] = useState<PublisherInfo[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [selectedPublisher, setSelectedPublisher] = useState<PublisherInfo | null>(null);

  const handleSelect = (templateId: string) => {
    if (templateId === 'copy_publisher') {
      setShowPublisherBrowser(true);
      return;
    }
    onUpdate({ template: templateId });
  };

  const handleSearchPublishers = async (query: string) => {
    setSearchQuery(query);
    if (query.length < 2) {
      setPublishers([]);
      return;
    }

    setLoading(true);
    try {
      const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiBase}/api/v1/publishers?q=${encodeURIComponent(query)}&has_algorithm=true`);
      if (response.ok) {
        const data = await response.json();
        // Standard API response: { data: [...], meta: {...} }
        setPublishers(data.data || []);
      }
    } catch (err) {
      console.error('Failed to search publishers:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectPublisher = (publisher: PublisherInfo) => {
    setSelectedPublisher(publisher);
    onUpdate({
      template: 'copy_publisher',
      sourcePublisherId: publisher.id,
    } as any);
    setShowPublisherBrowser(false);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Choose Your Starting Point</h2>
        <p className="text-muted-foreground">
          Start with sensible defaults or copy from an existing publisher
        </p>
      </div>

      {/* Two options */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Option 1: Default */}
        <button
          type="button"
          onClick={() => handleSelect('default')}
          className={cn(
            'text-left p-5 rounded-lg border-2 transition-all',
            selectedTemplate === 'default'
              ? 'border-primary bg-primary/5 ring-2 ring-primary/20'
              : 'border-border hover:border-primary/50'
          )}
        >
          <div className="flex justify-between items-start mb-3">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                <Sparkles className="h-5 w-5 text-primary" />
              </div>
              <div>
                <h3 className="font-semibold text-lg">Standard Defaults</h3>
                <p className="text-sm text-muted-foreground" dir="rtl">ברירות מחדל סטנדרטיות</p>
              </div>
            </div>
            {selectedTemplate === 'default' && (
              <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center">
                <Check className="w-4 h-4 text-primary-foreground" />
              </div>
            )}
          </div>

          <p className="text-sm text-muted-foreground mb-4">
            Start with the most commonly used zmanim. Based on GRA calculations with standard times for Shabbos and holidays.
          </p>

          <div className="pt-3 border-t border-border">
            <p className="text-xs font-medium text-muted-foreground mb-2">Includes:</p>
            <div className="flex flex-wrap gap-1">
              {DEFAULT_ZMANIM_PREVIEW.slice(0, 6).map((name) => (
                <span
                  key={name}
                  className="px-2 py-0.5 text-xs bg-muted rounded"
                >
                  {name}
                </span>
              ))}
              <span className="px-2 py-0.5 text-xs text-muted-foreground">
                +{DEFAULT_ZMANIM_PREVIEW.length - 6} more
              </span>
            </div>
          </div>
        </button>

        {/* Option 2: Copy from Publisher */}
        <button
          type="button"
          onClick={() => handleSelect('copy_publisher')}
          className={cn(
            'text-left p-5 rounded-lg border-2 transition-all',
            selectedTemplate === 'copy_publisher'
              ? 'border-primary bg-primary/5 ring-2 ring-primary/20'
              : 'border-border hover:border-primary/50'
          )}
        >
          <div className="flex justify-between items-start mb-3">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
                <Users className="h-5 w-5 text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <h3 className="font-semibold text-lg">Copy from Publisher</h3>
                <p className="text-sm text-muted-foreground" dir="rtl">העתק ממפרסם</p>
              </div>
            </div>
            {selectedTemplate === 'copy_publisher' && (
              <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center">
                <Check className="w-4 h-4 text-primary-foreground" />
              </div>
            )}
          </div>

          <p className="text-sm text-muted-foreground mb-4">
            Browse and copy the complete algorithm from another publisher. Great for starting with a trusted community&apos;s settings.
          </p>

          {/* Show selected publisher */}
          {selectedPublisher ? (
            <div className="pt-3 border-t border-border">
              <p className="text-xs font-medium text-muted-foreground mb-1">Selected Publisher:</p>
              <p className="text-sm font-medium">{selectedPublisher.name}</p>
              {selectedPublisher.organization_name && (
                <p className="text-xs text-muted-foreground">{selectedPublisher.organization_name}</p>
              )}
              <p className="text-xs text-muted-foreground mt-1">{selectedPublisher.zmanim_count} zmanim configured</p>
            </div>
          ) : (
            <div className="pt-3 border-t border-border">
              <p className="text-xs text-muted-foreground">
                Click to search and select a publisher
              </p>
            </div>
          )}
        </button>
      </div>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button onClick={onNext} disabled={!selectedTemplate}>
          Continue
        </Button>
      </div>

      {/* Publisher Browser Dialog */}
      <Dialog open={showPublisherBrowser} onOpenChange={setShowPublisherBrowser}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Copy from Publisher</DialogTitle>
            <DialogDescription>
              Search for a publisher to copy their algorithm settings
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search publishers..."
                value={searchQuery}
                onChange={(e) => handleSearchPublishers(e.target.value)}
                className="pl-10"
              />
            </div>

            {loading && (
              <div className="text-center py-4 text-muted-foreground">
                Searching...
              </div>
            )}

            {!loading && publishers.length > 0 && (
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {publishers.map((publisher) => (
                  <button
                    key={publisher.id}
                    onClick={() => handleSelectPublisher(publisher)}
                    className="w-full text-left p-3 rounded-lg border border-border hover:border-primary/50 transition-colors"
                  >
                    <div className="font-medium">{publisher.name}</div>
                    {publisher.organization_name && (
                      <div className="text-sm text-muted-foreground">{publisher.organization_name}</div>
                    )}
                    <div className="text-xs text-muted-foreground mt-1">
                      {publisher.zmanim_count} zmanim configured
                    </div>
                  </button>
                ))}
              </div>
            )}

            {!loading && searchQuery.length >= 2 && publishers.length === 0 && (
              <div className="text-center py-4 text-muted-foreground">
                No publishers found
              </div>
            )}

            {!loading && searchQuery.length < 2 && (
              <div className="text-center py-4 text-muted-foreground">
                Enter at least 2 characters to search
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
