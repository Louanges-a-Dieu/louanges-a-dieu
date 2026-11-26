import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

/**
 * Connexion directe à la base (outillage de développement uniquement).
 * DATABASE_URL, ou URL du pooler écrite par `supabase link` + SUPABASE_DB_PASSWORD.
 * TLS vérifié avec le certificat CA Supabase versionné (sauf base locale).
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
  // Base locale (`supabase db start`, Docker) : pas de TLS.
  if (['localhost', '127.0.0.1', '[::1]'].includes(new URL(url).hostname)) {
    return { connectionString: url };
  }
  const ca = readFileSync(
    process.env.SUPABASE_CA_CERT ?? resolve(repoRoot, 'supabase/ca/prod-ca-2021.crt'),
    'utf8',
  );
  return { connectionString: url, ssl: { ca, rejectUnauthorized: true } };
}

/**
 * Fin de la transaction en cours en tant qu'éditeur (rôle authenticated + JWT
 * avec second facteur) : RLS, triggers et journal s'appliquent normalement.
 * Le client doit pouvoir faire SET ROLE authenticated (connexion postgres).
 */
export async function actAsEditor(client: pg.Client, actorUserId: string): Promise<void> {
  await client.query('set local role authenticated');
  await client.query(`select set_config('request.jwt.claims', $1, true)`, [
    JSON.stringify({ sub: actorUserId, role: 'authenticated', aal: 'aal2' }),
  ]);
  const { rows } = await client.query<{ ok: boolean }>(`select private.has_role('editor') as ok`);
  if (!rows[0]?.ok) throw new Error('Le compte indiqué n’a pas le rôle éditeur');
}
