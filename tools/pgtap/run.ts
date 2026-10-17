/**
 * Exécuteur pgTAP sans Docker : lance chaque fichier supabase/tests/*.test.sql
 * sur une base distante et agrège les résultats TAP.
 *
 * Connexion : DATABASE_URL si défini, sinon l'URL du pooler écrite par
 * `supabase link` (supabase/.temp/pooler-url) + SUPABASE_DB_PASSWORD.
 * Les fichiers de test s'exécutent dans une transaction annulée (rollback).
 */
import { readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import pg from 'pg';

const repo = resolve(import.meta.dirname, '../..');
const testsDir = resolve(repo, 'supabase/tests');

function connectionString(): string {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const password = process.env.SUPABASE_DB_PASSWORD;
  if (!password) {
    throw new Error('Définir DATABASE_URL ou SUPABASE_DB_PASSWORD (voir docs/deployment).');
  }
  const url = new URL(readFileSync(resolve(repo, 'supabase/.temp/pooler-url'), 'utf8').trim());
  url.password = password;
  return url.toString();
}

/**
 * TLS : vérification complète avec le certificat CA Supabase versionné
 * (supabase/ca/prod-ca-2021.crt, téléchargé depuis le tableau de bord).
 * Sans ce fichier, la connexion est refusée, sauf dérogation explicite
 * PGTAP_INSECURE_TLS=1 (chiffré mais serveur non authentifié — base de
 * développement uniquement).
 */
function tlsOptions(): pg.ClientConfig['ssl'] {
  const caPath = process.env.SUPABASE_CA_CERT ?? resolve(repo, 'supabase/ca/prod-ca-2021.crt');
  try {
    return { ca: readFileSync(caPath, 'utf8'), rejectUnauthorized: true };
  } catch {
    if (process.env.PGTAP_INSECURE_TLS === '1') {
      console.warn('⚠ TLS sans vérification du serveur (PGTAP_INSECURE_TLS=1).');
      return { rejectUnauthorized: false };
    }
    throw new Error(
      `Certificat CA introuvable (${caPath}). Voir docs/deployment/database-tests.md.`,
    );
  }
}

/** Extrait les lignes TAP (ok / not ok / commentaires / plan) des résultats. */
function tapLines(results: pg.QueryResult | pg.QueryResult[]): string[] {
  const list = Array.isArray(results) ? results : [results];
  const lines: string[] = [];
  for (const result of list) {
    for (const row of result.rows ?? []) {
      for (const value of Object.values(row as Record<string, unknown>)) {
        if (typeof value === 'string' && /^(ok|not ok|#|\s+#|1\.\.)/.test(value)) {
          lines.push(...value.split('\n'));
        }
      }
    }
  }
  return lines;
}

async function main(): Promise<number> {
  const only = process.argv[2];
  const files = readdirSync(testsDir)
    .filter((f) => f.endsWith('.test.sql') && (!only || f.includes(only)))
    .sort();
  if (files.length === 0) {
    console.error('Aucun fichier de test trouvé.');
    return 1;
  }

  const client = new pg.Client({ connectionString: connectionString(), ssl: tlsOptions() });
  await client.connect();

  let passed = 0;
  let failed = 0;
  try {
    for (const file of files) {
      console.log(`\n# ${file}`);
      const sql = readFileSync(resolve(testsDir, file), 'utf8');
      try {
        const lines = tapLines(await client.query(sql));
        for (const line of lines) {
          if (line.startsWith('not ok')) failed++;
          else if (line.startsWith('ok')) passed++;
          console.log(line);
        }
        if (!lines.some((l) => l.startsWith('ok') || l.startsWith('not ok'))) {
          failed++;
          console.log('not ok - aucun résultat TAP produit');
        }
      } catch (error) {
        failed++;
        console.log(`not ok - erreur SQL : ${(error as Error).message}`);
        await client.query('rollback').catch(() => undefined);
      }
    }
  } finally {
    await client.end();
  }

  console.log(`\n${passed} réussi(s), ${failed} échec(s)`);
  return failed === 0 ? 0 : 1;
}

process.exitCode = await main();
