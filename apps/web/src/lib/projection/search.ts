import { fold, type PublishedHymn } from '@lad/shared-contracts';

/**
 * Recherche de la console : numéro exact d'abord (« 37bis », « 37 bis »),
 * puis numéros commençant par la saisie, puis titres et premiers vers.
 */
export function searchHymns(hymns: PublishedHymn[], query: string, limit = 30): PublishedHymn[] {
  const q = fold(query);
  if (!q) return [];
  const compact = q.replace(/\s+/g, '');
  const results: PublishedHymn[] = [];
  const seen = new Set<string>();
  const add = (h: PublishedHymn) => {
    if (!seen.has(h.id) && results.length < limit) {
      seen.add(h.id);
      results.push(h);
    }
  };
  const byNumber = [...hymns].sort(
    (a, b) => a.numberNumeric - b.numberNumeric || a.numberLabel.localeCompare(b.numberLabel),
  );
  if (/^\d+(bis|ter)?$/.test(compact)) {
    byNumber.filter((h) => h.numberLabel === compact).forEach(add);
    byNumber.filter((h) => h.numberLabel.startsWith(compact)).forEach(add);
  }
  for (const h of byNumber) {
    const text = fold(`${h.title} ${h.openingLine ?? ''}`);
    if (text.startsWith(q) || text.includes(` ${q}`)) add(h);
  }
  return results;
}
