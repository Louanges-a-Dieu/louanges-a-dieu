import { PublishedHymn } from '@lad/shared-contracts';
import { z } from 'zod';

import type { KeyValueStore } from './store';

/** Recueil conservé sur l'ordinateur (dernière release publiée). */
export interface StoredCatalog {
  releaseId: number;
  contentHash: string;
  hymns: PublishedHymn[];
  checkedAt: string;
}

export type CatalogStatus =
  | { kind: 'fresh'; catalog: StoredCatalog }
  | { kind: 'cached'; catalog: StoredCatalog }
  | { kind: 'missing' };

export interface CatalogConfig {
  url: string;
  publishableKey: string;
}

const Manifest = z.object({ releaseId: z.number().int(), contentHash: z.string() });
const Snapshot = z.object({
  releaseId: z.number().int(),
  contentHash: z.string(),
  hymns: z.array(PublishedHymn),
});

const KEY = 'catalog';

async function rpc(config: CatalogConfig, name: string, body: object, fetchImpl: typeof fetch) {
  const response = await fetchImpl(`${config.url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: config.publishableKey,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`${name} : ${response.status}`);
  return (await response.json()) as unknown;
}

/**
 * Recueil local, mis à jour si une nouvelle release existe et qu'Internet est
 * disponible. Sans réseau, la copie locale est utilisée telle quelle (Q-08) ;
 * une réponse invalide ne remplace jamais une copie valide.
 */
export async function syncCatalog(
  config: CatalogConfig,
  store: KeyValueStore,
  fetchImpl: typeof fetch = fetch,
): Promise<CatalogStatus> {
  const local = await store.get<StoredCatalog>(KEY);
  try {
    const manifest = Manifest.parse(await rpc(config, 'get_catalog_manifest', {}, fetchImpl));
    if (local && local.contentHash === manifest.contentHash) {
      const checked = { ...local, checkedAt: new Date().toISOString() };
      await store.set(KEY, checked);
      return { kind: 'fresh', catalog: checked };
    }
    const snapshot = Snapshot.parse(
      await rpc(config, 'get_catalog_snapshot', { p_release_id: manifest.releaseId }, fetchImpl),
    );
    const catalog: StoredCatalog = { ...snapshot, checkedAt: new Date().toISOString() };
    await store.set(KEY, catalog);
    return { kind: 'fresh', catalog };
  } catch {
    return local ? { kind: 'cached', catalog: local } : { kind: 'missing' };
  }
}
