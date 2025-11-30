'use client';

import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import {
  useMasterZmanimGrouped,
  useEventZmanimGrouped,
  useCreateZmanFromRegistry,
  MasterZman,
} from '@/lib/hooks/useZmanimList';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Search,
  Plus,
  Loader2,
  Sunrise,
  Sun,
  Sunset,
  Moon,
  Clock,
  ChevronRight,
  Sparkles,
  CalendarDays,
  Flame,
  CandlestickChart,
  Timer,
  Utensils,
} from 'lucide-react';

interface MasterZmanPickerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  existingZmanKeys: string[];
  onSuccess?: () => void;
}

// Time category config for everyday zmanim (grouped by time of day)
const TIME_CATEGORY_CONFIG: Record<
  string,
  { icon: React.ElementType; label: string; description: string }
> = {
  dawn: { icon: Sunrise, label: 'Dawn', description: 'Alos HaShachar variants' },
  sunrise: { icon: Sun, label: 'Sunrise', description: 'Sunrise and early morning' },
  morning: { icon: Clock, label: 'Morning', description: 'Shema and Tefillah times' },
  midday: { icon: Sun, label: 'Midday', description: 'Chatzos and Mincha Gedolah' },
  afternoon: { icon: Clock, label: 'Afternoon', description: 'Mincha and Plag times' },
  sunset: { icon: Sunset, label: 'Sunset', description: 'Shkiah' },
  nightfall: { icon: Moon, label: 'Nightfall', description: 'Tzeis HaKochavim variants' },
  midnight: { icon: Moon, label: 'Midnight', description: 'Chatzos Layla' },
};

// Event category config (grouped by PURPOSE like HebCal)
const EVENT_CATEGORY_CONFIG: Record<
  string,
  { icon: React.ElementType; label: string; hebrewLabel: string; description: string }
> = {
  candles: {
    icon: CandlestickChart,
    label: 'Candle Lighting',
    hebrewLabel: 'הדלקת נרות',
    description: 'Shabbos, Yom Tov, and Yom Kippur',
  },
  havdalah: {
    icon: Flame,
    label: 'Havdalah',
    hebrewLabel: 'הבדלה',
    description: 'End of Shabbos and Yom Tov',
  },
  yom_kippur: {
    icon: Moon,
    label: 'Yom Kippur',
    hebrewLabel: 'יום כיפור',
    description: 'Fast start and end times',
  },
  fast_day: {
    icon: Timer,
    label: 'Fast Days',
    hebrewLabel: 'תענית',
    description: 'Fast end times (regular fasts)',
  },
  tisha_bav: {
    icon: Moon,
    label: "Tisha B'Av",
    hebrewLabel: 'תשעה באב',
    description: 'Fast starts at sunset, ends at nightfall',
  },
  pesach: {
    icon: Utensils,
    label: 'Pesach',
    hebrewLabel: 'פסח',
    description: 'Chametz eating and burning times',
  },
};

const EVERYDAY_CATEGORY_ORDER = ['dawn', 'sunrise', 'morning', 'midday', 'afternoon', 'sunset', 'nightfall', 'midnight'];
const EVENT_CATEGORY_ORDER = ['candles', 'havdalah', 'yom_kippur', 'fast_day', 'tisha_bav', 'pesach'];

/**
 * MasterZmanPicker - Browse and add zmanim from the master registry
 *
 * Based on HebCal's approach:
 * - Everyday Zmanim: Solar calculations (same every day, different times)
 * - Event Zmanim: Grouped by PURPOSE (candles, havdalah, fast times, etc.)
 *   - No duplication: Candle lighting appears ONCE (applies to Shabbos + YT + YK)
 */
export function MasterZmanPicker({
  open,
  onOpenChange,
  existingZmanKeys,
  onSuccess,
}: MasterZmanPickerProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedZman, setSelectedZman] = useState<MasterZman | null>(null);
  const [customFormula, setCustomFormula] = useState<string>('');
  const [showCustomizeStep, setShowCustomizeStep] = useState(false);
  const [viewMode, setViewMode] = useState<'everyday' | 'events'>('everyday');

  // Fetch everyday zmanim (weekday = standard daily times)
  const { data: everydayZmanim, isLoading: loadingEveryday } = useMasterZmanimGrouped('weekday');
  // Fetch event zmanim (grouped by event_category: candles, havdalah, etc.)
  const { data: eventZmanim, isLoading: loadingEvents } = useEventZmanimGrouped();
  const createZman = useCreateZmanFromRegistry();

  const isLoading = viewMode === 'everyday' ? loadingEveryday : loadingEvents;
  const rawGroups = viewMode === 'everyday' ? everydayZmanim : eventZmanim;
  const categoryOrder = viewMode === 'everyday' ? EVERYDAY_CATEGORY_ORDER : EVENT_CATEGORY_ORDER;
  const categoryConfig = viewMode === 'everyday' ? TIME_CATEGORY_CONFIG : EVENT_CATEGORY_CONFIG;

  // Filter out already-added zmanim and apply search
  const filteredGroups = useMemo(() => {
    if (!rawGroups) return {};

    const result: Record<string, MasterZman[]> = {};
    const query = searchQuery.toLowerCase();

    for (const [category, zmanim] of Object.entries(rawGroups)) {
      const filtered = zmanim.filter((z) => {
        // Exclude already-added zmanim
        if (existingZmanKeys.includes(z.zman_key)) return false;

        // Apply search filter
        if (query) {
          return (
            z.canonical_hebrew_name.toLowerCase().includes(query) ||
            z.canonical_english_name.toLowerCase().includes(query) ||
            z.transliteration?.toLowerCase().includes(query) ||
            z.zman_key.toLowerCase().includes(query)
          );
        }
        return true;
      });

      if (filtered.length > 0) {
        result[category] = filtered;
      }
    }

    // Sort entries by category order
    const sortedResult: Record<string, MasterZman[]> = {};
    for (const cat of categoryOrder) {
      if (result[cat]) {
        sortedResult[cat] = result[cat];
      }
    }

    return sortedResult;
  }, [rawGroups, existingZmanKeys, searchQuery, categoryOrder]);

  const totalAvailable = useMemo(() => {
    return Object.values(filteredGroups).reduce((acc, arr) => acc + arr.length, 0);
  }, [filteredGroups]);

  const handleSelectZman = (zman: MasterZman) => {
    setSelectedZman(zman);
    setCustomFormula(zman.default_formula_dsl);
    setShowCustomizeStep(true);
  };

  const handleAddZman = async () => {
    if (!selectedZman) return;

    try {
      await createZman.mutateAsync({
        master_zman_id: selectedZman.id,
        formula_dsl: customFormula !== selectedZman.default_formula_dsl ? customFormula : undefined,
      });

      // Reset and close
      setSelectedZman(null);
      setCustomFormula('');
      setShowCustomizeStep(false);
      setSearchQuery('');
      onOpenChange(false);
      onSuccess?.();
    } catch (error) {
      console.error('Failed to add zman:', error);
    }
  };

  const handleBack = () => {
    setShowCustomizeStep(false);
    setSelectedZman(null);
    setCustomFormula('');
  };

  const handleClose = () => {
    setShowCustomizeStep(false);
    setSelectedZman(null);
    setCustomFormula('');
    setSearchQuery('');
    setViewMode('everyday');
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="max-w-2xl max-h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>
            {showCustomizeStep ? 'Customize Formula' : 'Add Zman from Registry'}
          </DialogTitle>
          <DialogDescription>
            {showCustomizeStep
              ? `Configure the formula for ${selectedZman?.canonical_english_name}`
              : 'Select a zman to add to your algorithm'}
          </DialogDescription>
        </DialogHeader>

        {!showCustomizeStep ? (
          <>
            {/* View Mode Tabs */}
            <Tabs value={viewMode} onValueChange={(v) => setViewMode(v as 'everyday' | 'events')}>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="everyday" className="gap-2">
                  <CalendarDays className="h-4 w-4" />
                  Everyday Zmanim
                </TabsTrigger>
                <TabsTrigger value="events" className="gap-2">
                  <Flame className="h-4 w-4" />
                  Event Zmanim
                </TabsTrigger>
              </TabsList>
            </Tabs>

            {/* Search */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search by name..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9"
              />
            </div>

            {/* Results */}
            <ScrollArea className="flex-1 min-h-0 h-[400px]">
              {isLoading ? (
                <div className="flex justify-center py-8">
                  <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                </div>
              ) : totalAvailable === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  {searchQuery ? (
                    <p>No matching zmanim found</p>
                  ) : (
                    <p>All available zmanim have been added</p>
                  )}
                </div>
              ) : (
                <Accordion type="multiple" defaultValue={[]} className="w-full">
                  {Object.entries(filteredGroups).map(([category, zmanim]) => {
                    const config = categoryConfig[category] || {
                      icon: Clock,
                      label: category,
                      description: '',
                    };
                    const Icon = config.icon;

                    return (
                      <AccordionItem key={category} value={category}>
                        <AccordionTrigger className="hover:no-underline">
                          <div className="flex items-center gap-3">
                            <Icon className="h-4 w-4 text-muted-foreground" />
                            <div className="text-left">
                              <span className="font-medium">{config.label}</span>
                              {'hebrewLabel' in config && (
                                <span className="text-muted-foreground ml-2 text-sm">
                                  {(config as typeof EVENT_CATEGORY_CONFIG[string]).hebrewLabel}
                                </span>
                              )}
                            </div>
                            <Badge variant="outline" className="text-xs ml-auto mr-2">
                              {zmanim.length}
                            </Badge>
                          </div>
                        </AccordionTrigger>
                        <AccordionContent>
                          {'description' in config && config.description && (
                            <p className="text-xs text-muted-foreground mb-2 pl-7">
                              {config.description}
                            </p>
                          )}
                          <div className="space-y-1 pl-7">
                            {zmanim.map((zman) => (
                              <button
                                key={zman.id}
                                onClick={() => handleSelectZman(zman)}
                                className="w-full text-left p-3 rounded-lg border border-transparent hover:border-primary/30 hover:bg-primary/5 transition-colors"
                              >
                                <div className="flex items-center justify-between">
                                  <div>
                                    <div className="font-medium">
                                      {zman.canonical_hebrew_name}
                                      <span className="text-muted-foreground mx-2">•</span>
                                      {zman.canonical_english_name}
                                    </div>
                                    {zman.description && (
                                      <p className="text-xs text-muted-foreground mt-0.5">
                                        {zman.description}
                                      </p>
                                    )}
                                  </div>
                                  <ChevronRight className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                                </div>
                                {zman.tags && zman.tags.length > 0 && (
                                  <div className="flex gap-1 mt-2">
                                    {zman.tags.slice(0, 3).map((tag) => (
                                      <Badge
                                        key={tag.id}
                                        variant="secondary"
                                        className="text-xs"
                                      >
                                        {tag.display_name_english}
                                      </Badge>
                                    ))}
                                  </div>
                                )}
                              </button>
                            ))}
                          </div>
                        </AccordionContent>
                      </AccordionItem>
                    );
                  })}
                </Accordion>
              )}
            </ScrollArea>

            <div className="text-xs text-muted-foreground text-center pt-2 border-t">
              Can&apos;t find what you need?{' '}
              <button className="text-primary hover:underline">
                Request a new zman
              </button>
            </div>
          </>
        ) : (
          /* Customize Step */
          <div className="space-y-4">
            {/* Name (read-only) */}
            <div className="p-4 bg-muted rounded-lg">
              <div className="text-lg font-semibold">
                {selectedZman?.canonical_hebrew_name}
                <span className="text-muted-foreground mx-2">•</span>
                {selectedZman?.canonical_english_name}
              </div>
              {selectedZman?.description && (
                <p className="text-sm text-muted-foreground mt-1">
                  {selectedZman.description}
                </p>
              )}
              {selectedZman?.halachic_notes && (
                <p className="text-xs text-muted-foreground mt-2 italic">
                  {selectedZman.halachic_notes}
                </p>
              )}
            </div>

            {/* Formula */}
            <div className="space-y-2">
              <Label htmlFor="formula">Formula (DSL)</Label>
              <Textarea
                id="formula"
                value={customFormula}
                onChange={(e) => setCustomFormula(e.target.value)}
                className="font-mono text-sm h-24"
                placeholder="Enter formula..."
              />
              {customFormula !== selectedZman?.default_formula_dsl && (
                <div className="flex items-center gap-2">
                  <Sparkles className="h-3 w-3 text-primary" />
                  <span className="text-xs text-primary">Custom formula</span>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setCustomFormula(selectedZman?.default_formula_dsl || '')}
                    className="text-xs h-6"
                  >
                    Reset to default
                  </Button>
                </div>
              )}
            </div>

            <DialogFooter className="flex gap-2">
              <Button variant="outline" onClick={handleBack}>
                Back
              </Button>
              <Button onClick={handleAddZman} disabled={createZman.isPending}>
                {createZman.isPending ? (
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                ) : (
                  <Plus className="h-4 w-4 mr-2" />
                )}
                Add Zman
              </Button>
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
