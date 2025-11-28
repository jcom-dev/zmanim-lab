import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { OnboardingState } from '../OnboardingWizard';

interface TemplateSelectionStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

interface Template {
  id: string;
  name: string;
  nameHebrew: string;
  description: string;
  previewTimes: { name: string; time: string }[];
}

const TEMPLATES: Template[] = [
  {
    id: 'gra',
    name: 'GRA Standard',
    nameHebrew: 'גר"א סטנדרטי',
    description: 'Based on the Vilna Gaon. Uses sunrise to sunset for proportional hours. Most widely used in Israel and by many Ashkenazi communities.',
    previewTimes: [
      { name: 'Alos HaShachar', time: '5:12' },
      { name: 'Sunrise', time: '6:32' },
      { name: 'Latest Shema', time: '9:28' },
      { name: 'Sunset', time: '17:43' },
      { name: 'Tzeis', time: '18:12' },
    ],
  },
  {
    id: 'mga',
    name: 'Magen Avraham',
    nameHebrew: 'מגן אברהם',
    description: 'Uses dawn to nightfall (72 minutes) for proportional hours. Common in Chabad communities and some Sephardic traditions.',
    previewTimes: [
      { name: 'Alos HaShachar', time: '5:20' },
      { name: 'Sunrise', time: '6:32' },
      { name: 'Latest Shema', time: '9:04' },
      { name: 'Sunset', time: '17:43' },
      { name: 'Tzeis', time: '18:55' },
    ],
  },
  {
    id: 'rabbeinu_tam',
    name: 'Rabbeinu Tam',
    nameHebrew: 'רבינו תם',
    description: 'Nightfall is 72 minutes after sunset. Used for stringent practices like ending Shabbat.',
    previewTimes: [
      { name: 'Alos HaShachar', time: '5:12' },
      { name: 'Sunrise', time: '6:32' },
      { name: 'Latest Shema', time: '9:28' },
      { name: 'Sunset', time: '17:43' },
      { name: 'Tzeis (RT)', time: '18:55' },
    ],
  },
  {
    id: 'custom',
    name: 'Start from Scratch',
    nameHebrew: 'התחל מאפס',
    description: 'Build your own algorithm from the ground up. Recommended for advanced users or unique minhagim.',
    previewTimes: [],
  },
];

export function TemplateSelectionStep({ state, onUpdate, onNext, onBack }: TemplateSelectionStepProps) {
  const selectedTemplate = state.data.template;

  const handleSelect = (templateId: string) => {
    onUpdate({ template: templateId });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Choose Your Template</h2>
        <p className="text-muted-foreground">
          Select a calculation method as your starting point. You can customize everything in the next step.
        </p>
      </div>

      {/* Template cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {TEMPLATES.map((template) => (
          <TemplateCard
            key={template.id}
            template={template}
            selected={selectedTemplate === template.id}
            onSelect={() => handleSelect(template.id)}
          />
        ))}
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
    </div>
  );
}

function TemplateCard({
  template,
  selected,
  onSelect,
}: {
  template: Template;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        'text-left p-4 rounded-lg border-2 transition-all',
        selected
          ? 'border-primary bg-primary/5 ring-2 ring-primary/20'
          : 'border-border hover:border-primary/50'
      )}
    >
      <div className="flex justify-between items-start mb-2">
        <div>
          <h3 className="font-semibold">{template.name}</h3>
          <p className="text-sm text-muted-foreground" dir="rtl">{template.nameHebrew}</p>
        </div>
        {selected && (
          <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center">
            <CheckIcon className="w-4 h-4 text-primary-foreground" />
          </div>
        )}
      </div>

      <p className="text-sm text-muted-foreground mb-3">
        {template.description}
      </p>

      {template.previewTimes.length > 0 && (
        <div className="mt-3 pt-3 border-t border-border">
          <p className="text-xs font-medium text-muted-foreground mb-2">Preview (today):</p>
          <div className="space-y-1">
            {template.previewTimes.slice(0, 4).map((t) => (
              <div key={t.name} className="flex justify-between text-xs">
                <span className="text-muted-foreground">{t.name}</span>
                <span className="font-mono">{t.time}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </button>
  );
}

function CheckIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}
