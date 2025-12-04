// DSL Token definitions for syntax highlighting

export type TokenType =
  | 'keyword'
  | 'function'
  | 'primitive'
  | 'operator'
  | 'number'
  | 'duration'
  | 'reference'
  | 'comment'
  | 'string'
  | 'bracket'
  | 'identifier'
  | 'unknown';

export interface Token {
  type: TokenType;
  value: string;
  start: number;
  end: number;
}

// DSL keywords
export const PRIMITIVES = [
  'sunrise',
  'sunset',
  'solar_noon',
  'midnight',
  'civil_dawn',
  'civil_dusk',
  'nautical_dawn',
  'nautical_dusk',
  'astronomical_dawn',
  'astronomical_dusk',
  'alos_hashachar',
  'misheyakir',
  'tzeis_hakochavim',
  'bein_hashmashos',
];

export const FUNCTIONS = [
  'solar',
  'proportional_hours',
  'midpoint',
  'if',
  'else',
];

export const OPERATORS = ['+', '-', '*', '/', '>', '<', '>=', '<=', '==', '!=', '&&', '||', '!'];

export const DIRECTION_KEYWORDS = ['before_sunrise', 'after_sunset'];

export const BASE_KEYWORDS = ['gra', 'mga', 'custom'];

// Simple tokenizer for DSL
export function tokenize(input: string): Token[] {
  const tokens: Token[] = [];
  let pos = 0;

  while (pos < input.length) {
    let match: RegExpMatchArray | null;

    // Skip whitespace
    match = input.slice(pos).match(/^\s+/);
    if (match) {
      pos += match[0].length;
      continue;
    }

    // Comments (// ...)
    match = input.slice(pos).match(/^\/\/[^\n]*/);
    if (match) {
      tokens.push({ type: 'comment', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Duration (e.g., 72min, 1hr, 2h)
    match = input.slice(pos).match(/^(\d+(?:\.\d+)?)\s*(min|minutes?|hr|hours?|h|m)\b/i);
    if (match) {
      tokens.push({ type: 'duration', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Numbers
    match = input.slice(pos).match(/^\d+(?:\.\d+)?/);
    if (match) {
      tokens.push({ type: 'number', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // References (@identifier)
    match = input.slice(pos).match(/^@[a-zA-Z_][a-zA-Z0-9_]*/);
    if (match) {
      tokens.push({ type: 'reference', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Identifiers (functions, primitives, keywords)
    match = input.slice(pos).match(/^[a-zA-Z_][a-zA-Z0-9_]*/);
    if (match) {
      const word = match[0].toLowerCase();
      let type: TokenType = 'identifier';

      if (FUNCTIONS.includes(word)) {
        type = 'function';
      } else if (PRIMITIVES.includes(word)) {
        type = 'primitive';
      } else if (DIRECTION_KEYWORDS.includes(word) || BASE_KEYWORDS.includes(word)) {
        type = 'keyword';
      }

      tokens.push({ type, value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Operators
    match = input.slice(pos).match(/^[+\-*/<>=!&|]+/);
    if (match && OPERATORS.includes(match[0])) {
      tokens.push({ type: 'operator', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Brackets
    match = input.slice(pos).match(/^[(){}[\],]/);
    if (match) {
      tokens.push({ type: 'bracket', value: match[0], start: pos, end: pos + match[0].length });
      pos += match[0].length;
      continue;
    }

    // Unknown - single character
    tokens.push({ type: 'unknown', value: input[pos], start: pos, end: pos + 1 });
    pos++;
  }

  return tokens;
}

// Get CSS class for token type
export function getTokenClass(type: TokenType): string {
  switch (type) {
    case 'keyword':
      return 'text-purple-500 dark:text-purple-400';
    case 'function':
      return 'text-blue-500 dark:text-blue-400';
    case 'primitive':
      return 'text-green-500 dark:text-green-400';
    case 'operator':
      return 'text-amber-500 dark:text-amber-400';
    case 'number':
      return 'text-orange-500 dark:text-orange-400';
    case 'duration':
      return 'text-teal-500 dark:text-teal-400';
    case 'reference':
      return 'text-pink-500 dark:text-pink-400';
    case 'comment':
      return 'text-muted-foreground italic';
    case 'bracket':
      return 'text-foreground';
    default:
      return 'text-foreground';
  }
}
