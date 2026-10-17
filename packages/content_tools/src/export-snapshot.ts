import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { gzipSync } from 'node:zlib';

import { PublishedHymn } from '@lad/shared-contracts';

/**
 * Télécharge la dernière release publiée (RPC publique, clé publishable — le
 * même chemin que l'application), valide CHAQUE cantique avec le contrat Zod,
 * puis écrit l'instantané compressé embarqué dans l'app (ADR-005).
 */
export interface ExportResult {
  releaseId: number;
  hymnCount: number;
  bytes: number;
}

interface AppConfig {
  SUPABASE_URL: string;
  SUPABASE_PUBLISHABLE_KEY: string;
}

export async function exportSnapshot(configPath: string, outPath: string): Promise<ExportResult> {
  const config = JSON.parse(readFileSync(configPath, 'utf8')) as Partial<AppConfig>;
  if (!config.SUPABASE_URL?.startsWith('https://') || !config.SUPABASE_PUBLISHABLE_KEY) {
    throw new Error(`${configPath} : SUPABASE_URL (https) et SUPABASE_PUBLISHABLE_KEY requis`);
  }
  if (!config.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')) {
    throw new Error('Seule une clé publishable est acceptée pour exporter le catalogue public');
  }

  const response = await fetch(`${config.SUPABASE_URL}/rest/v1/rpc/get_catalog_snapshot`, {
    method: 'POST',
    headers: { apikey: config.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
    body: '{}',
  });
  if (!response.ok) {
    throw new Error(`get_catalog_snapshot : HTTP ${response.status} ${await response.text()}`);
  }
  const snapshot = (await response.json()) as {
    releaseId?: number;
    contentHash?: string;
    hymns?: unknown[];
  } | null;
  if (!snapshot || typeof snapshot.releaseId !== 'number' || !Array.isArray(snapshot.hymns)) {
    throw new Error('Aucune release publiée, ou réponse inattendue');
  }

  const errors: string[] = [];
  snapshot.hymns.forEach((hymn, i) => {
    const result = PublishedHymn.safeParse(hymn);
    if (!result.success) errors.push(`#${i} : ${result.error.issues[0]?.message ?? 'invalide'}`);
  });
  if (errors.length > 0) {
    throw new Error(
      `${errors.length} cantique(s) non conformes au contrat :\n${errors.slice(0, 10).join('\n')}`,
    );
  }

  const gz = gzipSync(JSON.stringify(snapshot), { level: 9 });
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, gz);
  return { releaseId: snapshot.releaseId, hymnCount: snapshot.hymns.length, bytes: gz.length };
}
