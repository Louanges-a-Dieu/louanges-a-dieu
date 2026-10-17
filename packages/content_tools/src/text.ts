/** Utilitaires de texte partagés par la structuration et les contrôles. */

/** Espaces de fin de vers retirés ; le reste du texte est conservé tel quel. */
export const trimLineEnd = (line: string): string => line.replace(/[\s\u00a0\u202f]+$/u, '');

export const isBlank = (value: string): boolean => value.replace(/[\s\u00a0\u202f]/gu, '') === '';

/** Vers d'un paragraphe (sauts de ligne manuels compris), vers vides exclus. */
export const paragraphLines = (text: string): string[] =>
  text
    .split('\n')
    .map(trimLineEnd)
    .filter((line) => !isBlank(line));

/**
 * Forme de comparaison : minuscules, espaces normalisés, ponctuation retirée.
 * Les accents sont CONSERVÉS (« O » ≠ « Ô » doit être signalé).
 */
export const comparable = (value: string): string =>
  value
    .toLowerCase()
    .replace(/[\u00a0\u202f]/gu, ' ')
    .replace(/[’']/gu, "'")
    .replace(/[.,;:!?«»"()\-–—…]/gu, ' ')
    .replace(/\s+/gu, ' ')
    .trim();

/** Forme de recherche de similarité : comparable() sans accents. */
export const folded = (value: string): string =>
  comparable(value)
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/œ/gu, 'oe')
    .replace(/æ/gu, 'ae');
