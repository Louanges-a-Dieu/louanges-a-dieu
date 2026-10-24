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

/** Numéro d'un cantique : « 1139 », « 37bis », « 37 bis », « 12 TER » (null si invalide). */
export function parseHymnNumber(
  input: string,
): { label: string; numeric: number; suffix: 'bis' | 'ter' | null } | null {
  const m = /^\s*0*(\d{1,4})\s*(bis|ter)?\s*$/i.exec(input);
  if (!m || Number(m[1]) === 0) return null;
  const numeric = Number(m[1]);
  const suffix = (m[2]?.toLowerCase() ?? null) as 'bis' | 'ter' | null;
  return { label: `${numeric}${suffix ?? ''}`, numeric, suffix };
}

/** Paroles saisies d'un bloc : une strophe par paragraphe (ligne vide entre deux). */
export function splitStanzas(text: string): string[] {
  return normalizeSectionText(text)
    .split(/\n[ \t]*\n+/)
    .map(normalizeSectionText)
    .filter((s) => s.length > 0);
}
