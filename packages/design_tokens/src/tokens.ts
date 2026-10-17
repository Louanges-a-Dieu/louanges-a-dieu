import { readFileSync } from 'node:fs';

export const PALETTE_KEYS = [
  'background',
  'surface',
  'hairline',
  'text',
  'textSecondary',
  'gold',
  'goldText',
  'error',
  'success',
  'info',
] as const;
export type PaletteKey = (typeof PALETTE_KEYS)[number];
export type Palette = Record<PaletteKey, string>;

export const THEMES = ['light', 'dark', 'projection'] as const;
export type ThemeName = (typeof THEMES)[number];

export const FONT_ROLES = ['display', 'lyrics', 'ui'] as const;
export type FontRole = (typeof FONT_ROLES)[number];
export type FontWeightName = 'regular' | 'medium' | 'semibold';

export interface TextSpec {
  family: FontRole;
  size: number;
  lineHeight: number;
  weight: FontWeightName;
}

export interface ContrastRule {
  foreground: PaletteKey;
  background: PaletteKey;
  min: number;
}

export interface Tokens {
  color: Record<ThemeName, Palette>;
  contrast: { rules: ContrastRule[] };
  font: {
    family: Record<FontRole, string>;
    fallback: Record<FontRole, string>;
    weight: Record<FontWeightName, number>;
  };
  typeScale: Record<string, TextSpec>;
  lyricsSize: { min: number; default: number; max: number; step: number };
  space: Record<string, number>;
  radius: Record<string, number>;
  stroke: Record<string, number>;
  duration: Record<string, number>;
  touchTarget: { min: number };
}

const HEX = /^#[0-9A-F]{6}$/;
const NAME = /^[a-z][A-Za-z0-9]*$/;

/** Valide la structure et renvoie la liste des erreurs (vide si valide). */
export function validateTokens(raw: unknown): string[] {
  const errors: string[] = [];
  const t = raw as Partial<Tokens>;
  for (const theme of THEMES) {
    const palette = t.color?.[theme];
    if (!palette) {
      errors.push(`color.${theme} manquant`);
      continue;
    }
    for (const key of PALETTE_KEYS) {
      const value = palette[key];
      if (typeof value !== 'string' || !HEX.test(value)) {
        errors.push(`color.${theme}.${key} doit être une couleur #RRGGBB en majuscules`);
      }
    }
    for (const key of Object.keys(palette)) {
      if (!(PALETTE_KEYS as readonly string[]).includes(key)) {
        errors.push(`color.${theme}.${key} : clé inconnue`);
      }
    }
  }
  for (const rule of t.contrast?.rules ?? []) {
    for (const key of [rule.foreground, rule.background]) {
      if (!(PALETTE_KEYS as readonly string[]).includes(key)) {
        errors.push(`contrast : clé de couleur inconnue « ${key} »`);
      }
    }
  }
  for (const role of FONT_ROLES) {
    if (typeof t.font?.family?.[role] !== 'string') errors.push(`font.family.${role} manquant`);
    if (typeof t.font?.fallback?.[role] !== 'string') errors.push(`font.fallback.${role} manquant`);
  }
  for (const [name, weight] of Object.entries(t.font?.weight ?? {})) {
    if (![100, 200, 300, 400, 500, 600, 700, 800, 900].includes(weight)) {
      errors.push(`font.weight.${name} doit être un multiple de 100 entre 100 et 900`);
    }
  }
  for (const [name, spec] of Object.entries(t.typeScale ?? {})) {
    if (!(FONT_ROLES as readonly string[]).includes(spec.family)) {
      errors.push(`typeScale.${name}.family inconnue : ${spec.family}`);
    }
    if (!(spec.weight in (t.font?.weight ?? {}))) {
      errors.push(`typeScale.${name}.weight inconnu : ${spec.weight}`);
    }
  }
  const ls = t.lyricsSize;
  if (!ls || !(ls.min <= ls.default && ls.default <= ls.max) || ls.step <= 0) {
    errors.push('lyricsSize : il faut min ≤ default ≤ max et step > 0');
  }
  for (const group of ['space', 'radius', 'stroke', 'duration', 'typeScale'] as const) {
    for (const name of Object.keys(t[group] ?? {})) {
      if (!NAME.test(name)) errors.push(`${group}.${name} : nom invalide (camelCase attendu)`);
    }
  }
  return errors;
}

export function loadTokens(path: string): Tokens {
  const raw: unknown = JSON.parse(readFileSync(path, 'utf8'));
  const errors = validateTokens(raw);
  if (errors.length > 0) {
    throw new Error(`tokens.json invalide :\n- ${errors.join('\n- ')}`);
  }
  return raw as Tokens;
}
