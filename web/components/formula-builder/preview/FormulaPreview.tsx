'use client';

import { CheckCircle2, XCircle, Copy } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useState } from 'react';

interface FormulaPreviewProps {
  formula: string;
  isValid: boolean;
  errors: string[];
  className?: string;
}

// Simple syntax highlighting for DSL formulas
function highlightFormula(formula: string): React.ReactNode {
  // Keywords
  const keywords = ['solar', 'shaos', 'midpoint', 'gra', 'mga', 'custom', 'before_sunrise', 'after_sunset'];
  // Primitives
  const primitives = ['sunrise', 'sunset', 'solar_noon', 'midnight', 'alos_hashachar', 'tzeis_hakochavim'];

  // Simple tokenization
  const tokens = formula.split(/(\s+|[(),@+-])/g).filter(Boolean);

  return tokens.map((token, i) => {
    const lowerToken = token.toLowerCase();

    if (keywords.includes(lowerToken)) {
      return (
        <span key={i} className="text-blue-400">
          {token}
        </span>
      );
    }
    if (primitives.includes(lowerToken)) {
      return (
        <span key={i} className="text-green-400">
          {token}
        </span>
      );
    }
    if (/^\d+(\.\d+)?$/.test(token)) {
      return (
        <span key={i} className="text-amber-400">
          {token}
        </span>
      );
    }
    if (/^\d+min$/.test(token) || /^\d+h(r)?$/.test(token)) {
      return (
        <span key={i} className="text-purple-400">
          {token}
        </span>
      );
    }
    if (token === '@') {
      return (
        <span key={i} className="text-pink-400">
          {token}
        </span>
      );
    }
    return <span key={i}>{token}</span>;
  });
}

export function FormulaPreview({
  formula,
  isValid,
  errors,
  className,
}: FormulaPreviewProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(formula);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className={cn('space-y-2', className)}>
      <div className="flex items-center justify-between">
        <label className="text-sm font-medium flex items-center gap-2">
          Generated Formula
          {isValid ? (
            <CheckCircle2 className="h-4 w-4 text-green-500" />
          ) : (
            <XCircle className="h-4 w-4 text-destructive" />
          )}
        </label>
        <Button
          variant="ghost"
          size="sm"
          onClick={handleCopy}
          className="h-7 px-2"
        >
          <Copy className="h-3 w-3 mr-1" />
          {copied ? 'Copied!' : 'Copy'}
        </Button>
      </div>

      <div
        className={cn(
          'font-mono text-sm p-3 rounded-lg border',
          isValid
            ? 'bg-muted border-border'
            : 'bg-destructive/10 border-destructive'
        )}
      >
        <code>{highlightFormula(formula)}</code>
      </div>

      {errors.length > 0 && (
        <ul className="text-sm text-destructive space-y-1">
          {errors.map((error, i) => (
            <li key={i} className="flex items-start gap-2">
              <XCircle className="h-4 w-4 mt-0.5 flex-shrink-0" />
              {error}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default FormulaPreview;
