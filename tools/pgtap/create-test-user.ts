/**
 * DÉVELOPPEMENT UNIQUEMENT — crée (ou recrée) sur la base de développement un
 * utilisateur de test à e-mail confirmé et mot de passe aléatoire, pour les
 * tests d'intégration avec une vraie session Supabase (synchronisation,
 * suppression de compte) sans dépendre de l'envoi d'e-mails.
 *
 * Le mot de passe est écrit dans apps/mobile/config/dev-test-user.json (non
 * versionné). L'application n'utilise jamais de mot de passe (Q-13).
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

import { connectionConfig } from '../../packages/content_tools/src/db.ts';

const repo = resolve(import.meta.dirname, '../..');
const email = 'integration-test@louanges-a-dieu.test';
const password = randomBytes(24).toString('base64url');
const id = randomUUID();

const client = new pg.Client(connectionConfig(repo));
await client.connect();
try {
  const { rows } = await client.query<{ current_database: string }>('select current_database()');
  console.log(`Base : ${rows[0]?.current_database} (projet de développement)`);
  await client.query('begin');
  await client.query('delete from auth.users where email = $1', [email]);
  await client.query(
    `insert into auth.users (
       instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
       raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
       confirmation_token, recovery_token, email_change_token_new, email_change)
     values ('00000000-0000-0000-0000-000000000000', $1, 'authenticated', 'authenticated', $2,
             extensions.crypt($3, extensions.gen_salt('bf')), now(),
             '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')`,
    [id, email, password],
  );
  await client.query(
    `insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at)
     values (gen_random_uuid(), $1::uuid, $3::text, jsonb_build_object('sub', $3::text, 'email', $2::text),
             'email', now(), now())`,
    [id, email, id],
  );
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
