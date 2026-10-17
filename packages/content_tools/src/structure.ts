import type {
  DraftBibleReference,
  DraftHymn,
  DraftIssue,
  DraftSection,
} from '@lad/shared-contracts';

import type { Paragraph } from './docx.ts';
import { comparable, isBlank, paragraphLines, trimLineEnd } from './text.ts';

/**
 * Structuration déterministe du recueil à partir de la mise en forme directe
 * (voir IMPLEMENTATION_PLAN.md §3.2) :
 *   numéro       : centré, gras, « 37 » ou « 37bis »
 *   titre        : premier paragraphe centré qui suit le numéro
 *   strophe      : début marqué par un retrait (1ʳᵉ ligne ou gauche selon le régime),
 *                  fin marquée par un espacement après ≥ 80
 *   refrain      : paragraphe encadré (bordure)
 *   référence    : aligné à droite, « — Psaumes 47 — »
 *   séparateur   : « ✤ »
 *   fin          : « Index des cantiques »
 * Rien n'est deviné au-delà de ces règles : tout écart produit une anomalie.
 */

const NUMBER = /^(\d{1,4}) ?(bis|ter)?$/iu;
const REFERENCE = /^[—–-]\s*(.+?)\s*[—–-]$/u;
const SEPARATOR = '✤';
const INDEX_HEADING = 'Index des cantiques';
const STANZA_END_SPACING = 80;
const LONG_SECTION_LINES = 12;

export interface IndexEntry {
  title: string;
  numberLabel: string;
  paragraph: number;
}

export interface StructureResult {
  hymns: DraftHymn[];
  issues: DraftIssue[];
  indexEntries: IndexEntry[];
  /** Cantiques dont les strophes commencent par un retrait gauche (régime 2). */
  leftIndentRegime: string[];
}

const issue = (
  code: string,
  severity: DraftIssue['severity'],
  numberLabel: string | null,
  message: string,
  details: Record<string, unknown> = {},
): DraftIssue => ({ code, severity, numberLabel, message, details });

function parseNumber(
  p: Paragraph,
): { label: string; numeric: number; suffix: 'bis' | 'ter' | null } | null {
  if (p.align !== 'center' || p.boldRatio < 0.5) return null;
  const m = NUMBER.exec(p.text.trim());
  if (!m) return null;
  const suffix = (m[2]?.toLowerCase() as 'bis' | 'ter' | undefined) ?? null;
  return { label: `${Number(m[1])}${suffix ?? ''}`, numeric: Number(m[1]), suffix };
}

/** « Psaumes 47 », « Jean 3.16 », « 1 Jean 4.8-10 », « Psaumes 1-3 ». */
export function parseBibleReference(display: string): DraftBibleReference | null {
  const m = /^(.+?)\s+(\d+)(?:[.:,](\d+))?(?:\s*[-–]\s*(?:(\d+)[.:,])?(\d+))?$/u.exec(
    display.trim(),
  );
  if (!m) return null;
  const chapterStart = Number(m[2]);
  const verseStart = m[3] ? Number(m[3]) : null;
  let chapterEnd: number | null = null;
  let verseEnd: number | null = null;
  if (m[4]) {
    chapterEnd = Number(m[4]);
    verseEnd = Number(m[5]);
  } else if (m[5]) {
    if (verseStart === null) chapterEnd = Number(m[5]);
    else verseEnd = Number(m[5]);
  }
  return {
    displayText: display.trim(),
    book: m[1]!.trim(),
    chapterStart,
    verseStart,
    chapterEnd,
    verseEnd,
  };
}

export type MarkerKind = 'standard' | 'variant' | 'ambiguous' | 'midline';

/**
 * Classe les marqueurs de répétition d'un vers. Seules les formes en fin de
 * vers sont annotées à la publication (private.line_repeat, migration 0008).
 */
export function classifyRepeatMarker(line: string): { kind: MarkerKind; marker: string } | null {
  const end = /(\([^()]{1,12}\))[\s\p{P}]*$/u.exec(line);
  if (end) {
    const marker = end[1]!;
    const inner = marker.slice(1, -1).trim().toLowerCase();
    if (/^(bis|ter|\d+x)$/u.test(inner)) return { kind: 'standard', marker };
    if (/^(\d+ [x×]|[x×] ?\d+|\d+×)$/u.test(inner)) return { kind: 'variant', marker };
    if (/^\d+$/u.test(inner)) return { kind: 'ambiguous', marker };
  }
  const mid = /\((bis|ter|\d+ ?[x×])\)/iu.exec(line);
  if (mid && !end?.[1]?.toLowerCase().includes(mid[1]!.toLowerCase())) {
    return { kind: 'midline', marker: mid[0] };
  }
  return null;
}

/** Parenthèses qui ne sont pas des marqueurs de répétition (réponses chantées…). */
export function otherParentheticals(line: string): string[] {
  return [...line.matchAll(/\(([^()]{1,40})\)/gu)]
    .map((m) => m[0])
    .filter((p) => !/^\((bis|ter|\d+ ?[x×]|[x×] ?\d+|\d+)\)$/iu.test(p));
}

export function structure(paragraphs: Paragraph[]): StructureResult {
  const issues: DraftIssue[] = [];
  const hymns: DraftHymn[] = [];
  const leftIndentRegime = new Set<string>();

  const indexStart = paragraphs.findIndex(
    (p) => p.text.trim() === INDEX_HEADING && p.align === 'center',
  );
  const bodyEnd = indexStart === -1 ? paragraphs.length : indexStart;
  if (indexStart === -1) {
    issues.push(issue('A-17', 'warning', null, 'Titre « Index des cantiques » introuvable'));
  }

  const starts: number[] = [];
  for (let i = 0; i < bodyEnd; i++) {
    if (parseNumber(paragraphs[i]!)) starts.push(i);
  }

  starts.forEach((start, k) => {
    const end = k + 1 < starts.length ? starts[k + 1]! : bodyEnd;
    const number = parseNumber(paragraphs[start]!)!;
    const label = number.label;
    const sections: (DraftSection & { closed: boolean; lines: string[] })[] = [];
    const refs: DraftBibleReference[] = [];
    let title: string | null = null;
    let lastUsed = start;
    let afterSeparator = false;

    for (let i = start + 1; i < end; i++) {
      const p = paragraphs[i]!;
      if (isBlank(p.text)) continue;
      const text = p.text.trim();

      if (text === SEPARATOR) {
        afterSeparator = true;
        lastUsed = i;
        continue;
      }
      if (afterSeparator) {
        issues.push(
          issue('A-17', 'warning', label, 'Texte situé après le séparateur « ✤ »', {
            paragraph: i,
            text: text.slice(0, 80),
          }),
        );
        continue;
      }
      if (title === null && sections.length === 0) {
        if (p.align === 'center') {
          title = text;
          lastUsed = i;
          continue;
        }
        issues.push(
          issue('A-19', 'blocking', label, 'Titre centré introuvable après le numéro', {
            paragraph: i,
          }),
        );
        title = '';
      }

      const ref = p.align === 'right' ? REFERENCE.exec(text) : null;
      if (ref) {
        const parsed = parseBibleReference(ref[1]!);
        if (parsed) refs.push(parsed);
        else {
          issues.push(
            issue('A-18', 'blocking', label, 'Référence biblique non analysable', {
              paragraph: i,
              text,
            }),
          );
        }
        lastUsed = i;
        continue;
      }

      if (p.align === 'center' || p.align === 'right') {
        issues.push(
          issue(
            'A-17',
            'warning',
            label,
            'Paragraphe à l’alignement inattendu, traité comme un vers',
            {
              paragraph: i,
              align: p.align,
              text: text.slice(0, 80),
            },
          ),
        );
      }

      const type: DraftSection['type'] = p.border ? 'refrain' : 'verse';
      if ((type === 'refrain') !== p.italicRatio >= 0.5) {
        issues.push(
          issue(
            'A-07',
            'warning',
            label,
            type === 'refrain'
              ? 'Vers de refrain (encadré) non italique'
              : 'Vers en italique hors d’un refrain encadré',
            { paragraph: i, text: text.slice(0, 80) },
          ),
        );
      }

      const firstIndent = (p.indentFirstLine ?? 0) > 0;
      const leftIndent = type === 'verse' && (p.indentLeft ?? 0) > 0;
      if (leftIndent && !firstIndent) leftIndentRegime.add(label);
      const startsStanza = type === 'verse' && (firstIndent || leftIndent);

      const current = sections.at(-1);
      let section = current;
      if (!current || current.type !== type || current.closed || startsStanza) {
        section = { type, order: sections.length, text: '', closed: false, lines: [] };
        sections.push(section);
      }
      section!.lines.push(...paragraphLines(p.text));
      if (p.manualBreaks > 0) {
        issues.push(
          issue('A-04', 'info', label, 'Sauts de ligne manuels (vers séparés automatiquement)', {
            paragraph: i,
            breaks: p.manualBreaks,
          }),
        );
      }
      if ((p.spacingAfter ?? 0) >= STANZA_END_SPACING) section!.closed = true;
      lastUsed = i;
    }

    const cleanSections: DraftSection[] = sections
      .filter((s) => s.lines.length > 0)
      .map((s, order) => ({ type: s.type, order, text: s.lines.join('\n') }));

    for (const s of sections) {
      if (s.lines.length > LONG_SECTION_LINES) {
        issues.push(
          issue(
            'A-05',
            'warning',
            label,
            `Section de ${s.lines.length} vers : séparation de strophes manquante ?`,
            {
              section: s.order,
              lines: s.lines.length,
            },
          ),
        );
      }
      if (s.lines.length === 1 && sections.length > 1) {
        issues.push(
          issue('A-06', 'warning', label, 'Section d’un seul vers', {
            section: s.order,
            text: s.lines[0],
          }),
        );
      }
      for (const line of s.lines) {
        const marker = classifyRepeatMarker(line);
        if (marker && marker.kind !== 'standard') {
          const message = {
            variant: 'Marqueur de répétition de forme non standard (reconnu)',
            ambiguous: 'Marqueur ambigu, non interprété comme répétition',
            midline: 'Marqueur de répétition en milieu de vers, non interprété',
          }[marker.kind];
          issues.push(issue('A-09', 'warning', label, message, { marker: marker.marker, line }));
        }
        for (const other of otherParentheticals(line)) {
          issues.push(
            issue('A-10', 'info', label, 'Parenthèse conservée comme texte (réponse chantée ?)', {
              text: other,
              line,
            }),
          );
        }
      }
    }

    if (cleanSections.length === 0) {
      issues.push(issue('A-15', 'blocking', label, 'Cantique sans aucun vers'));
    }

    const openingLine = cleanSections[0]?.text.split('\n')[0] ?? null;
    const effectiveTitle = title && !isBlank(title) ? title : (openingLine ?? label);
    if (title && openingLine && !comparable(openingLine).startsWith(comparable(title))) {
      issues.push(
        issue('A-08', 'warning', label, 'Le titre ne reprend pas exactement le premier vers', {
          title,
          openingLine,
        }),
      );
    }

    hymns.push({
      numberLabel: label,
      numberNumeric: number.numeric,
      numberSuffix: number.suffix,
      title: trimLineEnd(effectiveTitle),
      openingLine,
      sourceParagraphStart: start,
      sourceParagraphEnd: lastUsed,
      sections: cleanSections.length > 0 ? cleanSections : [],
      bibleReferences: refs,
      relations:
        number.suffix === 'bis'
          ? [{ type: 'bis_of', relatedNumberLabel: `${number.numeric}` }]
          : [],
    });
  });

  // Index alphabétique : « Titre\tNuméro » ou « Titre Numéro[, Numéro] ».
  const indexEntries: IndexEntry[] = [];
  if (indexStart !== -1) {
    for (let i = indexStart + 1; i < paragraphs.length; i++) {
      const text = paragraphs[i]!.text.trim();
      if (/^achevé d.imprimer/iu.test(text)) break;
      const m = /^(.*?)[\s\t]*((?:\d{1,4} ?(?:bis|ter)?)(?:\s*,\s*\d{1,4} ?(?:bis|ter)?)*)$/iu.exec(
        text,
      );
      if (!m || isBlank(m[1]!)) continue;
      for (const n of m[2]!.split(',')) {
        indexEntries.push({
          title: m[1]!.trim(),
          numberLabel: n.replace(/\s/gu, '').toLowerCase(),
          paragraph: i,
        });
      }
    }
  }

  return { hymns, issues, indexEntries, leftIndentRegime: [...leftIndentRegime] };
}
