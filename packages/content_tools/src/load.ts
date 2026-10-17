import { randomUUID } from 'node:crypto';

import type { CatalogDraft, DraftHymn, DraftIssue } from '@lad/shared-contracts';
import type pg from 'pg';

/**
 * Chargement du catalogue brouillon dans la copie de travail éditoriale.
 *
 * - Agit EN TANT QU'ÉDITEUR (rôle authenticated + JWT de l'éditeur) : la RLS,
 *   les triggers (brouillon forcé) et le journal s'appliquent normalement.
 * - Un cantique déjà présent n'est JAMAIS écrasé : si son texte source a changé,
 *   une anomalie A-20 est ouverte pour décision humaine.
 * - Un cantique en base absent de la source : anomalie A-21.
 * - Idempotent : recharger le même fichier ne crée ni lot ni ligne.
 */

export interface LoadSummary {
  editionId: string;
  editionCreated: boolean;
  batchId: string | null;
  inserted: string[];
  unchanged: string[];
  changed: string[];
  missingFromSource: string[];
  issuesCreated: number;
}

interface ExistingHymn {
  id: string;
  number_label: string;
  fingerprint: string;
}

/** Empreinte du contenu importable d'un cantique (titre, premier vers, sections, références). */
export function fingerprint(h: {
  title: string;
  openingLine: string | null;
  sections: { type: string; text: string }[];
  references: string[];
}): string {
  return JSON.stringify([
    h.title,
    h.openingLine,
    h.sections.map((s) => [s.type, s.text]),
    [...h.references].sort(),
  ]);
}

const draftFingerprint = (h: DraftHymn): string =>
  fingerprint({
    title: h.title,
    openingLine: h.openingLine,
    sections: h.sections,
    references: h.bibleReferences.map((r) => r.displayText),
  });

/**
 * Charge le catalogue. Le client doit être connecté avec un rôle capable de
 * SET ROLE authenticated (connexion postgres de développement). La transaction
 * est gérée ici sauf si `manageTransaction` est faux (tests).
 */
export async function loadDraft(
  client: pg.Client,
  draft: CatalogDraft,
  actorUserId: string,
  { manageTransaction = true, dryRun = false } = {},
): Promise<LoadSummary> {
  if (manageTransaction) await client.query('begin');
  try {
    await client.query('set local role authenticated');
    await client.query(`select set_config('request.jwt.claims', $1, true)`, [
      JSON.stringify({ sub: actorUserId, role: 'authenticated' }),
    ]);
    const { rows: roleRows } = await client.query<{ ok: boolean }>(
      `select private.has_role('editor') as ok`,
    );
    if (!roleRows[0]?.ok) throw new Error('Le compte indiqué n’a pas le rôle éditeur');

    // Édition
    let editionCreated = false;
    let { rows: editions } = await client.query<{ id: string }>(
      `select id from public.editions where name = $1 and edition_number is not distinct from $2`,
      [draft.edition.name, draft.edition.editionNumber],
    );
    if (editions.length === 0) {
      ({ rows: editions } = await client.query<{ id: string }>(
        `insert into public.editions (name, edition_number, source_filename)
         values ($1, $2, $3) returning id`,
        [draft.edition.name, draft.edition.editionNumber, draft.source.filename],
      ));
      editionCreated = true;
    }
    const editionId = editions[0]!.id;

    // Contenu existant
    const { rows: existing } = await client.query<
      ExistingHymn & {
        title: string;
        opening_line: string | null;
        sections: { type: string; text: string }[];
        refs: string[];
      }
    >(
      `select h.id, h.number_label, h.title, h.opening_line,
              coalesce((select jsonb_agg(jsonb_build_object('type', s.section_type, 'text', s.text)
                                         order by s.display_order)
                          from public.hymn_sections s where s.hymn_id = h.id), '[]') as sections,
              coalesce((select jsonb_agg(coalesce(b.display_text, b.book || ' ' || b.chapter_start))
                          from public.bible_references b where b.hymn_id = h.id), '[]') as refs
         from public.hymns h
        where h.edition_id = $1`,
      [editionId],
    );
    const byLabel = new Map(
      existing.map((e) => [
        e.number_label,
        {
          id: e.id,
          fingerprint: fingerprint({
            title: e.title,
            openingLine: e.opening_line,
            sections: e.sections,
            references: e.refs,
          }),
        },
      ]),
    );

    const inserted: DraftHymn[] = [];
    const unchanged: string[] = [];
    const changed: DraftHymn[] = [];
    for (const h of draft.hymns) {
      const current = byLabel.get(h.numberLabel);
      if (!current) inserted.push(h);
      else if (current.fingerprint === draftFingerprint(h)) unchanged.push(h.numberLabel);
      else changed.push(h);
    }
    const sourceLabels = new Set(draft.hymns.map((h) => h.numberLabel));
    const missingFromSource = existing
      .map((e) => e.number_label)
      .filter((label) => !sourceLabels.has(label));

    const summary: LoadSummary = {
      editionId,
      editionCreated,
      batchId: null,
      inserted: inserted.map((h) => h.numberLabel),
      unchanged,
      changed: changed.map((h) => h.numberLabel),
      missingFromSource,
      issuesCreated: 0,
    };

    if (inserted.length === 0 && changed.length === 0 && missingFromSource.length === 0) {
      if (manageTransaction) await client.query(dryRun ? 'rollback' : 'commit');
      return summary; // rien de nouveau : aucun lot créé
    }

    // Lot d'import
    const { rows: batch } = await client.query<{ id: string }>(
      `insert into public.import_batches (edition_id, source_filename, source_sha256, parser_version, stats)
       values ($1, $2, $3, $4, $5) returning id`,
      [
        editionId,
        draft.source.filename,
        draft.source.sha256,
        draft.source.parserVersion,
        JSON.stringify({
          inserted: inserted.length,
          unchanged: unchanged.length,
          changed: changed.length,
          missingFromSource: missingFromSource.length,
        }),
      ],
    );
    const batchId = batch[0]!.id;
    summary.batchId = batchId;

    // Nouveaux cantiques (insertion en masse)
    const ids = new Map<string, string>([...byLabel].map(([label, v]) => [label, v.id]));
    for (const h of inserted) ids.set(h.numberLabel, randomUUID());

    if (inserted.length > 0) {
      await client.query(
        `insert into public.hymns (id, edition_id, number_label, number_numeric, number_suffix, title,
                                   opening_line, source_paragraph_start, source_paragraph_end, import_batch_id)
         select t.id, $1, t.label, t.num, t.suffix, t.title, t.opening, t.p0, t.p1, $2
           from unnest($3::uuid[], $4::text[], $5::int[], $6::text[], $7::text[], $8::text[], $9::int[], $10::int[])
             as t (id, label, num, suffix, title, opening, p0, p1)`,
        [
          editionId,
          batchId,
          inserted.map((h) => ids.get(h.numberLabel)),
          inserted.map((h) => h.numberLabel),
          inserted.map((h) => h.numberNumeric),
          inserted.map((h) => h.numberSuffix),
          inserted.map((h) => h.title),
          inserted.map((h) => h.openingLine),
          inserted.map((h) => h.sourceParagraphStart),
          inserted.map((h) => h.sourceParagraphEnd),
        ],
      );

      const sections = inserted.flatMap((h) =>
        h.sections.map((s) => ({ hymnId: ids.get(h.numberLabel)!, ...s })),
      );
      await client.query(
        `insert into public.hymn_sections (hymn_id, section_type, text, display_order)
         select t.hymn_id, t.type::public.section_type, t.text, t.ord
           from unnest($1::uuid[], $2::text[], $3::text[], $4::int[]) as t (hymn_id, type, text, ord)`,
        [
          sections.map((s) => s.hymnId),
          sections.map((s) => s.type),
          sections.map((s) => s.text),
          sections.map((s) => s.order),
        ],
      );

      const refs = inserted.flatMap((h) =>
        h.bibleReferences.map((r) => ({ hymnId: ids.get(h.numberLabel)!, ...r })),
      );
      if (refs.length > 0) {
        await client.query(
          `insert into public.bible_references (hymn_id, book, chapter_start, verse_start, chapter_end,
                                                verse_end, display_text)
           select * from unnest($1::uuid[], $2::text[], $3::int[], $4::int[], $5::int[], $6::int[], $7::text[])`,
          [
            refs.map((r) => r.hymnId),
            refs.map((r) => r.book),
            refs.map((r) => r.chapterStart),
            refs.map((r) => r.verseStart),
            refs.map((r) => r.chapterEnd),
            refs.map((r) => r.verseEnd),
            refs.map((r) => r.displayText),
          ],
        );
      }

      const relations = inserted.flatMap((h) =>
        h.relations
          .filter((r) => ids.has(r.relatedNumberLabel))
          .map((r) => [ids.get(h.numberLabel)!, ids.get(r.relatedNumberLabel)!] as const),
      );
      if (relations.length > 0) {
        await client.query(
          `insert into public.hymn_relations (hymn_id, related_hymn_id, relation)
           select t.a, t.b, 'bis_of' from unnest($1::uuid[], $2::uuid[]) as t (a, b)
           on conflict do nothing`,
          [relations.map((r) => r[0]), relations.map((r) => r[1])],
        );
      }
    }

    // Anomalies : celles du document et des cantiques insérés, puis A-20 / A-21.
    const insertedLabels = new Set(summary.inserted);
    const toCreate: (DraftIssue & { hymnId: string | null })[] = draft.issues
      .filter((i) => i.numberLabel === null || insertedLabels.has(i.numberLabel))
      .map((i) => ({ ...i, hymnId: i.numberLabel ? (ids.get(i.numberLabel) ?? null) : null }));
    for (const h of changed) {
      toCreate.push({
        code: 'A-20',
        severity: 'warning',
        numberLabel: h.numberLabel,
        message: 'Le texte source diffère de la version en base : non écrasé, à arbitrer',
        details: { sourceTitle: h.title, sourceSections: h.sections },
        hymnId: ids.get(h.numberLabel)!,
      });
    }
    for (const label of missingFromSource) {
      toCreate.push({
        code: 'A-21',
        severity: 'warning',
        numberLabel: label,
        message: 'Cantique présent en base mais absent de la source importée',
        details: {},
        hymnId: ids.get(label)!,
      });
    }
    if (toCreate.length > 0) {
      await client.query(
        `insert into public.import_issues (batch_id, hymn_id, code, severity, message, details)
         select $1, t.hymn_id, t.code, t.severity::public.issue_severity, t.message, t.details
           from unnest($2::uuid[], $3::text[], $4::text[], $5::text[], $6::jsonb[])
             as t (hymn_id, code, severity, message, details)`,
        [
          batchId,
          toCreate.map((i) => i.hymnId),
          toCreate.map((i) => i.code),
          toCreate.map((i) => i.severity),
          toCreate.map((i) => i.message),
          toCreate.map((i) => JSON.stringify({ ...i.details, numberLabel: i.numberLabel })),
        ],
      );
    }
    summary.issuesCreated = toCreate.length;

    if (manageTransaction) await client.query(dryRun ? 'rollback' : 'commit');
    return summary;
  } catch (error) {
    if (manageTransaction) await client.query('rollback');
    throw error;
  }
}
