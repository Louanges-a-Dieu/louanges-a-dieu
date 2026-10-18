/**
 * Normalisation de recherche (ADR-007), identique à l'implémentation Dart
 * (apps/mobile/lib/core/search/normalize.dart) : minuscules, accents retirés,
 * « œ » → « oe », apostrophes, ponctuation et espaces → un seul espace.
 * Cas de référence : fixtures/search/normalization.json.
 */
const MAP: Record<string, string> = {
  à: 'a',
  á: 'a',
  â: 'a',
  ã: 'a',
  ä: 'a',
  å: 'a',
  æ: 'ae',
  œ: 'oe',
  ç: 'c',
  è: 'e',
  é: 'e',
  ê: 'e',
  ë: 'e',
  ì: 'i',
  í: 'i',
  î: 'i',
  ï: 'i',
  ñ: 'n',
  ò: 'o',
  ó: 'o',
  ô: 'o',
  õ: 'o',
  ö: 'o',
  ù: 'u',
  ú: 'u',
  û: 'u',
  ü: 'u',
  ý: 'y',
  ÿ: 'y',
};

export function fold(input: string): string {
  let out = '';
  for (const char of input.toLowerCase()) {
    out += MAP[char] ?? (/[a-z0-9]/.test(char) ? char : ' ');
  }
  return out.replace(/\s+/g, ' ').trim();
}
