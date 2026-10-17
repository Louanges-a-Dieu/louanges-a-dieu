import type { DraftHymn } from '@lad/shared-contracts';

import { paragraphLines } from './text.ts';

/**
 * Contrôle de fidélité aller-retour (tâche 3.7).
 *
 * Le texte source est relu par une méthode INDÉPENDANTE de l'extracteur SAX
 * (expressions régulières sur le XML brut), puis comparé vers par vers au
 * catalogue structuré : aucun vers ne doit être perdu, ajouté, modifié ou
 * déplacé. Seuls sont écartés le numéro, le titre, les références « — … — »
 * et les séparateurs « ✤ », qui ont leur propre champ.
 */

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };

function decode(value: string): string {
  return value.replace(/&(#x[0-9a-f]+|#\d+|\w+);/giu, (whole, e: string) => {
    if (e.startsWith('#x') || e.startsWith('#X'))
      return String.fromCodePoint(Number.parseInt(e.slice(2), 16));
    if (e.startsWith('#')) return String.fromCodePoint(Number.parseInt(e.slice(1), 10));
    return ENTITIES[e] ?? whole;
  });
}

/** Texte de chaque <w:p> du document, par une lecture naïve du XML. */
export function rawParagraphTexts(documentXml: string): string[] {
  const body = documentXml.slice(documentXml.indexOf('<w:body'));
  const parts = body.split(/<w:p(?=[\s>/])/u).slice(1);
  return parts.map((part) => {
    const content = part.split(/<\/w:p>/u)[0] ?? '';
    const withBreaks = content
      .replace(/<w:br(?![^>]*w:type="(?:page|column)")[^>]*\/>/gu, '\u0001')
      .replace(/<w:cr\s*\/>/gu, '\u0001')
      .replace(/<w:tab\s*\/>/gu, '\u0002');
    let text = '';
    const tokens = withBreaks.matchAll(/<w:t(?:\s[^>]*)?>([^<]*)<\/w:t>|\u0001|\u0002/gu);
    for (const t of tokens) {
      if (t[0] === '\u0001') text += '\n';
      else if (t[0] === '\u0002') text += '\t';
      else text += decode(t[1] ?? '');
    }
    return text.normalize('NFC');
  });
}

export interface FidelityMismatch {
  numberLabel: string;
  expected: string[];
  actual: string[];
}

export interface FidelityReport {
  paragraphCountMatches: boolean;
  hymnsChecked: number;
  mismatches: FidelityMismatch[];
}

export function checkFidelity(
  documentXml: string,
  extractedParagraphCount: number,
  hymns: DraftHymn[],
  bodyEnd: number,
): FidelityReport {
  const raw = rawParagraphTexts(documentXml);
  const mismatches: FidelityMismatch[] = [];

  hymns.forEach((hymn, k) => {
    const end = k + 1 < hymns.length ? hymns[k + 1]!.sourceParagraphStart : bodyEnd;
    const expected: string[] = [];
    let titleSkipped = false;
    for (let i = hymn.sourceParagraphStart + 1; i < end; i++) {
      const text = (raw[i] ?? '').trim();
      if (text === '' || text === '✤') continue;
      if (!titleSkipped) {
        titleSkipped = true;
        continue;
      }
      if (/^[—–-]\s*.+?\s*[—–-]$/u.test(text)) continue;
      expected.push(...paragraphLines(raw[i]!));
    }
    const actual = hymn.sections.flatMap((s) => s.text.split('\n'));
    if (expected.length !== actual.length || expected.some((line, j) => line !== actual[j])) {
      mismatches.push({ numberLabel: hymn.numberLabel, expected, actual });
    }
  });

  return {
    paragraphCountMatches: raw.length === extractedParagraphCount,
    hymnsChecked: hymns.length,
    mismatches,
  };
}
