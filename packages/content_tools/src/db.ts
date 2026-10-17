import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

/**
 * Connexion directe à la base (outillage de développement uniquement).
 * DATABASE_URL, ou URL du pooler écrite par `supabase link` + SUPABASE_DB_PASSWORD.
 * TLS vérifié avec le certificat CA Supabase versionné.
 */
export function connectionConfig(repoRoot: string): pg.ClientConfig {
  const url =
    process.env.DATABASE_URL ??
    (() => {
      const password = process.env.SUPABASE_DB_PASSWORD;
      if (!password) throw new Error('Définir DATABASE_URL ou SUPABASE_DB_PASSWORD');
      const u = new URL(
        readFileSync(resolve(repoRoot, 'supabase/.temp/pooler-url'), 'utf8').trim(),
      );
      u.password = password;
      return u.toString();
    })();
  const ca = readFileSync(
    process.env.SUPABASE_CA_CERT ?? resolve(repoRoot, 'supabase/ca/prod-ca-2021.crt'),
    'utf8',
  );
  return { connectionString: url, ssl: { ca, rejectUnauthorized: true } };
}
