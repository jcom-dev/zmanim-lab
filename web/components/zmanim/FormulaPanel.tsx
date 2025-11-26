'use client';

import { useEffect, useState } from 'react';
import { X, Clock, Calculator, BookOpen, Info } from 'lucide-react';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';

export interface ZmanFormula {
  method: string;
  display_name: string;
  parameters: Record<string, unknown>;
  explanation: string;
  halachic_source?: string;
}

export interface Zman {
  name: string;
  key: string;
  time: string;
  formula: ZmanFormula;
}

interface FormulaPanelProps {
  zman: Zman | null;
  open: boolean;
  onClose: () => void;
}

// Format parameter values for display
const formatParameter = (key: string, value: unknown): string => {
  if (key === 'degrees' && typeof value === 'number') {
    return `${value}° below horizon`;
  }
  if (key === 'minutes' && typeof value === 'number') {
    return `${value} minutes`;
  }
  if (key === 'hours' && typeof value === 'number') {
    return `${value} hours`;
  }
  if (key === 'base') {
    return value === 'gra' ? 'GRA (Vilna Gaon)' : value === 'mga' ? 'MGA (Magen Avraham)' : String(value);
  }
  if (key === 'from') {
    return `from ${value}`;
  }
  return `${key}: ${value}`;
};

// Custom hook for media query
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    if (media.matches !== matches) {
      setMatches(media.matches);
    }
    const listener = () => setMatches(media.matches);
    media.addEventListener('change', listener);
    return () => media.removeEventListener('change', listener);
  }, [matches, query]);

  return matches;
}

export function FormulaPanel({ zman, open, onClose }: FormulaPanelProps) {
  const isDesktop = useMediaQuery('(min-width: 768px)');

  if (!zman) return null;

  const { formula } = zman;
  const parameters = formula?.parameters || {};
  const hasParameters = Object.keys(parameters).length > 0;

  return (
    <Sheet open={open} onOpenChange={(isOpen) => !isOpen && onClose()}>
      <SheetContent
        side={isDesktop ? 'right' : 'bottom'}
        className={isDesktop ? 'w-[400px] sm:max-w-[400px]' : 'h-[70vh] max-h-[70vh] rounded-t-2xl'}
      >
        {/* Mobile drag handle */}
        {!isDesktop && (
          <div className="flex justify-center pb-4 -mt-2">
            <div className="w-12 h-1.5 bg-slate-700 rounded-full" />
          </div>
        )}

        <SheetHeader className="pb-4 border-b border-slate-700">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-500/20 rounded-lg">
              <Clock className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <SheetTitle className="text-xl">{zman.name}</SheetTitle>
              <SheetDescription className="text-lg font-semibold text-blue-400">
                {zman.time}
              </SheetDescription>
            </div>
          </div>
        </SheetHeader>

        <div className="mt-6 space-y-6 overflow-y-auto">
          {/* Method Section */}
          <section>
            <div className="flex items-center gap-2 mb-3">
              <Calculator className="w-4 h-4 text-slate-500" />
              <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wide">
                Calculation Method
              </h3>
            </div>
            <div className="bg-slate-800 rounded-lg p-4">
              <p className="text-white font-medium">
                {formula?.display_name || formula?.method || 'Standard calculation'}
              </p>
            </div>
          </section>

          {/* Parameters Section */}
          {hasParameters && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <Info className="w-4 h-4 text-slate-500" />
                <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wide">
                  Parameters
                </h3>
              </div>
              <div className="bg-slate-800 rounded-lg p-4">
                <ul className="space-y-2">
                  {Object.entries(parameters).map(([key, value]) => (
                    <li key={key} className="flex items-center gap-2 text-slate-300">
                      <span className="w-2 h-2 bg-blue-400 rounded-full" />
                      {formatParameter(key, value)}
                    </li>
                  ))}
                </ul>
              </div>
            </section>
          )}

          {/* Explanation Section */}
          {formula?.explanation && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <BookOpen className="w-4 h-4 text-slate-500" />
                <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wide">
                  Explanation
                </h3>
              </div>
              <div className="bg-slate-800 rounded-lg p-4">
                <p className="text-slate-300 leading-relaxed">
                  {formula.explanation}
                </p>
              </div>
            </section>
          )}

          {/* Halachic Source Section */}
          {formula?.halachic_source && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <BookOpen className="w-4 h-4 text-amber-500" />
                <h3 className="text-sm font-semibold text-amber-400 uppercase tracking-wide">
                  Halachic Source
                </h3>
              </div>
              <div className="bg-amber-900/20 border border-amber-700/50 rounded-lg p-4">
                <p className="text-amber-200 leading-relaxed">
                  {formula.halachic_source}
                </p>
              </div>
            </section>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
