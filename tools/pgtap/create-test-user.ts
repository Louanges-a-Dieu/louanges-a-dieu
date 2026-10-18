/**
 * DÉVELOPPEMENT UNIQUEMENT — crée (ou recrée) sur la base de développement un
 * utilisateur de test à e-mail confirmé et mot de passe aléatoire, pour les
 * tests d'intégration avec une vraie session Supabase (synchronisation,
 * suppression de compte) sans dépendre de l'envoi d'e-mails.
 *
 * Le mot de passe est écrit dans apps/mobile/config/dev-test-user.json (non
 * versionné). L'application n'utilise jamais de mot de passe (Q-13).
 */
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

import { connectionConfig } from '../../packages/content_tools/src/db.ts';
import { createAuthUser } from './test-users.ts';

const repo = resolve(import.meta.dirname, '../..');
const email = 'integration-test@louanges-a-dieu.test';
let password = '';

const client = new pg.Client(connectionConfig(repo));
await client.connect();
try {
  const { rows } = await client.query<{ current_database: string }>('select current_database()');
  console.log(`Base : ${rows[0]?.current_database} (projet de développement)`);
  await client.query('begin');
  ({ password } = await createAuthUser(client, email));
  await client.query('commit');
} catch (error) {
  await client.query('rollback');
  throw error;
} finally {
  await client.end();
}

const out = resolve(repo, 'apps/mobile/config/dev-test-user.json');
writeFileSync(out, `${JSON.stringify({ email, password }, null, 2)}\n`, { mode: 0o600 });
console.log(`Utilisateur de test créé (${email}). Identifiants : ${out} (non versionné).`);
