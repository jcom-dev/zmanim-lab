/**
 * DSL Context Helper - Detects cursor context in DSL formulas
 * Epic 5, Story 5.2: Contextual Tooltips in DSL Editor
 */

export type DSLContext =
  | { type: 'empty_editor' }
  | { type: 'solar_degrees'; position: number }
  | { type: 'solar_direction'; position: number }
  | { type: 'proportional_hours'; position: number }
  | { type: 'proportional_base'; position: number }
  | { type: 'midpoint_first'; position: number }
  | { type: 'midpoint_second'; position: number }
  | { type: 'min_max_first'; position: number; func: 'min' | 'max' }
  | { type: 'min_max_second'; position: number; func: 'min' | 'max' }
  | { type: 'reference'; position: number }
  | { type: 'primitive' }
  | { type: 'operator'; afterValue: boolean }
  | { type: 'unknown' };

/**
 * Count open/close parentheses to find nesting level
 */
function countParens(text: string): { open: number; close: number } {
  let open = 0;
  let close = 0;
  for (const char of text) {
    if (char === '(') open++;
    if (char === ')') close++;
  }
  return { open, close };
}

/**
 * Find the innermost function context at cursor position
 */
function findInnermostFunction(formula: string, cursorPos: number): {
  funcName: string;
  paramIndex: number;
  funcStart: number;
} | null {
  const beforeCursor = formula.slice(0, cursorPos);

  // Track parenthesis depth and find the last open function
  let depth = 0;
  let lastFuncMatch: { funcName: string; funcStart: number; openPos: number } | null = null;
  let commaCount = 0;
  let commaPositions: number[] = [];

  // Scan backwards from cursor to find our function context
  for (let i = beforeCursor.length - 1; i >= 0; i--) {
    const char = beforeCursor[i];

    if (char === ')') {
      depth++;
    } else if (char === '(') {
      if (depth > 0) {
        depth--;
      } else {
        // This is our opening paren - look for function name before it
        const textBefore = beforeCursor.slice(0, i);
        const funcMatch = textBefore.match(/(\w+)\s*$/);
        if (funcMatch) {
          const funcName = funcMatch[1].toLowerCase();
          // Count commas between this paren and cursor (at our level)
          const textAfterParen = beforeCursor.slice(i + 1);
          commaCount = 0;
          let nestedDepth = 0;
          for (const c of textAfterParen) {
            if (c === '(') nestedDepth++;
            else if (c === ')') nestedDepth--;
            else if (c === ',' && nestedDepth === 0) commaCount++;
          }
          return { funcName, paramIndex: commaCount, funcStart: i - funcMatch[1].length };
        }
        return null;
      }
    }
  }

  return null;
}

/**
 * Get DSL context based on cursor position
 */
export function getDSLContext(formula: string, cursorPos: number): DSLContext {
  // Empty editor
  if (!formula.trim()) {
    return { type: 'empty_editor' };
  }

  const beforeCursor = formula.slice(0, cursorPos);

  // Check if we're typing a reference (@...)
  if (beforeCursor.match(/@\w*$/)) {
    return { type: 'reference', position: cursorPos };
  }

  // Find innermost function context
  const funcContext = findInnermostFunction(formula, cursorPos);

  if (funcContext) {
    const { funcName, paramIndex } = funcContext;

    // solar(degrees, direction)
    if (funcName === 'solar') {
      if (paramIndex === 0) {
        return { type: 'solar_degrees', position: cursorPos };
      } else if (paramIndex === 1) {
        return { type: 'solar_direction', position: cursorPos };
      }
    }

    // proportional_hours(hours, base)
    if (funcName === 'proportional_hours') {
      if (paramIndex === 0) {
        return { type: 'proportional_hours', position: cursorPos };
      } else if (paramIndex === 1) {
        return { type: 'proportional_base', position: cursorPos };
      }
    }

    // midpoint(time1, time2)
    if (funcName === 'midpoint') {
      if (paramIndex === 0) {
        return { type: 'midpoint_first', position: cursorPos };
      } else if (paramIndex === 1) {
        return { type: 'midpoint_second', position: cursorPos };
      }
    }

    // min(time1, time2) or max(time1, time2)
    if (funcName === 'min' || funcName === 'max') {
      if (paramIndex === 0) {
        return { type: 'min_max_first', position: cursorPos, func: funcName };
      } else if (paramIndex === 1) {
        return { type: 'min_max_second', position: cursorPos, func: funcName };
      }
    }
  }

  // Check if we're after a value (might want operator)
  const afterValue = beforeCursor.match(/(\w+|\d+min?|\))\s*$/);
  if (afterValue) {
    return { type: 'operator', afterValue: true };
  }

  return { type: 'unknown' };
}

/**
 * Get context-specific tooltip data
 */
export interface TooltipOption {
  value: string;
  label: string;
  description?: string;
  hebrewDescription?: string;
}

export interface TooltipData {
  title: string;
  description?: string;
  options: TooltipOption[];
  hint?: string;
  allowCustomInput?: boolean;
}

export const TOOLTIP_CONTENT: Record<string, TooltipData> = {
  solar_degrees: {
    title: '📐 Degrees: Sun angle below horizon (0-90)',
    description: 'How far below the horizon is the sun?',
    options: [
      { value: '8.5', label: '8.5°', description: 'Tzeis (nightfall)', hebrewDescription: 'צאת הכוכבים' },
      { value: '11', label: '11°', description: 'Misheyakir (tallis/tefillin)', hebrewDescription: 'משיכיר' },
      { value: '16.1', label: '16.1°', description: 'Alos (Magen Avraham dawn)', hebrewDescription: 'עלות השחר' },
      { value: '18', label: '18°', description: 'Astronomical twilight' },
      { value: '7.083', label: '7.083°', description: 'Tzeis 3 stars (Geonim)' },
    ],
    hint: 'Type a number, e.g., 16.1',
    allowCustomInput: true,
  },
  solar_direction: {
    title: '🧭 Direction: When does this angle occur?',
    description: 'Morning or evening?',
    options: [
      { value: 'before_sunrise', label: 'before_sunrise', description: 'Morning (dawn)' },
      { value: 'after_sunset', label: 'after_sunset', description: 'Evening (tzeis)' },
      { value: 'before_noon', label: 'before_noon', description: 'Late morning' },
      { value: 'after_noon', label: 'after_noon', description: 'Afternoon' },
    ],
  },
  proportional_hours: {
    title: '⏰ Proportional Hours: Which halachic hour?',
    description: 'The day is divided into 12 proportional hours.',
    options: [
      { value: '3', label: '3 hours', description: 'Latest Shema', hebrewDescription: 'סוף זמן קריאת שמע' },
      { value: '4', label: '4 hours', description: 'Latest Shacharis', hebrewDescription: 'סוף זמן תפילה' },
      { value: '6', label: '6 hours', description: 'Chatzos (midday)', hebrewDescription: 'חצות' },
      { value: '6.5', label: '6.5 hours', description: 'Mincha Gedola' },
      { value: '9.5', label: '9.5 hours', description: 'Mincha Ketana' },
      { value: '10.75', label: '10.75 hours', description: 'Plag HaMincha' },
    ],
    hint: 'Type a number, e.g., 4',
    allowCustomInput: true,
  },
  proportional_base: {
    title: '📏 Base System: How is the day calculated?',
    description: 'Different authorities define day boundaries differently.',
    options: [
      { value: 'gra', label: 'gra', description: 'GRA (Vilna Gaon): sunrise to sunset' },
      { value: 'mga', label: 'mga', description: 'MGA: 72 min before sunrise to 72 min after sunset' },
      { value: 'mga_90', label: 'mga_90', description: 'MGA 90: 90 min before/after' },
      { value: 'mga_120', label: 'mga_120', description: 'MGA 120: 120 min before/after' },
      { value: 'alos_16_1', label: 'alos_16_1', description: 'Using 16.1° for alos/tzeis' },
    ],
  },
  midpoint_first: {
    title: '📍 First Time: Starting point',
    description: 'The earlier time to find the midpoint.',
    options: [
      { value: 'sunrise', label: 'sunrise', description: 'Netz HaChama' },
      { value: '@alos', label: '@alos', description: 'Reference to your alos' },
      { value: 'solar(16.1, before_sunrise)', label: 'solar(16.1, before_sunrise)', description: 'Alos at 16.1°' },
    ],
    hint: 'Use a primitive or reference',
  },
  midpoint_second: {
    title: '📍 Second Time: Ending point',
    description: 'The later time to find the midpoint.',
    options: [
      { value: 'sunset', label: 'sunset', description: 'Shkias HaChama' },
      { value: '@tzeis', label: '@tzeis', description: 'Reference to your tzeis' },
      { value: 'solar(8.5, after_sunset)', label: 'solar(8.5, after_sunset)', description: 'Tzeis at 8.5°' },
    ],
    hint: 'Use a primitive or reference',
  },
  min_max_first: {
    title: '⏱️ First Time',
    description: 'First time to compare.',
    options: [
      { value: 'sunrise', label: 'sunrise' },
      { value: 'sunset', label: 'sunset' },
      { value: '@alos', label: '@alos' },
      { value: '@tzeis', label: '@tzeis' },
    ],
  },
  min_max_second: {
    title: '⏱️ Second Time',
    description: 'Second time to compare.',
    options: [
      { value: 'sunrise', label: 'sunrise' },
      { value: 'sunset', label: 'sunset' },
      { value: '@alos', label: '@alos' },
      { value: '@tzeis', label: '@tzeis' },
    ],
  },
  empty_editor: {
    title: '✨ Start your formula',
    description: 'Click an example to get started:',
    options: [
      { value: 'sunrise - 72min', label: 'sunrise - 72min', description: 'Fixed time before sunrise' },
      { value: 'solar(16.1, before_sunrise)', label: 'solar(16.1, ...)', description: 'Dawn at 16.1°' },
      { value: 'proportional_hours(4, gra)', label: 'proportional_hours(4, ...)', description: 'Latest Shacharis' },
      { value: 'sunset - 18min', label: 'sunset - 18min', description: 'Candle lighting' },
    ],
    hint: 'Or pick from the reference panel →',
  },
};

/**
 * Get tooltip data for a given context type
 */
export function getTooltipData(context: DSLContext): TooltipData | null {
  if (context.type === 'empty_editor') {
    return TOOLTIP_CONTENT.empty_editor;
  }

  if (context.type === 'solar_degrees') {
    return TOOLTIP_CONTENT.solar_degrees;
  }

  if (context.type === 'solar_direction') {
    return TOOLTIP_CONTENT.solar_direction;
  }

  if (context.type === 'proportional_hours') {
    return TOOLTIP_CONTENT.proportional_hours;
  }

  if (context.type === 'proportional_base') {
    return TOOLTIP_CONTENT.proportional_base;
  }

  if (context.type === 'midpoint_first') {
    return TOOLTIP_CONTENT.midpoint_first;
  }

  if (context.type === 'midpoint_second') {
    return TOOLTIP_CONTENT.midpoint_second;
  }

  if (context.type === 'min_max_first') {
    return TOOLTIP_CONTENT.min_max_first;
  }

  if (context.type === 'min_max_second') {
    return TOOLTIP_CONTENT.min_max_second;
  }

  return null;
}
