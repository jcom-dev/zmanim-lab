import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { CoverageSelector, CoverageSelection } from '@/components/shared/CoverageSelector';
import type { OnboardingState } from '../OnboardingWizard';

interface CoverageSetupStepProps {
  state: OnboardingState;
  onUpdate: (updates: Partial<OnboardingState['data']>) => void;
  onNext: () => void;
  onBack: () => void;
}

export function CoverageSetupStep({ state, onUpdate, onNext, onBack }: CoverageSetupStepProps) {
  const [selectedItems, setSelectedItems] = useState<CoverageSelection[]>(
    state.data.coverage || []
  );

  const handleChange = (items: CoverageSelection[]) => {
    setSelectedItems(items);
    onUpdate({ coverage: items });
  };

  return (
    <div className="space-y-6">
      <CoverageSelector
        selectedItems={selectedItems}
        onChange={handleChange}
        showQuickSelect={true}
        showSelectedBadges={true}
        headerTitle="Set Your Coverage"
        headerDescription="Choose where your zmanim will be available. Add countries, states/regions, or specific cities."
      />

      {/* Note about adding more */}
      <p className="text-sm text-muted-foreground text-center">
        You can add more coverage areas from your dashboard at any time.
      </p>

      {/* Actions */}
      <div className="flex justify-between pt-4">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button onClick={onNext} disabled={selectedItems.length === 0}>
          Continue
        </Button>
      </div>
    </div>
  );
}
