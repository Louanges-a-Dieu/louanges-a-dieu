import type { Tokens } from './tokens.ts';
import { THEMES } from './tokens.ts';

/** Luminance relative WCAG 2.x d'une couleur #RRGGBB. */
export function relativeLuminance(hex: string): number {
  const channel = (offset: number): number => {
    const c = parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
}

/** Rapport de contraste WCAG entre deux couleurs (1 à 21). */
export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [relativeLuminance(a), relativeLuminance(b)].sort((x, y) => y - x) as [
    number,
    number,
  ];
  return (hi + 0.05) / (lo + 0.05);
}

export interface ContrastViolation {
  theme: string;
  foreground: string;
  background: string;
  ratio: number;
  min: number;
}

/** Vérifie toutes les règles de contraste sur tous les thèmes, base et application. */
export function checkContrast(tokens: Tokens): ContrastViolation[] {
  const violations: ContrastViolation[] = [];
  const palettes = [
    ...THEMES.map((theme) => [theme, tokens.color[theme]] as const),
    ...(tokens.app
      ? ([
          ['app.light', tokens.app.color.light],
          ['app.dark', tokens.app.color.dark],
        ] as const)
      : []),
  ];
  for (const [theme, palette] of palettes) {
    for (const rule of tokens.contrast.rules) {
      const ratio = contrastRatio(palette[rule.foreground], palette[rule.background]);
      if (ratio < rule.min) {
        violations.push({ theme, ...rule, ratio: Math.round(ratio * 100) / 100 });
      }
    }
  }
  return violations;
}
