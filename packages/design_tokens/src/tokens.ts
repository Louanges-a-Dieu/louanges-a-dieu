import { readFileSync } from 'node:fs';

export const PALETTE_KEYS = [
  'background',
  'surface',
  'surfaceWarm',
  'hairline',
  'text',
  'textSecondary',
  'gold',
  'goldText',
  'goldLight',
  'goldPale',
  'error',
  'success',
  'info',
] as const;
export type PaletteKey = (typeof PALETTE_KEYS)[number];
export type Palette = Record<PaletteKey, string>;

export const THEMES = ['light', 'dark', 'sepia', 'projection'] as const;
export type ThemeName = (typeof THEMES)[number];

export const FONT_ROLES = ['display', 'lyrics', 'ui', 'numeric'] as const;
export type FontRole = (typeof FONT_ROLES)[number];
export type FontWeightName = 'regular' | 'medium' | 'semibold';

export interface TextSpec {
  family: FontRole;
  size: number;
  lineHeight: number;
  weight: FontWeightName;
  /** Interlettrage en em (0 par défaut). */
  letterSpacing?: number;
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
  /** Ombre douce (cartes mises en avant) ; couleur : texte du thème. */
  shadow: { softOffsetY: number; softBlur: number; softOpacity: number };
  duration: Record<string, number>;
  touchTarget: { min: number };
  /**
   * Direction propre à l'application mobile (remplace les valeurs de base de
   * même nom). Facultatif : absent depuis la direction « Le recueil vivant »
   * (2026-10-20), commune à toutes les surfaces.
   */
  app?: {
    color: Record<'light' | 'dark', Palette>;
    font: { family: Record<FontRole, string>; fallback: Record<FontRole, string> };
    typeScale: Record<string, TextSpec>;
    radius: Record<string, number>;
    stroke: Record<string, number>;
  };
}

/**
 * Tokens tels que les voit l'application mobile : bloc « app » appliqué sur
 * les valeurs de base. Le thème projection reste celui de base (l'écran
 * projeté est servi avec les tokens CSS de base).
 */
export function appTokens(t: Tokens): Tokens {
  if (!t.app) return t;
  return {
    ...t,
    color: { ...t.color, light: t.app.color.light, dark: t.app.color.dark },
    font: { ...t.font, family: t.app.font.family, fallback: t.app.font.fallback },
    typeScale: t.app.typeScale,
    radius: { ...t.radius, ...t.app.radius },
    stroke: { ...t.stroke, ...t.app.stroke },
  };
}

const HEX = /^#[0-9A-F]{6}$/;
const NAME = /^[a-z][A-Za-z0-9]*$/;

function checkPalette(errors: string[], path: string, palette: Palette | undefined) {
  if (!palette) {
    errors.push(`${path} manquant`);
    return;
  }
  for (const key of PALETTE_KEYS) {
    const value = palette[key];
    if (typeof value !== 'string' || !HEX.test(value)) {
      errors.push(`${path}.${key} doit être une couleur #RRGGBB en majuscules`);
    }
  }
  for (const key of Object.keys(palette)) {
    if (!(PALETTE_KEYS as readonly string[]).includes(key)) {
      errors.push(`${path}.${key} : clé inconnue`);
    }
  }
}

function checkFonts(
  errors: string[],
  path: string,
  font: Partial<Pick<Tokens['font'], 'family' | 'fallback'>> | undefined,
) {
  for (const role of FONT_ROLES) {
    if (typeof font?.family?.[role] !== 'string') errors.push(`${path}.family.${role} manquant`);
    if (typeof font?.fallback?.[role] !== 'string')
      errors.push(`${path}.fallback.${role} manquant`);
  }
}

function checkTypeScale(
  errors: string[],
  path: string,
  scale: Record<string, TextSpec> | undefined,
  weights: Record<string, number>,
) {
  for (const [name, spec] of Object.entries(scale ?? {})) {
    if (!(FONT_ROLES as readonly string[]).includes(spec.family)) {
      errors.push(`${path}.${name}.family inconnue : ${spec.family}`);
    }
    if (!(spec.weight in weights)) {
      errors.push(`${path}.${name}.weight inconnu : ${spec.weight}`);
    }
    if (spec.letterSpacing !== undefined && Math.abs(spec.letterSpacing) > 0.5) {
      errors.push(`${path}.${name}.letterSpacing : valeur en em attendue (entre -0,5 et 0,5)`);
    }
    if (!NAME.test(name)) errors.push(`${path}.${name} : nom invalide (camelCase attendu)`);
  }
}

/** Valide la structure et renvoie la liste des erreurs (vide si valide). */
export function validateTokens(raw: unknown): string[] {
  const errors: string[] = [];
  const t = raw as Partial<Tokens>;
  for (const theme of THEMES) checkPalette(errors, `color.${theme}`, t.color?.[theme]);
  for (const rule of t.contrast?.rules ?? []) {
    for (const key of [rule.foreground, rule.background]) {
      if (!(PALETTE_KEYS as readonly string[]).includes(key)) {
        errors.push(`contrast : clé de couleur inconnue « ${key} »`);
      }
    }
  }
  checkFonts(errors, 'font', t.font);
  for (const [name, weight] of Object.entries(t.font?.weight ?? {})) {
    if (![100, 200, 300, 400, 500, 600, 700, 800, 900].includes(weight)) {
      errors.push(`font.weight.${name} doit être un multiple de 100 entre 100 et 900`);
    }
  }
  const weights = t.font?.weight ?? {};
  checkTypeScale(errors, 'typeScale', t.typeScale, weights);
  const ls = t.lyricsSize;
  if (!ls || !(ls.min <= ls.default && ls.default <= ls.max) || ls.step <= 0) {
    errors.push('lyricsSize : il faut min ≤ default ≤ max et step > 0');
  }
  for (const group of ['space', 'radius', 'stroke', 'duration'] as const) {
    for (const name of Object.keys(t[group] ?? {})) {
      if (!NAME.test(name)) errors.push(`${group}.${name} : nom invalide (camelCase attendu)`);
    }
  }

  const shadow = t.shadow;
  if (
    !shadow ||
    !(shadow.softOffsetY >= 0 && shadow.softBlur >= 0) ||
    !(shadow.softOpacity > 0 && shadow.softOpacity <= 1)
  ) {
    errors.push('shadow : softOffsetY et softBlur ≥ 0, 0 < softOpacity ≤ 1');
  }

  const app = t.app;
  if (!app) return errors;
  checkPalette(errors, 'app.color.light', app.color?.light);
  checkPalette(errors, 'app.color.dark', app.color?.dark);
  checkFonts(errors, 'app.font', app.font);
  checkTypeScale(errors, 'app.typeScale', app.typeScale, weights);
  // Les composants de l'app utilisent les styles de base : aucun ne doit manquer.
  for (const name of Object.keys(t.typeScale ?? {})) {
    if (!app.typeScale?.[name]) errors.push(`app.typeScale.${name} manquant`);
  }
  for (const group of ['radius', 'stroke'] as const) {
    for (const name of Object.keys(app[group] ?? {})) {
      if (!NAME.test(name)) errors.push(`app.${group}.${name} : nom invalide (camelCase attendu)`);
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
