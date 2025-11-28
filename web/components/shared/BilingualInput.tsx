'use client';

import { useState, useCallback } from 'react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';
import { CheckCircle2, AlertCircle } from 'lucide-react';

interface BilingualInputProps {
  nameHebrew: string;
  nameEnglish: string;
  transliteration?: string;
  onHebrewChange: (value: string) => void;
  onEnglishChange: (value: string) => void;
  onTransliterationChange?: (value: string) => void;
  errors?: {
    name_hebrew?: string;
    name_english?: string;
    transliteration?: string;
  };
  disabled?: boolean;
  className?: string;
}

/**
 * Checks if a string contains Hebrew characters (U+0590-U+05FF)
 */
function containsHebrew(str: string): boolean {
  return /[\u0590-\u05FF]/.test(str);
}

/**
 * Counts Hebrew characters in a string
 */
function countHebrewChars(str: string): number {
  return (str.match(/[\u0590-\u05FF]/g) || []).length;
}

/**
 * BilingualInput - Input component for Hebrew and English zman names
 *
 * Features:
 * - Side-by-side Hebrew and English input fields
 * - RTL direction for Hebrew input
 * - Hebrew character validation indicator
 * - Optional transliteration field
 */
export function BilingualInput({
  nameHebrew,
  nameEnglish,
  transliteration,
  onHebrewChange,
  onEnglishChange,
  onTransliterationChange,
  errors,
  disabled = false,
  className,
}: BilingualInputProps) {
  const [hebrewFocused, setHebrewFocused] = useState(false);
  const hasHebrew = containsHebrew(nameHebrew);
  const hebrewCharCount = countHebrewChars(nameHebrew);

  const handleHebrewChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onHebrewChange(e.target.value);
    },
    [onHebrewChange]
  );

  const handleEnglishChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onEnglishChange(e.target.value);
    },
    [onEnglishChange]
  );

  const handleTransliterationChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onTransliterationChange?.(e.target.value);
    },
    [onTransliterationChange]
  );

  return (
    <div className={cn('space-y-4', className)}>
      {/* Hebrew and English side by side */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Hebrew Name */}
        <div className="space-y-2">
          <Label htmlFor="name_hebrew" className="flex items-center justify-between">
            <span>
              Hebrew Name <span className="text-destructive">*</span>
            </span>
            <span className="text-xs text-muted-foreground font-hebrew">שם בעברית</span>
          </Label>
          <div className="relative">
            <Input
              id="name_hebrew"
              dir="rtl"
              className={cn(
                'font-hebrew text-right pr-10',
                errors?.name_hebrew && 'border-destructive'
              )}
              value={nameHebrew}
              onChange={handleHebrewChange}
              onFocus={() => setHebrewFocused(true)}
              onBlur={() => setHebrewFocused(false)}
              placeholder="עלות השחר"
              disabled={disabled}
            />
            {/* Validation indicator */}
            <div className="absolute left-2 top-1/2 -translate-y-1/2">
              {nameHebrew.length > 0 && (
                hasHebrew ? (
                  <CheckCircle2 className="h-4 w-4 text-green-500" />
                ) : (
                  <AlertCircle className="h-4 w-4 text-destructive" />
                )
              )}
            </div>
          </div>
          {/* Character count / validation status */}
          <div className="flex justify-between text-xs">
            <span className={cn(
              errors?.name_hebrew ? 'text-destructive' : 'text-muted-foreground'
            )}>
              {errors?.name_hebrew || (
                hebrewFocused && nameHebrew.length > 0 && !hasHebrew
                  ? 'Must contain Hebrew characters (א-ת)'
                  : ''
              )}
            </span>
            <span className="text-muted-foreground">
              {hebrewCharCount} Hebrew chars
            </span>
          </div>
        </div>

        {/* English Name */}
        <div className="space-y-2">
          <Label htmlFor="name_english" className="flex items-center justify-between">
            <span>
              English Name <span className="text-destructive">*</span>
            </span>
          </Label>
          <Input
            id="name_english"
            className={cn(
              errors?.name_english && 'border-destructive'
            )}
            value={nameEnglish}
            onChange={handleEnglishChange}
            placeholder="Dawn"
            disabled={disabled}
          />
          {errors?.name_english && (
            <p className="text-xs text-destructive">{errors.name_english}</p>
          )}
        </div>
      </div>

      {/* Transliteration (optional) */}
      {onTransliterationChange && (
        <div className="space-y-2">
          <Label htmlFor="transliteration" className="flex items-center gap-2">
            <span>Transliteration</span>
            <span className="text-xs text-muted-foreground">(optional)</span>
          </Label>
          <Input
            id="transliteration"
            className={cn(
              errors?.transliteration && 'border-destructive'
            )}
            value={transliteration || ''}
            onChange={handleTransliterationChange}
            placeholder="Alos HaShachar"
            disabled={disabled}
          />
          <p className="text-xs text-muted-foreground">
            Phonetic pronunciation for non-Hebrew speakers
          </p>
        </div>
      )}
    </div>
  );
}

export default BilingualInput;
