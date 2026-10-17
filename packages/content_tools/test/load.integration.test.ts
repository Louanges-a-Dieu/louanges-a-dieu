import { randomUUID } from 'node:crypto';
import { resolve } from 'node:path';

import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { connectionConfig } from '../src/db.ts';
import { loadDraft } from '../src/load.ts';
import { importDocx } from '../src/pipeline.ts';
import { docx, number, sampleBook, separator, stanza, title } from './docx-builder.ts';

/**
 * Test d'intégration contre la base de développement. Tout se déroule dans une
 * transaction ANNULÉE à la fin. Sauté (et signalé comme tel) sans accès base.
 */
const hasDb = Boolean(process.env.DATABASE_URL ?? process.env.SUPABASE_DB_PASSWORD);
const repoRoot = resolve(import.meta.dirname, '../../..');

describe.skipIf(!hasDb)('chargement en base (intégration)', () => {
  const client = new pg.Client(hasDb ? connectionConfig(repoRoot) : {});
  const editorId = randomUUID();
  const userId = randomUUID();
  const editionName = `Édition de test ${randomUUID()}`;
  const draft = importDocx(docx(sampleBook()), {
    filename: 'test.docx',
    editionName,
    editionNumber: 1,
  }).draft;

  const asEditor = async <T extends pg.QueryResultRow>(sql: string, params: unknown[] = []) =>
    (await client.query<T>(sql, params)).rows;

  beforeAll(async () => {
    await client.connect();
    await client.query('begin');
    await client.query(`insert into auth.users (id, email) values ($1, $2), ($3, $4)`, [
      editorId,
      `${editorId}@test.invalid`,
      userId,
      `${userId}@test.invalid`,
    ]);
    await client.query(`insert into public.user_roles (user_id, role) values ($1, 'editor')`, [
      editorId,
    ]);
  });

  afterAll(async () => {
    await client.query('rollback');
    await client.end();
  });

  it('premier chargement : tous les cantiques en brouillon, avec sections, références, relations et anomalies', async () => {
    const summary = await loadDraft(client, draft, editorId, { manageTransaction: false });
    expect(summary.editionCreated).toBe(true);
    expect(summary.inserted).toEqual(['1', '2', '2bis', '4']);
    expect(summary.batchId).not.toBeNull();

    const hymns = await asEditor<{ number_label: string; status: string; sections: number }>(
      `select h.number_label, h.status::text,
              (select count(*)::int from public.hymn_sections s where s.hymn_id = h.id) as sections
         from public.hymns h where h.edition_id = $1 order by h.number_numeric, h.number_label`,
      [summary.editionId],
    );
    expect(hymns).toEqual([
      { number_label: '1', status: 'draft', sections: 3 },
      { number_label: '2', status: 'draft', sections: 1 },
      { number_label: '2bis', status: 'draft', sections: 2 },
      { number_label: '4', status: 'draft', sections: 1 },
    ]);

    const [rel] = await asEditor<{ n: number }>(
      `select count(*)::int as n from public.hymn_relations r
         join public.hymns h on h.id = r.hymn_id
        where h.edition_id = $1 and r.relation = 'bis_of'`,
      [summary.editionId],
    );
    expect(rel!.n).toBe(1);

    const [ref] = await asEditor<{ display_text: string }>(
      `select b.display_text from public.bible_references b
         join public.hymns h on h.id = b.hymn_id where h.edition_id = $1`,
      [summary.editionId],
    );
    expect(ref!.display_text).toBe('Psaumes 150');

    const [issues] = await asEditor<{ n: number }>(
      `select count(*)::int as n from public.import_issues where batch_id = $1`,
      [summary.batchId],
    );
    expect(issues!.n).toBe(draft.issues.length);

    const [audit] = await asEditor<{ n: number }>(
      `select count(*)::int as n from public.audit_log
        where table_name = 'hymns' and action = 'insert' and actor_id = $1`,
      [editorId],
    );
    expect(audit!.n).toBe(4);
  });

  it('rechargement du même fichier : aucun changement, aucun lot', async () => {
    const summary = await loadDraft(client, draft, editorId, { manageTransaction: false });
    expect(summary).toMatchObject({ inserted: [], changed: [], batchId: null });
    expect(summary.unchanged).toHaveLength(4);
  });

  it('source modifiée : jamais d’écrasement, anomalie A-20 ; nouveau cantique ajouté', async () => {
    const modified = importDocx(
      docx([
        ...sampleBook().slice(0, -6),
        number('5'),
        title('Cinq'),
        ...stanza(['Cinquième chant.']),
        separator(),
      ]),
      { filename: 'test-v2.docx', editionName, editionNumber: 1 },
    ).draft;
    modified.hymns.find((h) => h.numberLabel === '1')!.title = 'Titre modifié';

    const summary = await loadDraft(client, modified, editorId, { manageTransaction: false });
    expect(summary.inserted).toEqual(['5']);
    expect(summary.changed).toEqual(['1']);

    const [one] = await asEditor<{ title: string }>(
      `select title from public.hymns where edition_id = $1 and number_label = '1'`,
      [summary.editionId],
    );
    expect(one!.title).toBe('Premier vers du chant un');

    const codes = await asEditor<{ code: string }>(
      `select code from public.import_issues where batch_id = $1 and code in ('A-20', 'A-21') order by code`,
      [summary.batchId],
    );
    expect(codes.map((c) => c.code)).toEqual(['A-20']);
  });

  it('refuse un compte sans rôle éditeur', async () => {
    await client.query('reset role');
    await expect(loadDraft(client, draft, userId, { manageTransaction: false })).rejects.toThrow(
      'rôle éditeur',
    );
  });
});
