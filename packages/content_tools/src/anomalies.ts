import type { DraftHymn, DraftIssue } from '@lad/shared-contracts';

import type { IndexEntry } from './structure.ts';
import { comparable, folded } from './text.ts';

const issue = (
  code: string,
  severity: DraftIssue['severity'],
  numberLabel: string | null,
  message: string,
  details: Record<string, unknown> = {},
): DraftIssue => ({ code, severity, numberLabel, message, details });

/** Anomalies qui portent sur l'ensemble du recueil. */
export function documentIssues(
  hymns: DraftHymn[],
  indexEntries: IndexEntry[],
  leftIndentRegime: string[],
): DraftIssue[] {
  const issues: DraftIssue[] = [];

  // A-16 : numéro en double.
  const seen = new Map<string, number>();
  for (const h of hymns) seen.set(h.numberLabel, (seen.get(h.numberLabel) ?? 0) + 1);
  for (const [label, count] of seen) {
    if (count > 1) {
      issues.push(issue('A-16', 'blocking', label, `Numéro présent ${count} fois`));
    }
  }

  // A-01 : trous dans la numérotation.
  const numbers = new Set(hymns.filter((h) => h.numberSuffix === null).map((h) => h.numberNumeric));
  const max = Math.max(0, ...numbers);
  const missing: number[] = [];
  for (let n = 1; n <= max; n++) if (!numbers.has(n)) missing.push(n);
  if (missing.length > 0) {
    issues.push(
      issue('A-01', 'warning', null, `Numéro(s) absent(s) de la séquence : ${missing.join(', ')}`, {
        missing,
      }),
    );
  }

  // Cantiques « bis » sans cantique principal.
  for (const h of hymns) {
    for (const r of h.relations) {
      if (!seen.has(r.relatedNumberLabel)) {
        issues.push(
          issue(
            'A-16',
            'blocking',
            h.numberLabel,
            `Cantique principal ${r.relatedNumberLabel} introuvable`,
          ),
        );
      }
    }
  }

  // A-02 : recoupement avec l'index alphabétique imprimé.
  if (indexEntries.length > 0) {
    const byLabel = new Map(hymns.map((h) => [h.numberLabel, h]));
    const indexed = new Set(indexEntries.map((e) => e.numberLabel));
    for (const h of hymns) {
      if (!indexed.has(h.numberLabel)) {
        issues.push(
          issue(
            'A-02',
            'info',
            h.numberLabel,
            'Absent de l’index alphabétique imprimé (l’index de l’app est généré)',
          ),
        );
      }
    }
    for (const e of indexEntries) {
      const h = byLabel.get(e.numberLabel);
      if (!h) {
        issues.push(
          issue(
            'A-02',
            'warning',
            null,
            `L’index renvoie au n° ${e.numberLabel}, qui n’existe pas`,
            {
              title: e.title,
              paragraph: e.paragraph,
            },
          ),
        );
      } else if (
        !comparable(h.title).startsWith(comparable(e.title)) &&
        !comparable(e.title).startsWith(comparable(h.title))
      ) {
        issues.push(
          issue('A-02', 'warning', h.numberLabel, 'Titre différent dans l’index', {
            indexTitle: e.title,
            title: h.title,
          }),
        );
      }
    }
  }

  // A-03 : deux conventions de mise en forme des strophes.
  if (leftIndentRegime.length > 0) {
    issues.push(
      issue(
        'A-03',
        'info',
        null,
        `${leftIndentRegime.length} cantique(s) utilisent un retrait gauche pour les strophes (régime 2)`,
        {
          first: leftIndentRegime[0],
          count: leftIndentRegime.length,
        },
      ),
    );
  }

  // A-11 : orthographes différentes d'un même livre biblique.
  const books = new Map<string, Set<string>>();
  for (const h of hymns) {
    for (const r of h.bibleReferences) {
      const key = folded(r.book).replace(/s$/u, '');
      if (!books.has(key)) books.set(key, new Set());
      books.get(key)!.add(r.book);
    }
  }
  for (const variants of books.values()) {
    if (variants.size > 1) {
      issues.push(
        issue('A-11', 'info', null, `Orthographes différentes : ${[...variants].join(' / ')}`, {
          variants: [...variants],
        }),
      );
    }
  }

  issues.push(...similarityIssues(hymns));
  return issues;
}

/** Ensemble des triplets de mots (sans accents) du texte d'un cantique. */
function shingles(h: DraftHymn): Set<string> {
  const words = folded(h.sections.map((s) => s.text).join(' '))
    .split(' ')
    .filter((w) => w.length > 2);
  const out = new Set<string>();
  for (let i = 0; i + 2 < words.length; i++) out.add(`${words[i]} ${words[i + 1]} ${words[i + 2]}`);
  return out;
}

/**
 * A-12 : textes identiques ou proches (doublons, variantes, traductions).
 * Similarité de Jaccard sur les triplets de mots ; candidats trouvés par index
 * inversé pour éviter de comparer toutes les paires.
 */
export function similarityIssues(hymns: DraftHymn[], minShared = 4): DraftIssue[] {
  const sets = hymns.map(shingles);
  const inverted = new Map<string, number[]>();
  sets.forEach((set, i) => {
    for (const s of set) {
      const list = inverted.get(s);
      if (list) list.push(i);
      else inverted.set(s, [i]);
    }
  });

  const shared = new Map<string, number>();
  for (const list of inverted.values()) {
    if (list.length > 50) continue; // formule trop courante pour être significative
    for (let a = 0; a < list.length; a++) {
      for (let b = a + 1; b < list.length; b++) {
        const key = `${list[a]}:${list[b]}`;
        shared.set(key, (shared.get(key) ?? 0) + 1);
      }
    }
  }

  const issues: DraftIssue[] = [];
  for (const [key, count] of shared) {
    if (count < minShared) continue;
    const [a, b] = key.split(':').map(Number) as [number, number];
    const union = sets[a]!.size + sets[b]!.size - count;
    const jaccard = union === 0 ? 0 : count / union;
    const containment = count / Math.min(sets[a]!.size, sets[b]!.size);
    if (jaccard < 0.3 && containment < 0.6) continue;
    const ha = hymns[a]!;
    const hb = hymns[b]!;
    const probable = jaccard >= 0.6;
    issues.push(
      issue(
        'A-12',
        probable ? 'warning' : 'info',
        ha.numberLabel,
        probable
          ? `Doublon probable du n° ${hb.numberLabel}`
          : jaccard >= 0.3
            ? `Texte proche du n° ${hb.numberLabel} (variante ?)`
            : `Texte en grande partie inclus dans le n° ${hb.numberLabel} ou l’incluant`,
        {
          other: hb.numberLabel,
          jaccard: Math.round(jaccard * 100) / 100,
          containment: Math.round(containment * 100) / 100,
        },
      ),
    );
  }
  return issues.sort((x, y) =>
    String(x.details.other).localeCompare(String(y.details.other), 'fr', { numeric: true }),
  );
}
