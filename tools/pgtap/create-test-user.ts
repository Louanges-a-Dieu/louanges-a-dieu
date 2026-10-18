/**
 * DÉVELOPPEMENT UNIQUEMENT — crée (ou recrée) sur la base de développement deux
 * comptes de test à e-mail confirmé et mot de passe aléatoire, pour les tests
 * d'intégration avec une vraie session Supabase, sans envoi d'e-mail :
 *
 * - « integration-test » : compte DURABLE, sans rôle, partagé par les tests
 *   web et admin (apps/mobile/config/dev-test-user.json) ;
 * - « disposable-test » : compte JETABLE, supprimé par le test Flutter de
 *   suppression de compte (apps/mobile/config/dev-test-user-disposable.json).
 *
 * Fichiers non versionnés. L'application n'utilise jamais de mot de passe (Q-13).
 */
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

import { connectionConfig } from '../../packages/content_tools/src/db.ts';
import { createAuthUser } from './test-users.ts';

const repo = resolve(import.meta.dirname, '../..');
const accounts = [
  { email: 'integration-test@louanges-a-dieu.test', file: 'dev-test-user.json' },
  { email: 'disposable-test@louanges-a-dieu.test', file: 'dev-test-user-disposable.json' },
];

const client = new pg.Client(connectionConfig(repo));
await client.connect();
const created: Array<{ email: string; password: string; file: string }> = [];
try {
  const { rows } = await client.query<{ current_database: string }>('select current_database()');
  console.log(`Base : ${rows[0]?.current_database} (projet de développement)`);
  await client.query('begin');
  for (const account of accounts) {
    const { password } = await createAuthUser(client, account.email);
    created.push({ ...account, password });
  }
  await client.query('commit');
} catch (error) {
  await client.query('rollback');
  throw error;
} finally {
  await client.end();
}

for (const { email, password, file } of created) {
  const out = resolve(repo, 'apps/mobile/config', file);
  writeFileSync(out, `${JSON.stringify({ email, password }, null, 2)}\n`, { mode: 0o600 });
  console.log(`Compte de test créé (${email}) : ${out} (non versionné).`);
}
