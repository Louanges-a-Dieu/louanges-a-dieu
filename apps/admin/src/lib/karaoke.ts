// Synchronisation karaoké : calcul pur, sans dépendance (utilisé dans le
// navigateur par l'outil de synchronisation).

/** Vers à synchroniser pour le karaoké. */
export interface SyncLine {
  sectionId: string;
  lineIndex: number;
  text: string;
  /** « Couplet 1 », « Refrain »… sur le premier vers de chaque section. */
  section: string | null;
}

export interface CueRow {
  section_id: string;
  line_index: number;
  start_ms: number;
  end_ms: number;
}

/** Appui pendant la synchronisation : début d'un vers (null : vers non chanté) ou pause instrumentale. */
export type SyncEvent = { kind: 'line'; at: number | null } | { kind: 'pause'; at: number };

/**
 * Début et fin de chaque vers d'après les appuis : une pause instrumentale
 * termine le dernier vers chanté sans en commencer un autre.
 */
export function replay(events: SyncEvent[]): {
  starts: (number | null)[];
  ends: (number | null)[];
} {
  const starts: (number | null)[] = [];
  const ends: (number | null)[] = [];
  let last = -1;
  for (const e of events) {
    if (e.kind === 'line') {
      starts.push(e.at);
      ends.push(null);
      if (e.at !== null) last = starts.length - 1;
    } else if (last >= 0) {
      ends[last] = e.at;
    }
  }
  return { starts, ends };
}

/** Une pause n'a de sens que juste après le début d'un vers chanté. */
export function canPause(events: SyncEvent[]): boolean {
  const last = events.at(-1);
  return last?.kind === 'line' && last.at !== null;
}

/**
 * Passages ligne par ligne : `starts[k]` est le début du vers k (null : vers
 * passé, non chanté sur l'enregistrement). Un vers se termine à sa pause
 * (`ends[k]`), sinon au début du suivant chanté, le dernier à `endMs`.
 */
export function cuesFromTaps(
  lines: SyncLine[],
  starts: (number | null)[],
  endMs: number,
  ends: (number | null)[] = [],
): CueRow[] {
  const sung = lines
    .map((line, k) => ({ line, start: starts[k] ?? null, end: ends[k] ?? null }))
    .filter((x): x is { line: SyncLine; start: number; end: number | null } => x.start !== null);
  return sung
    .map(({ line, start, end }, k) => ({
      section_id: line.sectionId,
      line_index: line.lineIndex,
      start_ms: Math.round(start),
      end_ms: Math.round(end ?? (k + 1 < sung.length ? sung[k + 1]!.start : endMs)),
    }))
    .filter((c) => c.end_ms > c.start_ms);
}

// ------------------------------------------------- ajustement après coup

/** Vers déjà synchronisé, ajustable : début et fin modifiables. */
export interface EditableCue {
  sectionId: string;
  lineIndex: number;
  text: string;
  /** Nom de la section quand elle change par rapport au vers précédent. */
  section: string | null;
  start: number;
  end: number;
}

/**
 * Passages synchronisés (dans l'ordre de l'enregistrement) avec le texte de
 * leur vers, pour les ajuster sans tout refaire.
 */
export function editableCues(cues: CueRow[], lines: SyncLine[]): EditableCue[] {
  const text = new Map(lines.map((l) => [`${l.sectionId}|${l.lineIndex}`, l.text]));
  const names = new Map(
    lines.filter((l) => l.section !== null).map((l) => [l.sectionId, l.section]),
  );
  return cues.map((c, i) => ({
    sectionId: c.section_id,
    lineIndex: c.line_index,
    text: text.get(`${c.section_id}|${c.line_index}`) ?? `Vers ${c.line_index + 1}`,
    section:
      i === 0 || cues[i - 1]!.section_id !== c.section_id
        ? (names.get(c.section_id) ?? null)
        : null,
    start: c.start_ms,
    end: c.end_ms,
  }));
}

/** Problème d'un vers (null : correct) : fin avant le début, chevauchement. */
export function cueProblems(cues: EditableCue[]): (string | null)[] {
  return cues.map((c, i) => {
    if (c.start < 0) return 'début négatif';
    if (c.end <= c.start) return 'la fin doit suivre le début';
    if (i > 0 && c.start < cues[i - 1]!.end) return 'commence avant la fin du vers précédent';
    return null;
  });
}

/** Décale de `deltaMs` les vers à partir de `from` (jamais avant 0). */
export function shiftCues(cues: EditableCue[], deltaMs: number, from = 0): EditableCue[] {
  return cues.map((c, i) =>
    i < from
      ? c
      : { ...c, start: Math.max(0, c.start + deltaMs), end: Math.max(1, c.end + deltaMs) },
  );
}

/** Lignes à enregistrer (même format que la synchronisation complète). */
export function toCueRows(cues: EditableCue[]): CueRow[] {
  return cues.map((c) => ({
    section_id: c.sectionId,
    line_index: c.lineIndex,
    start_ms: Math.round(c.start),
    end_ms: Math.round(c.end),
  }));
}

/** « 1:05.3 » (au dixième). */
export function tenths(ms: number): string {
  const s = Math.max(0, Math.round(ms / 100)) / 10;
  return `${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, '0')}`;
}

/** « 1:05.3 », « 65.3 » ou « 1:05 » → millisecondes (null si illisible). */
export function parseTenths(value: string): number | null {
  const m = /^\s*(?:(\d+):)?(\d+)(?:[.,](\d{1,3}))?\s*$/.exec(value);
  if (!m) return null;
  const [, min, sec, frac] = m;
  if (min !== undefined && Number(sec) > 59) return null;
  return (Number(min ?? 0) * 60 + Number(sec)) * 1000 + Number((frac ?? '').padEnd(3, '0') || 0);
}
