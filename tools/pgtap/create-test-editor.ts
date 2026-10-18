/**
 * DÉVELOPPEMENT UNIQUEMENT — crée sur la base de développement un compte
 * super administrateur de test AVEC second facteur TOTP vérifié, pour les
 * tests de bout en bout du back-office (Phase 9). L'enrôlement passe par l'API
 * officielle d'Auth, comme pour un vrai éditeur.
 *
 * Identifiants et secret TOTP écrits dans apps/admin/e2e/.test-editor.json
 * (non versionné).
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import pg from 'pg';

import { connectionConfig } from '../../packages/content_tools/src/db.ts';
import { createAuthUser, totp } from './test-users.ts';

const repo = resolve(import.meta.dirname, '../..');
const email = 'editor-test@louanges-a-dieu.test';

const env = Object.fromEntries(
  readFileSync(resolve(repo, 'apps/admin/.env.local'), 'utf8')
    .split('\n')
    .filter((l) => l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]),
);
const url = env.SUPABASE_URL!;
const apikey = env.SUPABASE_PUBLISHABLE_KEY!;

const client = new pg.Client(connectionConfig(repo));
await client.connect();
let user: { id: string; email: string; password: string };
try {
  await client.query('begin');
  user = await createAuthUser(client, email);
  await client.query(`insert into public.user_roles (user_id, role) values ($1, 'super_admin')`, [
    user.id,
  ]);
  await client.query('commit');
} catch (error) {
  await client.query('rollback');
  throw error;
} finally {
  await client.end();
}

async function auth(path: string, body: object, token?: string) {
  const response = await fetch(`${url}/auth/v1/${path}`, {
    method: 'POST',
    headers: {
      apikey,
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const json = (await response.json()) as Record<string, unknown>;
  if (!response.ok) throw new Error(`${path} : ${JSON.stringify(json)}`);
  return json;
}

const session = await auth('token?grant_type=password', { email, password: user.password });
const token = session.access_token as string;
const factor = await auth('factors', { factor_type: 'totp', friendly_name: 'Test E2E' }, token);
const secret = (factor.totp as { secret: string }).secret;
const challenge = await auth(`factors/${factor.id}/challenge`, {}, token);
await auth(
  `factors/${factor.id}/verify`,
  { challenge_id: challenge.id, code: totp(secret) },
  token,
);

const out = resolve(repo, 'apps/admin/e2e/.test-editor.json');
writeFileSync(
  out,
  `${JSON.stringify({ email, password: user.password, totpSecret: secret, factorId: factor.id }, null, 2)}\n`,
  { mode: 0o600 },
);
console.log(
  `Super administrateur de test avec second facteur créé (${email}) : ${out} (non versionné).`,
);
