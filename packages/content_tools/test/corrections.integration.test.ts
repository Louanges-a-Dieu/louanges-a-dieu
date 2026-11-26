import { randomUUID } from 'node:crypto';
import { resolve } from 'node:path';

import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import type { CorrectionRow } from '../src/corrections.ts';
import { actAsEditor, connectionConfig } from '../src/db.ts';
import { loadCorrections } from '../src/suggestions.ts';

/**
 * Du tableur à la file éditoriale, puis application, contre une vraie base
 * (développement ou locale). Tout se déroule dans une transaction ANNULÉE.
 */
const hasDb = Boolean(process.env.DATABASE_URL ?? process.env.SUPABASE_DB_PASSWORD);
const repoRoot = resolve(import.meta.dirname, '../../..');

function row(
  n: number,
  original: string,
  proposed: string,
  extra: Partial<CorrectionRow> = {},
): CorrectionRow {
  return {
    file: 'relecture.xlsx',
    sheet: 'Corrections',
    row: n,
    number: null,
    title: null,
    original,
    proposed,
    problem: null,
    confidence: null,
    validation: null,
    comment: null,
    ...extra,
  };
}

describe.skipIf(!hasDb)('propositions de correction en base (intégration)', () => {
  const client = new pg.Client(hasDb ? connectionConfig(repoRoot) : {});
  const editorId = randomUUID();
  const editionId = randomUUID();
  const hymnId = randomUUID();
  const sectionId = randomUUID();
  const files = [{ name: 'relecture.xlsx', bytes: new TextEncoder().encode('tableur') }];
  const rows = [
    row(2, 'Sépares-toi des œuvres', 'Sépare-toi des œuvres'),
    row(3, 'O jour heureux', 'Ô jour heureux', { title: 'O jour heureux' }),
    row(4, 'les pêcheurs se relèvent', 'les pécheurs se relèvent'),
    row(5, 'jour de bonheur', 'jour de joie', { validation: 'Non' }),
  ];

  beforeAll(async () => {
    await client.connect();
    await client.query('begin');
    await client.query(`insert into auth.users (id, email) values ($1, $2)`, [
      editorId,
      `${editorId}@test.invalid`,
    ]);
    await client.query(`insert into public.user_roles (user_id, role) values ($1, 'editor')`, [
      editorId,
    ]);
    await client.query(`insert into public.editions (id, name) values ($1, $2)`, [
      editionId,
      `Test ${editionId}`,
    ]);
    await client.query(
      `insert into public.hymns (id, edition_id, number_label, number_numeric, title, opening_line)
       values ($1, $2, '1', 1, 'O jour heureux', 'O jour heureux, jour de bonheur,')`,
      [hymnId, editionId],
    );
    await client.query(
      `insert into public.hymn_sections (id, hymn_id, section_type, section_number, text, display_order)
       values ($1, $2, 'verse', 1, E'O jour heureux, jour de bonheur,\\nSépares-toi des œuvres des ténèbres', 0)`,
      [sectionId, hymnId],
    );
    await client.query('savepoint debut');
  });

  afterAll(async () => {
    await client.query('rollback');
    await client.end();
  });

  const reset = () => client.query('rollback to savepoint debut');

  it('simulation : décompte sans rien écrire', async () => {
    const s = await loadCorrections(client, { files, rows }, editorId, {
      editionId,
      dryRun: true,
      manageTransaction: false,
    });
    expect(s.stats).toEqual({ applied: 0, pending: 2, conflict: 0, not_found: 1, declined: 1 });
    expect(s).toMatchObject({ received: 3, new: 3, created: 0, batchId: null });
    await reset();
  });

  it('chargement, application, puis rechargement sans doublon', async () => {
    const first = await loadCorrections(client, { files, rows }, editorId, {
      editionId,
      manageTransaction: false,
    });
    expect(first.created).toBe(3);

    const { rows: issues } = await client.query<{ id: string; key: string; passages: number }>(
      `select id, details ->> 'key' as key, jsonb_array_length(details -> 'passages') as passages
         from public.import_issues where code = 'A-13' and batch_id = $1 order by key`,
      [first.batchId],
    );
    expect(issues.map((i) => [i.key, i.passages])).toEqual([
      [`relecture.xlsx|Corrections|2|${hymnId}`, 1],
      [`relecture.xlsx|Corrections|3|${hymnId}`, 3],
      ['relecture.xlsx|Corrections|4', 0],
    ]);

    // Le titre, le premier vers et le texte du cantique en une seule décision.
    await client.query('reset role');
    await actAsEditor(client, editorId);
    await client.query(`select public.apply_correction($1)`, [issues[1]!.id]);
    const { rows: hymn } = await client.query<{
      title: string;
      opening_line: string;
      text: string;
    }>(
      `select h.title, h.opening_line, s.text from public.hymns h
         join public.hymn_sections s on s.hymn_id = h.id where h.id = $1`,
      [hymnId],
    );
    expect(hymn[0]).toEqual({
      title: 'Ô jour heureux',
      opening_line: 'Ô jour heureux, jour de bonheur,',
      text: 'Ô jour heureux, jour de bonheur,\nSépares-toi des œuvres des ténèbres',
    });

    await client.query('reset role');
    const again = await loadCorrections(client, { files, rows }, editorId, {
      editionId,
      manageTransaction: false,
    });
    expect(again.stats).toMatchObject({ applied: 1, pending: 1, not_found: 1 });
    expect(again).toMatchObject({ created: 0, alreadyKnown: 2, batchId: null });
    await client.query('reset role');
  });
});
