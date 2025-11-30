// DSL Reference Data for the Advanced DSL Editor
// This file contains all the primitives, functions, operators, and examples

export interface ReferenceItem {
  name: string;
  signature?: string;
  description: string;
  snippet: string;
  category: 'primitive' | 'function' | 'operator' | 'reference';
}

export interface ExamplePattern {
  formula: string;
  description: string;
}

export const DSL_PRIMITIVES: ReferenceItem[] = [
  // Core astronomical events
  {
    name: 'sunrise',
    description: 'Start of visible sun (netz hachama)',
    snippet: 'sunrise',
    category: 'primitive',
  },
  {
    name: 'sunset',
    description: 'End of visible sun (shkiah)',
    snippet: 'sunset',
    category: 'primitive',
  },
  {
    name: 'solar_noon',
    description: 'Sun at highest point (chatzos hayom)',
    snippet: 'solar_noon',
    category: 'primitive',
  },
  {
    name: 'solar_midnight',
    description: 'Solar midnight (chatzos halayla)',
    snippet: 'solar_midnight',
    category: 'primitive',
  },
  // Visible sunrise/sunset (with atmospheric refraction)
  {
    name: 'visible_sunrise',
    description: 'Visible sunrise accounting for atmospheric refraction',
    snippet: 'visible_sunrise',
    category: 'primitive',
  },
  {
    name: 'visible_sunset',
    description: 'Visible sunset accounting for atmospheric refraction',
    snippet: 'visible_sunset',
    category: 'primitive',
  },
  // Civil twilight (-6°)
  {
    name: 'civil_dawn',
    description: 'Civil dawn - sun at 6° below horizon (morning)',
    snippet: 'civil_dawn',
    category: 'primitive',
  },
  {
    name: 'civil_dusk',
    description: 'Civil dusk - sun at 6° below horizon (evening)',
    snippet: 'civil_dusk',
    category: 'primitive',
  },
  // Nautical twilight (-12°)
  {
    name: 'nautical_dawn',
    description: 'Nautical dawn - sun at 12° below horizon (morning)',
    snippet: 'nautical_dawn',
    category: 'primitive',
  },
  {
    name: 'nautical_dusk',
    description: 'Nautical dusk - sun at 12° below horizon (evening)',
    snippet: 'nautical_dusk',
    category: 'primitive',
  },
  // Astronomical twilight (-18°)
  {
    name: 'astronomical_dawn',
    description: 'Astronomical dawn - sun at 18° below horizon (morning)',
    snippet: 'astronomical_dawn',
    category: 'primitive',
  },
  {
    name: 'astronomical_dusk',
    description: 'Astronomical dusk - sun at 18° below horizon (evening)',
    snippet: 'astronomical_dusk',
    category: 'primitive',
  },
];

export const DSL_FUNCTIONS: ReferenceItem[] = [
  // Solar angle function
  {
    name: 'solar',
    signature: 'solar(degrees, direction)',
    description: 'Time when sun reaches angle. Directions: before_sunrise, after_sunset, before_noon, after_noon',
    snippet: 'solar(degrees, direction)',
    category: 'function',
  },
  // Proportional hours (sha'os zmaniyos)
  {
    name: 'shaos',
    signature: 'shaos(hours, base)',
    description: 'Proportional hours. Bases: gra (sunrise-sunset), mga (72min), mga_90, mga_120',
    snippet: 'shaos(hours, base)',
    category: 'function',
  },
  // Midpoint function
  {
    name: 'midpoint',
    signature: 'midpoint(a, b)',
    description: 'Returns the midpoint between two times',
    snippet: 'midpoint(a, b)',
    category: 'function',
  },
];

// Shaos bases for reference
export const DSL_SHAOS_BASES: ReferenceItem[] = [
  {
    name: 'gra',
    description: 'GRA method: sunrise to sunset',
    snippet: 'gra',
    category: 'function',
  },
  {
    name: 'mga',
    description: 'MGA method: 72 min before sunrise to 72 min after sunset',
    snippet: 'mga',
    category: 'function',
  },
  {
    name: 'mga_90',
    description: 'MGA 90 method: 90 min before sunrise to 90 min after sunset',
    snippet: 'mga_90',
    category: 'function',
  },
  {
    name: 'mga_120',
    description: 'MGA 120 method: 120 min before sunrise to 120 min after sunset',
    snippet: 'mga_120',
    category: 'function',
  },
];

// Solar directions for reference
export const DSL_DIRECTIONS: ReferenceItem[] = [
  {
    name: 'before_sunrise',
    description: 'Morning: sun ascending before sunrise',
    snippet: 'before_sunrise',
    category: 'function',
  },
  {
    name: 'after_sunset',
    description: 'Evening: sun descending after sunset',
    snippet: 'after_sunset',
    category: 'function',
  },
  {
    name: 'before_noon',
    description: 'Morning: sun ascending before solar noon',
    snippet: 'before_noon',
    category: 'function',
  },
  {
    name: 'after_noon',
    description: 'Afternoon: sun descending after solar noon',
    snippet: 'after_noon',
    category: 'function',
  },
];

export const DSL_OPERATORS: ReferenceItem[] = [
  {
    name: '+',
    description: 'Add duration (e.g., sunrise + 30min)',
    snippet: ' + ',
    category: 'operator',
  },
  {
    name: '-',
    description: 'Subtract duration (e.g., sunset - 18min)',
    snippet: ' - ',
    category: 'operator',
  },
  {
    name: 'min',
    description: 'Minutes unit (e.g., 72min)',
    snippet: 'min',
    category: 'operator',
  },
  {
    name: 'hr',
    description: 'Hours unit (e.g., 1hr)',
    snippet: 'hr',
    category: 'operator',
  },
];

export const EXAMPLE_PATTERNS: ExamplePattern[] = [
  {
    formula: 'sunrise - 72min',
    description: 'Dawn - 72 fixed minutes before sunrise',
  },
  {
    formula: 'solar(16.1, before_sunrise)',
    description: 'Dawn at 16.1° (Magen Avraham)',
  },
  {
    formula: 'shaos(4, sunrise)',
    description: 'End of 4th proportional hour (Sof Zman Shema)',
  },
  {
    formula: 'sunset - 18min',
    description: 'Candle lighting - 18 min before sunset',
  },
  {
    formula: 'solar(8.5, after_sunset)',
    description: 'Tzeis - 8.5° after sunset',
  },
  {
    formula: 'sunset + 72min',
    description: 'Tzeis - 72 minutes after sunset (Rabbeinu Tam)',
  },
];

// Helper to get all reference items
export function getAllReferenceItems(): ReferenceItem[] {
  return [...DSL_PRIMITIVES, ...DSL_FUNCTIONS, ...DSL_OPERATORS];
}

// Helper to create reference items from zmanim keys
export function createZmanimReferences(zmanimKeys: string[]): ReferenceItem[] {
  return zmanimKeys.map((key) => ({
    name: `@${key}`,
    description: `Reference to ${key.replace(/_/g, ' ')}`,
    snippet: `@${key}`,
    category: 'reference' as const,
  }));
}

// Helper to escape special regex characters
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Helper to check if a term is used in a formula
export function isTermInFormula(term: string, formula: string): boolean {
  // For references, check exact match with @
  if (term.startsWith('@')) {
    return formula.includes(term);
  }
  // For operators (special characters like +, -), use simple includes
  if (DSL_OPERATORS.some(op => op.name === term)) {
    return formula.includes(term);
  }
  // For functions, check if function name is followed by (
  if (DSL_FUNCTIONS.some(f => f.name === term)) {
    const escapedTerm = escapeRegex(term);
    const regex = new RegExp(`\\b${escapedTerm}\\s*\\(`);
    return regex.test(formula);
  }
  // For primitives, check word boundary
  const escapedTerm = escapeRegex(term);
  const regex = new RegExp(`\\b${escapedTerm}\\b`);
  return regex.test(formula);
}
