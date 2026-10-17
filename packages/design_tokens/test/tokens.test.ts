import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

import { checkContrast, contrastRatio } from '../src/contrast.ts';
import { generateCss, generateDart } from '../src/generate.ts';
import { loadTokens, validateTokens } from '../src/tokens.ts';

const tokens = loadTokens(resolve(import.meta.dirname, '../tokens.json'));

describe('contrastRatio', () => {
  it('donne 21 pour noir sur blanc et 1 pour une couleur sur elle-même', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBeCloseTo(21, 5);
    expect(contrastRatio('#B08D57', '#B08D57')).toBeCloseTo(1, 5);
  });

  it('est symétrique', () => {
    expect(contrastRatio('#1F1A17', '#FFFFFF')).toBeCloseTo(contrastRatio('#FFFFFF', '#1F1A17'));
  });
});

describe('tokens.json', () => {
  it('est structurellement valide', () => {
    expect(validateTokens(tokens)).toEqual([]);
  });

  it('respecte toutes les règles de contraste sur les trois thèmes', () => {
    expect(checkContrast(tokens)).toEqual([]);
  });

  it('garantit le niveau AAA pour le texte des paroles sur fond blanc', () => {
    expect(contrastRatio(tokens.color.light.text, tokens.color.light.background)).toBeGreaterThan(
      7,
    );
  });

  it("n'autorise pas l'or décoratif comme couleur de texte courant (< 4.5)", () => {
    expect(contrastRatio(tokens.color.light.gold, tokens.color.light.background)).toBeLessThan(4.5);
  });

  it('a un fond blanc pur en thème clair (décision Q-11)', () => {
    expect(tokens.color.light.background).toBe('#FFFFFF');
  });
});

describe('validateTokens', () => {
  it('détecte une couleur mal formée', () => {
    const broken = structuredClone(tokens);
    broken.color.dark.text = 'blue';
    expect(validateTokens(broken)).toContain(
      'color.dark.text doit être une couleur #RRGGBB en majuscules',
    );
  });

  it('détecte une taille de lecture incohérente', () => {
    const broken = structuredClone(tokens);
    broken.lyricsSize.default = 99;
    expect(validateTokens(broken)).toContain(
      'lyricsSize : il faut min ≤ default ≤ max et step > 0',
    );
  });
});

describe('générateurs', () => {
  it('produit les trois palettes Dart avec des couleurs opaques', () => {
    const dart = generateDart(tokens);
    expect(dart).toContain('static const light = LadPalette(');
    expect(dart).toContain('static const dark = LadPalette(');
    expect(dart).toContain('static const projection = LadPalette(');
    expect(dart).toContain('background: Color(0xFFFFFFFF),');
    expect(dart).toContain('weight: FontWeight.w400,');
  });

  it('produit les variables CSS et le mode sombre automatique', () => {
    const css = generateCss(tokens);
    expect(css).toContain('--lad-color-text-secondary: #6B625B;');
    expect(css).toContain("--lad-font-lyrics: 'Literata', Georgia, serif;");
    expect(css).toContain("[data-theme='projection']");
    expect(css).toContain('@media (prefers-color-scheme: dark)');
  });

  it('est déterministe', () => {
    expect(generateDart(tokens)).toBe(generateDart(tokens));
    expect(generateCss(tokens)).toBe(generateCss(tokens));
  });
});
