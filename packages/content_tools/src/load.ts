import type { CatalogDraft } from '@lad/shared-contracts';
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
 * - Simulation (`dryRun`) : diff de réimport sans aucune écriture.
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

/**
 * Charge le catalogue. Le client doit être connecté avec un rôle capable de
 * SET ROLE authenticated (connexion postgres de développement). La transaction
 * est gérée ici sauf si `manageTransaction` est faux (tests).
 *
 * La logique est celle de la fonction SQL `public.import_catalog_draft`
 * (migration 0015), partagée avec le back-office : session de l'éditeur avec
 * second facteur (aal2), RLS et journal appliqués.
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
      JSON.stringify({ sub: actorUserId, role: 'authenticated', aal: 'aal2' }),
    ]);
    const { rows: roleRows } = await client.query<{ ok: boolean }>(
      `select private.has_role('editor') as ok`,
    );
    if (!roleRows[0]?.ok) throw new Error('Le compte indiqué n’a pas le rôle éditeur');

    const { rows } = await client.query<{ summary: LoadSummary & { dryRun: boolean } }>(
      `select public.import_catalog_draft($1::jsonb, $2) as summary`,
      [JSON.stringify(draft), dryRun],
    );
    const { dryRun: _ignored, ...summary } = rows[0]!.summary;
    if (manageTransaction) await client.query(dryRun ? 'rollback' : 'commit');
    return summary;
  } catch (error) {
    if (manageTransaction) await client.query('rollback');
    throw error;
  }
}
