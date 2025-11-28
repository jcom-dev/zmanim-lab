import { useState, useEffect } from 'react';
import { WizardProgress } from './WizardProgress';
import { WelcomeStep } from './steps/WelcomeStep';
import { TemplateSelectionStep } from './steps/TemplateSelectionStep';
import { CustomizeZmanimStep } from './steps/CustomizeZmanimStep';
import { CoverageSetupStep } from './steps/CoverageSetupStep';
import { ReviewPublishStep } from './steps/ReviewPublishStep';

export interface OnboardingState {
  currentStep: number;
  completedSteps: number[];
  data: {
    template?: string;
    customizations?: ZmanCustomization[];
    coverage?: CoverageSelection[];
  };
  startedAt: string;
  lastUpdatedAt: string;
}

export interface ZmanCustomization {
  key: string;
  nameHebrew: string;
  nameEnglish: string;
  formula: string;
  modified: boolean;
}

export interface CoverageSelection {
  type: 'city' | 'region' | 'country';
  id: string;
  name: string;
}

interface StepDefinition {
  id: string;
  title: string;
  titleHebrew: string;
}

const STEPS: StepDefinition[] = [
  { id: 'welcome', title: 'Welcome', titleHebrew: 'ברוכים הבאים' },
  { id: 'template', title: 'Choose Template', titleHebrew: 'בחר תבנית' },
  { id: 'customize', title: 'Customize Zmanim', titleHebrew: 'התאם זמנים' },
  { id: 'coverage', title: 'Set Coverage', titleHebrew: 'הגדר כיסוי' },
  { id: 'review', title: 'Review & Publish', titleHebrew: 'בדוק ופרסם' },
];

interface OnboardingWizardProps {
  publisherId?: string;
  onComplete?: () => void;
  onSkip?: () => void;
}

export function OnboardingWizard({ publisherId, onComplete, onSkip }: OnboardingWizardProps) {
  const [state, setState] = useState<OnboardingState>({
    currentStep: 0,
    completedSteps: [],
    data: {},
    startedAt: new Date().toISOString(),
    lastUpdatedAt: new Date().toISOString(),
  });
  const [loading, setLoading] = useState(true);

  // Load saved state on mount
  useEffect(() => {
    fetchOnboardingState();
  }, []);

  const fetchOnboardingState = async () => {
    try {
      const response = await fetch('/api/v1/publisher/onboarding', {
        headers: { 'X-Publisher-Id': publisherId || '' },
      });
      if (response.ok) {
        const data = await response.json();
        if (data) {
          setState(data);
        }
      }
    } catch (error) {
      console.error('Failed to fetch onboarding state:', error);
    } finally {
      setLoading(false);
    }
  };

  const saveState = async (newState: OnboardingState) => {
    setState(newState);
    try {
      await fetch('/api/v1/publisher/onboarding', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'X-Publisher-Id': publisherId || '',
        },
        body: JSON.stringify(newState),
      });
    } catch (error) {
      console.error('Failed to save onboarding state:', error);
    }
  };

  const goToStep = (step: number) => {
    const newState = {
      ...state,
      currentStep: step,
      lastUpdatedAt: new Date().toISOString(),
    };
    saveState(newState);
  };

  const updateData = (updates: Partial<OnboardingState['data']>) => {
    const newState = {
      ...state,
      data: { ...state.data, ...updates },
      lastUpdatedAt: new Date().toISOString(),
    };
    saveState(newState);
  };

  const markStepComplete = (step: number) => {
    if (!state.completedSteps.includes(step)) {
      const newState = {
        ...state,
        completedSteps: [...state.completedSteps, step],
        lastUpdatedAt: new Date().toISOString(),
      };
      saveState(newState);
    }
  };

  const handleNext = () => {
    markStepComplete(state.currentStep);
    if (state.currentStep < STEPS.length - 1) {
      goToStep(state.currentStep + 1);
    }
  };

  const handleBack = () => {
    if (state.currentStep > 0) {
      goToStep(state.currentStep - 1);
    }
  };

  const handleSkip = async () => {
    try {
      await fetch('/api/v1/publisher/onboarding/skip', {
        method: 'POST',
        headers: { 'X-Publisher-Id': publisherId || '' },
      });
      onSkip?.();
    } catch (error) {
      console.error('Failed to skip onboarding:', error);
    }
  };

  const handleComplete = async () => {
    try {
      await fetch('/api/v1/publisher/onboarding/complete', {
        method: 'POST',
        headers: { 'X-Publisher-Id': publisherId || '' },
      });
      onComplete?.();
    } catch (error) {
      console.error('Failed to complete onboarding:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  const stepProps = {
    state,
    onUpdate: updateData,
    onNext: handleNext,
    onBack: handleBack,
    onSkip: handleSkip,
  };

  return (
    <div className="max-w-4xl mx-auto py-8 px-4">
      <WizardProgress
        steps={STEPS}
        currentStep={state.currentStep}
        completedSteps={state.completedSteps}
      />

      <div className="mt-8 bg-card rounded-lg shadow-lg p-6 min-h-[400px]">
        {state.currentStep === 0 && <WelcomeStep {...stepProps} />}
        {state.currentStep === 1 && <TemplateSelectionStep {...stepProps} />}
        {state.currentStep === 2 && <CustomizeZmanimStep {...stepProps} />}
        {state.currentStep === 3 && <CoverageSetupStep {...stepProps} />}
        {state.currentStep === 4 && (
          <ReviewPublishStep {...stepProps} onComplete={handleComplete} />
        )}
      </div>
    </div>
  );
}
