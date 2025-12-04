'use client';

import { useMemo } from 'react';
import { tokenize, type TokenType, type Token } from '@/lib/codemirror/dsl-tokens';

interface HighlightedFormulaProps {
  formula: string;
  className?: string;
  inline?: boolean;
}

/**
 * HighlightedFormula - Displays a DSL formula with syntax highlighting
 *
 * Uses the existing DSL tokenizer from /lib/codemirror/dsl-tokens.ts
 * to provide color-coded syntax highlighting for formulas.
 *
 * @param formula - The DSL formula string to highlight
 * @param className - Additional CSS classes
 * @param inline - If true, displays inline without padding/background
 */
export function HighlightedFormula({ formula, className = '', inline = false }: HighlightedFormulaProps) {
  const tokens = useMemo(() => {
    if (!formula || formula.trim() === '') return [];
    return tokenize(formula);
  }, [formula]);

  if (!formula || formula.trim() === '') {
    return (
      <span className="text-muted-foreground italic text-sm">
        No formula defined
      </span>
    );
  }

  const baseClasses = inline
    ? 'font-mono text-sm'
    : 'font-mono text-sm p-3 bg-muted rounded-md overflow-x-auto';

  return (
    <pre className={`${baseClasses} ${className}`.trim()}>
      <code>
        {tokens.map((token, i) => (
          <span key={i} className={getTokenColorClass(token.type)}>
            {token.value}
          </span>
        ))}
      </code>
    </pre>
  );
}

/**
 * Get Tailwind CSS class for token type
 * Provides color-coding for different DSL syntax elements
 */
function getTokenColorClass(type: TokenType): string {
  switch (type) {
    case 'keyword':
      // Keywords: if, else, etc.
      return 'text-blue-600 dark:text-blue-400 font-semibold';

    case 'function':
      // Functions: solar(), proportional_hours(), midpoint()
      return 'text-purple-600 dark:text-purple-400 font-medium';

    case 'primitive':
      // Primitives: sunrise, sunset, solar_noon, etc.
      return 'text-green-600 dark:text-green-400 font-medium';

    case 'number':
      // Numbers: 16.1, 3, 72, etc.
      return 'text-orange-600 dark:text-orange-400';

    case 'duration':
      // Durations: 72min, 1hr, etc.
      return 'text-amber-600 dark:text-amber-400';

    case 'reference':
      // References: @alos_hashachar, @tzais, etc.
      return 'text-cyan-600 dark:text-cyan-400 font-medium';

    case 'operator':
      // Operators: +, -, *, /, etc.
      return 'text-gray-600 dark:text-gray-400';

    case 'bracket':
      // Brackets: (, ), {, }
      return 'text-gray-500 dark:text-gray-500';

    case 'string':
      // Strings: "summer", "winter", etc.
      return 'text-emerald-600 dark:text-emerald-400';

    case 'comment':
      // Comments: // ... or /* ... */
      return 'text-gray-500 dark:text-gray-500 italic';

    case 'unknown':
      // Unknown/unrecognized tokens
      return 'text-red-600 dark:text-red-400';

    default:
      // Default/unknown tokens
      return 'text-foreground';
  }
}

/**
 * InlineFormula - Compact inline version
 * Useful for displaying formulas in cards, lists, etc.
 */
export function InlineFormula({ formula, className }: { formula: string; className?: string }) {
  return <HighlightedFormula formula={formula} inline className={className} />;
}
