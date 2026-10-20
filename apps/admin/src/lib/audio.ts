import { sungOrder, type HymnSection } from '@lad/shared-contracts';

import type { SyncLine } from './karaoke';
import { sectionName } from './text';

/** Types d'enregistrement, avec le nom affiché dans l'application. */
export const MEDIA_LABELS: Record<string, string> = {
  melody: 'Mélodie',
  accompaniment: 'Accompagnement',
  choir: 'Chorale',
  soprano: 'Soprano',
  alto: 'Alto',
  tenor: 'Ténor',
  bass: 'Basse',
  instrumental: 'Instrumental',
  other: 'Enregistrement',
};

/** « 3:05 », « 1:02:07 » ou « 185 » (secondes) → secondes ; vide → null. */
export function parseDuration(value: string): number | null | 'invalide' {
  const v = value.trim();
  if (v === '') return null;
  if (/^\d+([.,]\d+)?$/.test(v)) {
    const seconds = Number(v.replace(',', '.'));
    return seconds > 0 ? seconds : 'invalide';
  }
  const ms = parseClock(v);
  return ms === null || ms === 0 ? 'invalide' : ms / 1000;
}

/** « m:ss » ou « h:mm:ss » (décimales de seconde admises) → millisecondes. */
export function parseClock(value: string): number | null {
  const m = /^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?$/.exec(value.trim());
  if (!m) return null;
  const [, h, min, s, frac] = m;
  if (Number(s) > 59 || (h !== undefined && Number(min) > 59)) return null;
  return (
    ((Number(h ?? 0) * 60 + Number(min)) * 60 + Number(s)) * 1000 +
    Number((frac ?? '').padEnd(3, '0') || 0)
  );
}

/** Millisecondes → « 3:05 » (« 1:02:07 » au-delà d'une heure, « 0:12.5 » si besoin). */
export function formatClock(ms: number): string {
  const total = Math.floor(ms / 1000);
  const rest = ms % 1000;
  const h = Math.floor(total / 3600);
  const min = Math.floor((total % 3600) / 60);
  const s = String(total % 60).padStart(2, '0');
  const frac = rest ? `.${String(rest).padStart(3, '0').replace(/0+$/, '')}` : '';
  return h ? `${h}:${String(min).padStart(2, '0')}:${s}${frac}` : `${min}:${s}${frac}`;
}

export interface SectionRef {
  id: string;
  section_type: string;
  section_number: number | null;
}

export interface SegmentRow {
  section_id: string | null;
  start_ms: number;
  end_ms: number;
  line_index?: number | null;
}

/** Marqueur de fin d'enregistrement, et passage sans paroles. */
const END = /^fin$/i;
const NO_LYRICS = /^[-–—]$/;

/**
 * Libellés acceptés pour une section : son nom (« Couplet 2 », « Refrain »)
 * s'il est unique dans le cantique, et toujours « #n » (n-ième section
 * imprimée).
 */
function sectionLabels(sections: SectionRef[]): Map<string, string> {
  const byName = new Map<string, string[]>();
  sections.forEach((s) => {
    const name = sectionName(s.section_type, s.section_number).toLowerCase();
    byName.set(name, [...(byName.get(name) ?? []), s.id]);
  });
  const labels = new Map<string, string>();
  for (const [name, ids] of byName) if (ids.length === 1) labels.set(name, ids[0]!);
  sections.forEach((s, i) => labels.set(`#${i + 1}`, s.id));
  return labels;
}

/** Libellé d'une section pour le texte des passages (inverse de {@link parseSegments}). */
function labelOf(sectionId: string | null, sections: SectionRef[]): string {
  if (sectionId === null) return '-';
  const i = sections.findIndex((s) => s.id === sectionId);
  if (i < 0) return '-';
  const s = sections[i]!;
  const name = sectionName(s.section_type, s.section_number);
  const unique = sections.filter(
    (o) => sectionName(o.section_type, o.section_number) === name,
  ).length;
  return unique === 1 ? name : `#${i + 1}`;
}

/**
 * Passages d'un enregistrement, une ligne par début de passage, puis la fin :
 *
 *     0:00 Couplet 1
 *     0:32 Refrain
 *     1:05 #3
 *     1:40 -          (passage sans paroles)
 *     2:10 fin
 *
 * Chaque passage se termine au début du suivant.
 */
export function parseSegments(
  text: string,
  sections: SectionRef[],
): { segments: SegmentRow[] } | { error: string } {
  const labels = sectionLabels(sections);
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l !== '');
  if (lines.length === 0) return { segments: [] };

  const marks: { at: number; sectionId: string | null | 'fin' }[] = [];
  for (const [n, line] of lines.entries()) {
    const m = /^(\S+)\s+(.+)$/.exec(line);
    const at = m ? parseClock(m[1]!) : null;
    if (!m || at === null) {
      return { error: `Ligne ${n + 1} : « ${line} » — attendu « m:ss Libellé ».` };
    }
    const label = m[2]!.trim();
    let sectionId: string | null | 'fin';
    if (END.test(label)) sectionId = 'fin';
    else if (NO_LYRICS.test(label)) sectionId = null;
    else {
      const found = labels.get(label.toLowerCase());
      if (!found) {
        return {
          error: `Ligne ${n + 1} : section « ${label} » inconnue ou ambiguë (utiliser « #n », n-ième section).`,
        };
      }
      sectionId = found;
    }
    const previous = marks.at(-1);
    if (previous && at <= previous.at) {
      return { error: `Ligne ${n + 1} : les temps doivent être croissants.` };
    }
    if (previous?.sectionId === 'fin') {
      return { error: `Ligne ${n + 1} : rien ne peut suivre « fin ».` };
    }
    marks.push({ at, sectionId });
  }
  if (marks.at(-1)!.sectionId !== 'fin') {
    return { error: 'Terminer par la fin de l’enregistrement : « m:ss fin ».' };
  }
  const segments: SegmentRow[] = [];
  for (let i = 0; i < marks.length - 1; i++) {
    const { at, sectionId } = marks[i]!;
    segments.push({
      section_id: sectionId as string | null,
      start_ms: at,
      end_ms: marks[i + 1]!.at,
    });
  }
  return { segments };
}

/** Texte modifiable des passages existants. */
export function formatSegments(segments: SegmentRow[], sections: SectionRef[]): string {
  if (segments.length === 0) return '';
  return [
    ...segments.map((s) => `${formatClock(s.start_ms)} ${labelOf(s.section_id, sections)}`),
    `${formatClock(segments.at(-1)!.end_ms)} fin`,
  ].join('\n');
}

/** Adresse publique d'un fichier, si l'hébergement est configuré. */
export function audioUrl(storageKey: string): string | null {
  const base = (process.env.AUDIO_BASE_URL ?? '').replace(/\/+$/, '');
  if (!base.startsWith('https://')) return null;
  return `${base}/${storageKey.split('/').map(encodeURIComponent).join('/')}`;
}

/** Vers à synchroniser pour le karaoké, dans l'ordre chanté (refrain répété). */
export function syncLines(sections: HymnSection[]): SyncLine[] {
  return sungOrder(sections).flatMap((section) =>
    section.lines.map((line, i) => ({
      sectionId: section.id,
      lineIndex: i,
      text: line.text,
      section: i === 0 ? sectionName(section.type, section.number) : null,
    })),
  );
}
