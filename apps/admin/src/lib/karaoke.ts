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

/**
 * Passages ligne par ligne à partir des appuis : `starts[k]` est le début du
 * vers k (null : vers passé, non chanté sur l'enregistrement) ; chaque vers
 * se termine au début du suivant chanté, le dernier à `endMs`.
 */
export function cuesFromTaps(
  lines: SyncLine[],
  starts: (number | null)[],
  endMs: number,
): CueRow[] {
  const sung = lines
    .map((line, k) => ({ line, start: starts[k] ?? null }))
    .filter((x): x is { line: SyncLine; start: number } => x.start !== null);
  return sung
    .map(({ line, start }, k) => ({
      section_id: line.sectionId,
      line_index: line.lineIndex,
      start_ms: Math.round(start),
      end_ms: Math.round(k + 1 < sung.length ? sung[k + 1]!.start : endMs),
    }))
    .filter((c) => c.end_ms > c.start_ms);
}
