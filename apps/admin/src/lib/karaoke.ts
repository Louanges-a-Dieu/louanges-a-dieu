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
