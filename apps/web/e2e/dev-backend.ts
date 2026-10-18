import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/** Accès à la base de DÉVELOPPEMENT pour les tests de bout en bout. */
export const envFile = resolve(import.meta.dirname, '../.env.local');
export const userFile = resolve(import.meta.dirname, '../../mobile/config/dev-test-user.json');

export function readEnv() {
  const env = Object.fromEntries(
    readFileSync(envFile, 'utf8')
      .split('\n')
      .filter((line) => line.includes('='))
      .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1).trim()]),
  );
  return { url: env.SUPABASE_URL ?? '', publishableKey: env.SUPABASE_PUBLISHABLE_KEY ?? '' };
}

export const hasTestUser = () => existsSync(userFile);

/**
 * Crée, avec l'utilisateur de test, un programme publié et son lien ;
 * `cleanup` le supprime.
 */
export async function createSharedProgram(title: string, labels: string[]) {
  const config = readEnv();
  const user = JSON.parse(readFileSync(userFile, 'utf8')) as { email: string; password: string };
  const session = await fetch(`${config.url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
    body: JSON.stringify(user),
  });
  if (!session.ok) throw new Error('Connexion de l’utilisateur de test impossible');
  const { access_token } = (await session.json()) as { access_token: string };
  const rpc = async (name: string, params: object) => {
    const r = await fetch(`${config.url}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        apikey: config.publishableKey,
        Authorization: `Bearer ${access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(params),
    });
    const text = await r.text();
    if (!r.ok) throw new Error(`${name} : ${text}`);
    return text ? (JSON.parse(text) as unknown) : null;
  };
  const hymnId = async (label: string) => {
    const r = await fetch(
      `${config.url}/rest/v1/published_hymns?select=hymn_id&payload->>numberLabel=eq.${label}&order=release_id.desc&limit=1`,
      { headers: { apikey: config.publishableKey } },
    );
    return ((await r.json()) as { hymn_id: string }[])[0]!.hymn_id;
  };
  const id = randomUUID();
  const items = [{ id: randomUUID(), label: 'Accueil', notes: null, order: 0 }];
  for (const [i, label] of labels.entries()) {
    items.push({
      id: randomUUID(),
      hymnId: await hymnId(label),
      notes: null,
      order: i + 1,
    } as never);
  }
  const push = (extra: object = {}) =>
    rpc('sync_push_worship_service', {
      p_service: { id, title, serviceDate: '2026-10-25', status: 'published', items, ...extra },
    });
  await push();
  const token = (await rpc('ensure_share_link', { p_service_id: id })) as string;
  return { token, cleanup: () => push({ deleted: true, status: 'draft' }) };
}
