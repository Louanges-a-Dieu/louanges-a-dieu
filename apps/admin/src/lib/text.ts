import { fold } from '@lad/shared-contracts';

/** Texte d'une section : fins de ligne normalisées, espaces de fin de vers retirés, rien d'autre. */
export function normalizeSectionText(text: string): string {
  return text
    .replace(/\r\n?/g, '\n')
    .split('\n')
    .map((line) => line.replace(/[ \t ]+$/u, ''))
    .join('\n')
    .replace(/^\n+|\n+$/g, '');
}

const SECTION_NAMES: Record<string, string> = {
  verse: 'Couplet',
  refrain: 'Refrain',
  bridge: 'Pont',
  intro: 'Introduction',
  outro: 'Conclusion',
  note: 'Note',
};

/** « Couplet 2 », « Refrain »… (comme dans l'application). */
export function sectionName(type: string, number: number | null): string {
  return [SECTION_NAMES[type] ?? type, number ?? undefined]
    .filter((p) => p !== undefined)
    .join(' ');
}

/** Identifiant d'un thème : « Saint-Esprit » → « saint-esprit » (normalisation de recherche partagée). */
export function themeSlug(name: string): string {
  return fold(name).replace(/\s+/g, '-');
}
