import { createHash } from 'node:crypto';

import type pg from 'pg';

import {
  CorrectionMatcher,
  type CorrectionRow,
  type Match,
  type Passage,
  type TextUnit,
  type UnitKind,
} from './corrections.ts';
import { actAsEditor } from './db.ts';

/**
 * Propositions de correction (Q-04, A-13) : du tableur à la file éditoriale.
 *
 * Le rapprochement se fait sur le texte ACTUEL de la copie de travail, lu dans
 * la même transaction que le chargement : les positions envoyées à
 * `public.import_corrections` (migration 0027) sont donc exactes. Seules les
 * propositions encore utiles entrent dans la file (à appliquer, à arbitrer,
 * introuvables) ; les corrections déjà faites et celles refusées dans le
 * tableur (« Non ») sont seulement comptées.
 */

export const CORRECTIONS_PARSER_VERSION = 'corrections-1';

export interface SuggestionPassage {
  unit: UnitKind;
  sectionId: string | null;
  /** Position en caractères Unicode (comme PostgreSQL). */
  offset: number;
  current: string;
  /** Texte corrigé ; null si le passage a été retouché depuis (à arbitrer). */
  replacement: string | null;
  /** Vers entiers qui contiennent le passage, pour la relecture. */
  context: string;
}

export interface Suggestion {
  /** Identifie la proposition d'un chargement à l'autre (fichier, feuille, ligne, cantique). */
  key: string;
  status: 'pending' | 'conflict' | 'not_found';
  hymnId: string | null;
  passages: SuggestionPassage[];
  source: Omit<CorrectionRow, 'row'> & { row: number };
}

export type CorrectionStats = Record<Match['status'], number>;

export interface CorrectionsPayload {
  format: 'lad.corrections';
  version: 1;
  source: { filename: string; sha256: string; parserVersion: string };
  editionId: string;
  stats: CorrectionStats;
  suggestions: Suggestion[];
}

function context(text: string, offset: number, length: number): string {
  const chars = [...text];
  const start = chars.slice(0, offset).lastIndexOf('\n') + 1;
  const after = chars.slice(offset + length).indexOf('\n');
  const end = after < 0 ? chars.length : offset + length + after;
  return chars.slice(start, end).join('');
}

function toPassage(p: Passage & { replacement?: string | undefined }): SuggestionPassage {
  return {
    unit: p.unit.unit,
    sectionId: p.unit.sectionId,
    offset: p.offset,
    current: p.current,
    replacement: p.replacement ?? null,
    context: context(p.unit.text, p.offset, [...p.current].length),
  };
}

/**
 * Rapproche les lignes des tableurs du texte et regroupe les passages par
 * cantique : une proposition = une ligne de tableur × un cantique.
 */
export function buildSuggestions(
  rows: CorrectionRow[],
  units: TextUnit[],
): { stats: CorrectionStats; suggestions: Suggestion[] } {
  const matcher = new CorrectionMatcher(units);
  const stats: CorrectionStats = { applied: 0, pending: 0, conflict: 0, not_found: 0, declined: 0 };
  const suggestions: Suggestion[] = [];
  const keys = new Set<string>();

  for (const row of rows) {
    const match = matcher.match(row);
    stats[match.status]++;
    if (match.status === 'applied' || match.status === 'declined') continue;

    const base = `${row.file}|${row.sheet}|${row.row}`;
    if (match.status === 'not_found') {
      suggestions.push({ key: base, status: 'not_found', hymnId: null, passages: [], source: row });
      continue;
    }
    const byHymn = new Map<string, SuggestionPassage[]>();
    const seen = new Set<string>();
    for (const p of match.passages) {
      const passage = toPassage(p);
      const id = `${p.unit.hymnId}|${passage.unit}|${passage.sectionId}|${passage.offset}`;
      if (seen.has(id)) continue;
      seen.add(id);
      byHymn.set(p.unit.hymnId, [...(byHymn.get(p.unit.hymnId) ?? []), passage]);
    }
    for (const [hymnId, passages] of byHymn) {
      const key = `${base}|${hymnId}`;
      if (keys.has(key)) continue;
      keys.add(key);
      suggestions.push({ key, status: match.status, hymnId, passages, source: row });
    }
  }
  return { stats, suggestions };
}

/** Empreinte des fichiers sources, dans l'ordre donné. */
export function sourceDigest(files: { name: string; bytes: Uint8Array }[]): string {
  const hash = createHash('sha256');
  for (const f of files) {
    hash.update(f.name);
    hash.update(createHash('sha256').update(f.bytes).digest());
  }
  return hash.digest('hex');
}

/** Textes corrigeables de l'édition : titres, premiers vers, sections (cantiques non archivés). */
export async function readUnits(client: pg.Client, editionId: string): Promise<TextUnit[]> {
  const { rows } = await client.query<{
    hymn_id: string;
    number_label: string;
    title: string;
    opening_line: string | null;
    section_id: string | null;
    text: string | null;
  }>(
    `select h.id as hymn_id, h.number_label, h.title, h.opening_line,
            s.id as section_id, s.text
       from public.hymns h
       left join public.hymn_sections s on s.hymn_id = h.id
      where h.edition_id = $1 and h.status <> 'archived'
      order by h.number_numeric, h.number_label, s.display_order`,
    [editionId],
  );
  const units: TextUnit[] = [];
  const done = new Set<string>();
  for (const r of rows) {
    const hymn = { hymnId: r.hymn_id, numberLabel: r.number_label, hymnTitle: r.title };
    if (!done.has(r.hymn_id)) {
      done.add(r.hymn_id);
      units.push({ ...hymn, unit: 'title', sectionId: null, text: r.title });
      if (r.opening_line) {
        units.push({ ...hymn, unit: 'opening_line', sectionId: null, text: r.opening_line });
      }
    }
    if (r.section_id && r.text) {
      units.push({ ...hymn, unit: 'section', sectionId: r.section_id, text: r.text });
    }
  }
  return units;
}

/** Édition à corriger : celle indiquée, sinon la seule qui a des cantiques. */
export async function resolveEdition(client: pg.Client, editionId?: string): Promise<string> {
  const { rows } = await client.query<{ id: string; name: string; hymns: number }>(
    `select e.id, e.name, count(h.id)::int as hymns
       from public.editions e join public.hymns h on h.edition_id = e.id
      group by e.id, e.name order by e.name`,
  );
  if (editionId) {
    if (!rows.some((r) => r.id === editionId))
      throw new Error(`Édition ${editionId} introuvable ou vide`);
    return editionId;
  }
  if (rows.length === 1) return rows[0]!.id;
  throw new Error(
    rows.length === 0
      ? 'Aucune édition avec des cantiques'
      : `Plusieurs éditions : préciser --edition parmi ${rows.map((r) => `${r.id} (${r.name}, ${r.hymns})`).join(', ')}`,
  );
}

export interface CorrectionsSummary {
  editionId: string;
  stats: CorrectionStats;
  batchId: string | null;
  received: number;
  alreadyKnown: number;
  created: number;
  new: number;
  dryRun: boolean;
}

/**
 * Charge les propositions dans la file A-13, en tant qu'éditeur (RLS, journal).
 * Idempotent : une proposition déjà chargée n'est jamais recréée.
 */
export async function loadCorrections(
  client: pg.Client,
  input: { files: { name: string; bytes: Uint8Array }[]; rows: CorrectionRow[] },
  actorUserId: string,
  {
    editionId,
    dryRun = false,
    manageTransaction = true,
  }: { editionId?: string | undefined; dryRun?: boolean; manageTransaction?: boolean } = {},
): Promise<CorrectionsSummary> {
  if (manageTransaction) await client.query('begin');
  try {
    await actAsEditor(client, actorUserId);
    const edition = await resolveEdition(client, editionId);
    const { stats, suggestions } = buildSuggestions(input.rows, await readUnits(client, edition));
    const payload: CorrectionsPayload = {
      format: 'lad.corrections',
      version: 1,
      source: {
        filename: input.files.map((f) => f.name).join(', '),
        sha256: sourceDigest(input.files),
        parserVersion: CORRECTIONS_PARSER_VERSION,
      },
      editionId: edition,
      stats,
      suggestions,
    };
    const { rows } = await client.query<{
      summary: Omit<CorrectionsSummary, 'editionId' | 'stats'>;
    }>(`select public.import_corrections($1::jsonb, $2) as summary`, [
      JSON.stringify(payload),
      dryRun,
    ]);
    if (manageTransaction) await client.query(dryRun ? 'rollback' : 'commit');
    return { editionId: edition, stats, ...rows[0]!.summary };
  } catch (error) {
    if (manageTransaction) await client.query('rollback');
    throw error;
  }
}
