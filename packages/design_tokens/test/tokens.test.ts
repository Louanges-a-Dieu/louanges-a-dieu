import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

import { checkContrast, contrastRatio } from '../src/contrast.ts';
import { generateCss, generateDart } from '../src/generate.ts';
import { appTokens, loadTokens, validateTokens } from '../src/tokens.ts';

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

  it('garantit le niveau AAA pour le texte des paroles sur le fond ivoire', () => {
    expect(contrastRatio(tokens.color.light.text, tokens.color.light.background)).toBeGreaterThan(
      7,
    );
  });

  it("n'autorise pas l'or décoratif comme couleur de texte courant (< 4.5)", () => {
    expect(contrastRatio(tokens.color.light.gold, tokens.color.light.background)).toBeLessThan(4.5);
  });

  it('suit la direction « Le recueil vivant » (2026-10-20) : ivoire, brun, or, serif', () => {
    expect(tokens.color.light.background).toBe('#F7F0E4');
    expect(tokens.color.light.text).toBe('#392A1B');
    expect(tokens.color.light.gold).toBe('#A86D13');
    expect(tokens.color.projection.background).toBe('#171F1F');
    expect(tokens.font.family.display).toBe('Cormorant Garamond');
    expect(tokens.font.family.lyrics).toBe('Literata');
    expect(tokens.font.family.ui).toBe('Inter');
  });

  it('libellés blancs (surface) lisibles sur les boutons dorés (AA)', () => {
    expect(
      contrastRatio(tokens.color.light.surface, tokens.color.light.goldText),
    ).toBeGreaterThanOrEqual(4.5);
  });
});

describe('bloc facultatif « app »', () => {
  it('absent : l’application reçoit exactement les valeurs de base', () => {
    expect(tokens.app).toBeUndefined();
    expect(appTokens(tokens)).toBe(tokens);
  });

  const withApp = (): typeof tokens => {
    const t = structuredClone(tokens);
    t.app = {
      color: { light: { ...t.color.light }, dark: { ...t.color.dark } },
      font: { family: { ...t.font.family }, fallback: { ...t.font.fallback } },
      typeScale: structuredClone(t.typeScale),
      radius: {},
      stroke: {},
    };
    return t;
  };

  it('présent : remplace les palettes claire et sombre, garde la projection de base', () => {
    const t = withApp();
    t.app!.color.light.background = '#FFFFFF';
    const app = appTokens(t);
    expect(app.color.light.background).toBe('#FFFFFF');
    expect(app.color.projection).toEqual(t.color.projection);
  });

  it('signale un style de base absent du bloc « app »', () => {
    const broken = withApp();
    delete broken.app!.typeScale.lyrics;
    expect(validateTokens(broken)).toContain('app.typeScale.lyrics manquant');
  });

  it('vérifie aussi les contrastes des palettes de l’application', () => {
    const broken = withApp();
    broken.app!.color.light.textSecondary = '#BBBBBB';
    expect(checkContrast(broken).map((v) => v.theme)).toContain('app.light');
  });

  it('Dart et CSS : mêmes polices pour l’app, le web et l’écran projeté', () => {
    const dart = generateDart(tokens);
    expect(dart).toContain("static const String lyrics = 'Literata';");
    expect(dart).toContain('abstract final class LadProjectionFonts');
    expect(dart).toContain('abstract final class LadProjectionTypeScale');
    expect(dart).toContain('letterSpacing: 0.16,');
    expect(dart).toContain('abstract final class LadShadow');
    const css = generateCss(tokens);
    expect(css).toContain("--lad-font-lyrics: 'Literata', Georgia, serif;");
    expect(css).toContain('--lad-shadow-soft:');
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

  it('détecte une ombre incohérente', () => {
    const broken = structuredClone(tokens);
    broken.shadow.softOpacity = 2;
    expect(validateTokens(broken)).toContain(
      'shadow : softOffsetY et softBlur ≥ 0, 0 < softOpacity ≤ 1',
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
    expect(dart).toContain('background: Color(0xFFF7F0E4),');
    expect(dart).toContain('weight: FontWeight.w400,');
  });

  it('produit les variables CSS et le mode sombre automatique', () => {
    const css = generateCss(tokens);
    expect(css).toContain('--lad-color-text-secondary: #76634B;');
    expect(css).toContain('--lad-color-gold-pale: #E8D1A6;');
    expect(css).toContain("--lad-font-lyrics: 'Literata', Georgia, serif;");
    expect(css).toContain("[data-theme='projection']");
    expect(css).toContain('@media (prefers-color-scheme: dark)');
  });

  it('est déterministe', () => {
    expect(generateDart(tokens)).toBe(generateDart(tokens));
    expect(generateCss(tokens)).toBe(generateCss(tokens));
  });
});
