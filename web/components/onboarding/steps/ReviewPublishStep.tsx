import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { OnboardingState } from '../OnboardingWizard';

interface ReviewPublishStepProps {
  state: OnboardingState;
  onBack: () => void;
  onComplete: () => void;
}

const TEMPLATE_NAMES: Record<string, { en: string; he: string }> = {
  gra: { en: 'GRA Standard', he: 'גר"א סטנדרטי' },
  mga: { en: 'Magen Avraham', he: 'מגן אברהם' },
  rabbeinu_tam: { en: 'Rabbeinu Tam', he: 'רבינו תם' },
  custom: { en: 'Custom', he: 'מותאם אישית' },
};

export function ReviewPublishStep({ state, onBack, onComplete }: ReviewPublishStepProps) {
  const [publishing, setPublishing] = useState(false);
  const [published, setPublished] = useState(false);

  const template = state.data.template || 'custom';
  const customizations = state.data.customizations || [];
  const coverage = state.data.coverage || [];

  const handlePublish = async () => {
    setPublishing(true);
    try {
      await onComplete();
      setPublished(true);
    } catch (error) {
      console.error('Failed to publish:', error);
    } finally {
      setPublishing(false);
    }
  };

  if (published) {
    return (
      <div className="text-center space-y-6 py-8">
        {/* Success animation */}
        <div className="flex justify-center">
          <div className="w-20 h-20 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center animate-bounce">
            <CheckIcon className="w-10 h-10 text-green-600" />
          </div>
        </div>

        <div className="space-y-2">
          <h2 className="text-2xl font-bold text-green-600 dark:text-green-400">Congratulations!</h2>
          <p className="text-lg text-muted-foreground">
            Your algorithm is now live!
          </p>
          <p className="text-muted-foreground" dir="rtl">
            מזל טוב! האלגוריתם שלך פעיל
          </p>
        </div>

        <div className="bg-muted rounded-lg p-4 max-w-md mx-auto">
          <h3 className="font-medium mb-2">What&apos;s next?</h3>
          <ul className="text-sm text-muted-foreground text-left space-y-1">
            <li>• Add more zmanim to your algorithm</li>
            <li>• Expand your coverage to more cities</li>
            <li>• Customize names and descriptions</li>
            <li>• Share your times with your community</li>
          </ul>
        </div>

        <Button size="lg" asChild>
          <a href="/publisher/algorithm">Go to Dashboard</a>
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">Review & Publish</h2>
        <p className="text-muted-foreground">
          Review your settings before publishing your algorithm.
        </p>
      </div>

      {/* Summary sections */}
      <div className="space-y-4">
        {/* Template */}
        <SummarySection title="Template">
          <div className="flex items-center gap-2">
            <span className="font-medium">{TEMPLATE_NAMES[template]?.en}</span>
            <span className="text-muted-foreground" dir="rtl">
              {TEMPLATE_NAMES[template]?.he}
            </span>
          </div>
        </SummarySection>

        {/* Zmanim */}
        <SummarySection title="Zmanim">
          <div className="grid grid-cols-2 gap-2 text-sm">
            {customizations.slice(0, 6).map((z) => (
              <div key={z.key} className="flex justify-between">
                <span>{z.nameEnglish}</span>
                {z.modified && (
                  <span className="text-xs text-amber-600">(customized)</span>
                )}
              </div>
            ))}
            {customizations.length > 6 && (
              <div className="text-muted-foreground">
                +{customizations.length - 6} more
              </div>
            )}
          </div>
        </SummarySection>

        {/* Coverage */}
        <SummarySection title="Coverage">
          <div className="flex flex-wrap gap-2">
            {coverage.map((c) => (
              <span
                key={c.id}
                className="px-2 py-1 text-sm bg-muted rounded"
              >
                {c.name}
              </span>
            ))}
          </div>
        </SummarySection>
      </div>

      {/* Preview note */}
      <div className="bg-primary/10 rounded-lg p-4 text-sm">
        <div className="flex items-start gap-2">
          <InfoIcon className="w-5 h-5 text-primary shrink-0 mt-0.5" />
          <div>
            <p className="font-medium text-foreground">
              Ready to publish?
            </p>
            <p className="text-muted-foreground">
              Your algorithm will immediately be available for users in your covered cities.
              You can make changes at any time from your dashboard.
            </p>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button
          onClick={handlePublish}
          disabled={publishing}
          className="px-8 bg-green-600 hover:bg-green-700"
        >
          {publishing ? (
            <>
              <LoaderIcon className="mr-2 h-4 w-4 animate-spin" />
              Publishing...
            </>
          ) : (
            <>
              <RocketIcon className="mr-2 h-4 w-4" />
              Publish Algorithm
            </>
          )}
        </Button>
      </div>
    </div>
  );
}

function SummarySection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="border rounded-lg p-4">
      <h3 className="text-sm font-medium text-muted-foreground mb-2">{title}</h3>
      {children}
    </div>
  );
}

function CheckIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

function InfoIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="10" />
      <path d="M12 16v-4M12 8h.01" />
    </svg>
  );
}

function LoaderIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M21 12a9 9 0 1 1-6.219-8.56" />
    </svg>
  );
}

function RocketIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z" />
      <path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z" />
      <path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5" />
    </svg>
  );
}
