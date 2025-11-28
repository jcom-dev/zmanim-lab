import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { HighlightedFormula } from '@/components/shared/HighlightedFormula';
import { ChevronDown, ChevronUp, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { OnboardingState, ZmanCustomization } from '../OnboardingWizard';

interface CustomizeZmanimStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

interface ExtendedZmanCustomization extends ZmanCustomization {
  category: 'essential' | 'optional';
  enabled: boolean;
}

// Default zmanim for GRA template with categories
const DEFAULT_ZMANIM: ExtendedZmanCustomization[] = [
  // Essential zmanim
  { key: 'alos', nameHebrew: 'עלות השחר', nameEnglish: 'Dawn', formula: 'solar(16.1, before_sunrise)', modified: false, category: 'essential', enabled: true },
  { key: 'sunrise', nameHebrew: 'נץ החמה', nameEnglish: 'Sunrise', formula: 'sunrise', modified: false, category: 'essential', enabled: true },
  { key: 'sof_zman_shema', nameHebrew: 'סוף זמן שמע', nameEnglish: 'Latest Shema', formula: 'sunrise + shaos(3, gra)', modified: false, category: 'essential', enabled: true },
  { key: 'sof_zman_tefillah', nameHebrew: 'סוף זמן תפילה', nameEnglish: 'Latest Shacharit', formula: 'sunrise + shaos(4, gra)', modified: false, category: 'essential', enabled: true },
  { key: 'chatzos', nameHebrew: 'חצות', nameEnglish: 'Midday', formula: 'solar_noon', modified: false, category: 'essential', enabled: true },
  { key: 'mincha_gedola', nameHebrew: 'מנחה גדולה', nameEnglish: 'Earliest Mincha', formula: 'solar_noon + shaos(0.5, gra)', modified: false, category: 'essential', enabled: true },
  { key: 'sunset', nameHebrew: 'שקיעה', nameEnglish: 'Sunset', formula: 'sunset', modified: false, category: 'essential', enabled: true },
  { key: 'tzais', nameHebrew: 'צאת הכוכבים', nameEnglish: 'Nightfall', formula: 'solar(8.5, after_sunset)', modified: false, category: 'essential', enabled: true },
  // Optional zmanim
  { key: 'misheyakir', nameHebrew: 'משיכיר', nameEnglish: 'Earliest Tallit', formula: 'solar(11.5, before_sunrise)', modified: false, category: 'optional', enabled: false },
  { key: 'mincha_ketana', nameHebrew: 'מנחה קטנה', nameEnglish: 'Mincha Ketana', formula: 'sunset - shaos(2.5, gra)', modified: false, category: 'optional', enabled: false },
  { key: 'plag_hamincha', nameHebrew: 'פלג המנחה', nameEnglish: 'Plag HaMincha', formula: 'sunset - shaos(1.25, gra)', modified: false, category: 'optional', enabled: false },
  { key: 'tzais_rt', nameHebrew: 'צאת ר"ת', nameEnglish: 'Nightfall (R"T)', formula: 'sunset + 72min', modified: false, category: 'optional', enabled: false },
];

export function CustomizeZmanimStep({ state, onUpdate, onNext, onBack }: CustomizeZmanimStepProps) {
  const [zmanim, setZmanim] = useState<ExtendedZmanCustomization[]>(
    (state.data.customizations as ExtendedZmanCustomization[]) || DEFAULT_ZMANIM
  );

  // Save customizations when they change
  useEffect(() => {
    onUpdate({ customizations: zmanim });
  }, [zmanim]);

  const updateZman = (key: string, field: keyof ExtendedZmanCustomization, value: string | boolean) => {
    setZmanim((prev) =>
      prev.map((z) =>
        z.key === key ? { ...z, [field]: value, modified: field !== 'enabled' ? true : z.modified } : z
      )
    );
  };

  const toggleZman = (key: string) => {
    setZmanim((prev) =>
      prev.map((z) =>
        z.key === key ? { ...z, enabled: !z.enabled } : z
      )
    );
  };

  const essentialZmanim = zmanim.filter(z => z.category === 'essential');
  const optionalZmanim = zmanim.filter(z => z.category === 'optional');
  const enabledCount = zmanim.filter(z => z.enabled).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Customize Your Zmanim</h2>
        <p className="text-muted-foreground">
          Review and adjust the times. Toggle optional zmanim on/off, and click to expand for editing.
        </p>
      </div>

      {/* Selection counter */}
      <div className="flex justify-center">
        <Badge variant="secondary" className="text-sm">
          {enabledCount} zmanim selected
        </Badge>
      </div>

      {/* Essential Zmanim */}
      <div className="space-y-3">
        <div className="flex items-center gap-2">
          <h3 className="font-semibold text-lg">Essential Zmanim</h3>
          <Badge variant="outline">{essentialZmanim.length}</Badge>
        </div>
        <p className="text-sm text-muted-foreground">
          Core times that are always included in your algorithm
        </p>
        <div className="space-y-2">
          {essentialZmanim.map((zman) => (
            <ZmanRow
              key={zman.key}
              zman={zman}
              onUpdate={(field, value) => updateZman(zman.key, field, value)}
              onToggle={() => toggleZman(zman.key)}
              isEssential
            />
          ))}
        </div>
      </div>

      {/* Optional Zmanim */}
      <div className="space-y-3">
        <div className="flex items-center gap-2">
          <h3 className="font-semibold text-lg">Optional Zmanim</h3>
          <Badge variant="outline">{optionalZmanim.filter(z => z.enabled).length}/{optionalZmanim.length}</Badge>
        </div>
        <p className="text-sm text-muted-foreground">
          Click to enable additional times for your community
        </p>
        <div className="space-y-2">
          {optionalZmanim.map((zman) => (
            <ZmanRow
              key={zman.key}
              zman={zman}
              onUpdate={(field, value) => updateZman(zman.key, field, value)}
              onToggle={() => toggleZman(zman.key)}
            />
          ))}
        </div>
      </div>

      {/* Link to advanced */}
      <div className="text-center pt-2">
        <p className="text-sm text-muted-foreground">
          Need more control? You can fine-tune every formula in the{' '}
          <span className="text-primary font-medium">Algorithm Editor</span>{' '}
          after completing setup.
        </p>
      </div>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button onClick={onNext}>Continue</Button>
      </div>
    </div>
  );
}

function ZmanRow({
  zman,
  onUpdate,
  onToggle,
  isEssential = false,
}: {
  zman: ExtendedZmanCustomization;
  onUpdate: (field: keyof ExtendedZmanCustomization, value: string | boolean) => void;
  onToggle: () => void;
  isEssential?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);

  return (
    <Card className={cn(
      'transition-all',
      !zman.enabled && !isEssential && 'opacity-60',
      zman.enabled && 'border-primary/30'
    )}>
      <CardContent className="py-3 px-4">
        <div className="flex items-start gap-3">
          {/* Toggle checkbox for optional zmanim */}
          {!isEssential && (
            <button
              type="button"
              onClick={onToggle}
              className={cn(
                'mt-1 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors',
                zman.enabled
                  ? 'bg-primary border-primary text-primary-foreground'
                  : 'border-muted-foreground/30 hover:border-primary/50'
              )}
            >
              {zman.enabled && <Check className="h-3 w-3" />}
            </button>
          )}
          {isEssential && (
            <div className="mt-1 w-5 h-5 rounded bg-primary/20 flex items-center justify-center">
              <Check className="h-3 w-3 text-primary" />
            </div>
          )}

          {/* Zman info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-medium">{zman.nameEnglish}</span>
              <span className="text-sm text-muted-foreground font-hebrew" dir="rtl">
                {zman.nameHebrew}
              </span>
              {zman.modified && (
                <Badge variant="outline" className="text-xs bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-300">
                  Modified
                </Badge>
              )}
            </div>
            {/* Formula preview with syntax highlighting */}
            <div className="mt-1">
              <HighlightedFormula formula={zman.formula} inline className="text-xs" />
            </div>
          </div>

          {/* Expand button */}
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setExpanded(!expanded)}
            className="h-8 px-2"
          >
            {expanded ? (
              <ChevronUp className="h-4 w-4" />
            ) : (
              <ChevronDown className="h-4 w-4" />
            )}
          </Button>
        </div>

        {/* Expanded edit form */}
        {expanded && (
          <div className="mt-4 pt-4 border-t space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor={`${zman.key}-english`} className="text-xs">
                  English Name
                </Label>
                <Input
                  id={`${zman.key}-english`}
                  value={zman.nameEnglish}
                  onChange={(e) => onUpdate('nameEnglish', e.target.value)}
                  className="h-9"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor={`${zman.key}-hebrew`} className="text-xs">
                  Hebrew Name
                </Label>
                <Input
                  id={`${zman.key}-hebrew`}
                  value={zman.nameHebrew}
                  onChange={(e) => onUpdate('nameHebrew', e.target.value)}
                  className="h-9 font-hebrew"
                  dir="rtl"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor={`${zman.key}-formula`} className="text-xs">
                Formula (DSL)
              </Label>
              <Input
                id={`${zman.key}-formula`}
                value={zman.formula}
                onChange={(e) => onUpdate('formula', e.target.value)}
                className="h-9 font-mono text-sm"
              />
              <p className="text-xs text-muted-foreground">
                Use the advanced editor for full syntax highlighting and validation
              </p>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
