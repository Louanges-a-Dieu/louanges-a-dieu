import type { Palette, Tokens } from './tokens.ts';
import { FONT_ROLES, PALETTE_KEYS, THEMES } from './tokens.ts';

const HEADER = 'GÉNÉRÉ par packages/design_tokens à partir de tokens.json — NE PAS MODIFIER.';

const kebab = (name: string): string => name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
const dartNumber = (n: number): string => String(n);

// ---------------------------------------------------------------------------
// Dart (Flutter)
// ---------------------------------------------------------------------------

function dartPalette(name: string, palette: Palette): string {
  const args = PALETTE_KEYS.map((key) => `    ${key}: Color(0xFF${palette[key].slice(1)}),`).join(
    '\n',
  );
  return `  static const ${name} = LadPalette(\n${args}\n  );`;
}

function dartConstants(className: string, doc: string, values: Record<string, number>): string {
  const lines = Object.entries(values)
    .map(([name, value]) => `  static const double ${name} = ${dartNumber(value)};`)
    .join('\n');
  return `/// ${doc}\nabstract final class ${className} {\n${lines}\n}`;
}

export function generateDart(tokens: Tokens): string {
  const fields = PALETTE_KEYS.map((key) => `  final Color ${key};`).join('\n');
  const ctorArgs = PALETTE_KEYS.map((key) => `    required this.${key},`).join('\n');
  const palettes = THEMES.map((theme) => dartPalette(theme, tokens.color[theme])).join('\n\n');

  const durations = Object.entries(tokens.duration)
    .map(([name, ms]) => `  static const Duration ${name} = Duration(milliseconds: ${ms});`)
    .join('\n');

  const families = FONT_ROLES.map(
    (role) => `  static const String ${role} = '${tokens.font.family[role]}';`,
  ).join('\n');

  const typeScale = Object.entries(tokens.typeScale)
    .map(([name, spec]) =>
      [
        `  static const ${name} = LadTextSpec(`,
        `    role: LadFontRole.${spec.family},`,
        `    size: ${dartNumber(spec.size)},`,
        `    height: ${dartNumber(spec.lineHeight)},`,
        `    weight: FontWeight.w${tokens.font.weight[spec.weight]},`,
        `  );`,
      ].join('\n'),
    )
    .join('\n\n');

  const ls = tokens.lyricsSize;

  return `// ${HEADER}
// Source : packages/design_tokens/tokens.json (ADR-014).

import 'dart:ui';

/// Palette de couleurs d'un thème.
final class LadPalette {
  const LadPalette({
${ctorArgs}
  });

${fields}

${palettes}
}

${dartConstants('LadSpace', 'Espacements (dp).', tokens.space)}

${dartConstants('LadRadius', 'Rayons (dp).', tokens.radius)}

${dartConstants('LadStroke', 'Épaisseurs de trait (dp).', tokens.stroke)}

/// Durées d'animation.
abstract final class LadDurations {
${durations}
}

/// Familles de polices.
abstract final class LadFonts {
${families}
}

/// Rôle typographique.
enum LadFontRole { ${FONT_ROLES.join(', ')} }

/// Spécification d'un style de texte.
final class LadTextSpec {
  const LadTextSpec({
    required this.role,
    required this.size,
    required this.height,
    required this.weight,
  });

  final LadFontRole role;
  final double size;
  final double height;
  final FontWeight weight;
}

/// Échelle typographique.
abstract final class LadTypeScale {
${typeScale}
}

/// Taille de lecture des paroles réglable par l'utilisateur (pt).
abstract final class LadLyricsSize {
  static const double min = ${dartNumber(ls.min)};
  static const double defaultSize = ${dartNumber(ls.default)};
  static const double max = ${dartNumber(ls.max)};
  static const double step = ${dartNumber(ls.step)};
}

/// Taille minimale d'une cible tactile (dp).
abstract final class LadTouchTarget {
  static const double min = ${dartNumber(tokens.touchTarget.min)};
}
`;
}

// ---------------------------------------------------------------------------
// CSS (web)
// ---------------------------------------------------------------------------

function cssColors(palette: Palette, indent: string): string {
  return PALETTE_KEYS.map((key) => `${indent}--lad-color-${kebab(key)}: ${palette[key]};`).join(
    '\n',
  );
}

export function generateCss(tokens: Tokens): string {
  const px = (group: Record<string, number>, prefix: string): string =>
    Object.entries(group)
      .map(([name, value]) => `  --lad-${prefix}-${kebab(name)}: ${value}px;`)
      .join('\n');

  const fonts = FONT_ROLES.map(
    (role) => `  --lad-font-${role}: '${tokens.font.family[role]}', ${tokens.font.fallback[role]};`,
  ).join('\n');

  const type = Object.entries(tokens.typeScale)
    .map(([name, spec]) =>
      [
        `  --lad-type-${kebab(name)}-family: var(--lad-font-${spec.family});`,
        `  --lad-type-${kebab(name)}-size: ${spec.size}px;`,
        `  --lad-type-${kebab(name)}-line-height: ${spec.lineHeight};`,
        `  --lad-type-${kebab(name)}-weight: ${tokens.font.weight[spec.weight]};`,
      ].join('\n'),
    )
    .join('\n');

  const durations = Object.entries(tokens.duration)
    .map(([name, ms]) => `  --lad-duration-${kebab(name)}: ${ms}ms;`)
    .join('\n');

  return `/* ${HEADER} */

:root,
[data-theme='light'] {
  color-scheme: light;
${cssColors(tokens.color.light, '  ')}
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) {
    color-scheme: dark;
${cssColors(tokens.color.dark, '    ')}
  }
}

[data-theme='dark'] {
  color-scheme: dark;
${cssColors(tokens.color.dark, '  ')}
}

[data-theme='projection'] {
  color-scheme: dark;
${cssColors(tokens.color.projection, '  ')}
}

:root {
${fonts}
${type}
${px(tokens.space, 'space')}
${px(tokens.radius, 'radius')}
${px(tokens.stroke, 'stroke')}
${durations}
  --lad-touch-target-min: ${tokens.touchTarget.min}px;
  --lad-lyrics-size-min: ${tokens.lyricsSize.min}px;
  --lad-lyrics-size-default: ${tokens.lyricsSize.default}px;
  --lad-lyrics-size-max: ${tokens.lyricsSize.max}px;
}
`;
}
