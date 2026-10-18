/**
 * Partage de bout en bout avec le VRAI serveur de développement (T-007, 7.6) :
 * un responsable connecté publie un programme et obtient un lien, puis la page
 * publique le lit avec la seule clé publique. Lien désactivé, expiré, programme
 * dépublié et jeton au hasard donnent exactement la même réponse.
 *
 * Nécessite apps/web/.env.local et apps/mobile/config/dev-test-user.json
 * (créé par `node tools/pgtap/create-test-user.ts`) ; ignoré sinon (CI).
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { fetchSharedProgram, type SupabaseConfig } from '../../src/lib/shared-program';

const envFile = resolve(import.meta.dirname, '../../.env.local');
const userFile = resolve(import.meta.dirname, '../../../mobile/config/dev-test-user.json');
const available = existsSync(envFile) && existsSync(userFile);

function readEnv(): SupabaseConfig {
  const env = Object.fromEntries(
    readFileSync(envFile, 'utf8')
      .split('\n')
      .filter((line) => line.includes('='))
      .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1).trim()]),
  );
  return { url: env.SUPABASE_URL ?? '', publishableKey: env.SUPABASE_PUBLISHABLE_KEY ?? '' };
}

describe.skipIf(!available)('programme partagé — serveur réel', () => {
  let config: SupabaseConfig;
  let accessToken: string;
  const serviceId = randomUUID();
  let hymn: { hymn_id: string; numberLabel: string; title: string };

  async function rpc(name: string, params: object): Promise<unknown> {
    const response = await fetch(`${config.url}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        apikey: config.publishableKey,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(params),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${name} : ${response.status} ${text}`);
    return text ? JSON.parse(text) : null;
  }

  const push = (status: string, extra: object = {}) =>
    rpc('sync_push_worship_service', {
      p_service: {
        id: serviceId,
        title: 'Essai de partage (test d’intégration)',
        serviceDate: '2026-04-05',
        status,
        items: [
          { id: randomUUID(), label: 'Accueil', notes: 'Debout', order: 0 },
          { id: randomUUID(), hymnId: hymn.hymn_id, notes: null, order: 1 },
        ],
        ...extra,
      },
    });

  beforeAll(async () => {
    config = readEnv();
    const user = JSON.parse(readFileSync(userFile, 'utf8')) as { email: string; password: string };
    const session = await fetch(`${config.url}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(user),
    });
    expect(session.ok, 'connexion de l’utilisateur de test').toBe(true);
    accessToken = ((await session.json()) as { access_token: string }).access_token;

    const hymns = await fetch(
      `${config.url}/rest/v1/published_hymns?select=hymn_id,numberLabel:payload->>numberLabel,title:payload->>title&order=release_id.desc&limit=1`,
      { headers: { apikey: config.publishableKey } },
    );
    [hymn] = (await hymns.json()) as (typeof hymn)[];
    expect(hymn, 'au moins un cantique publié').toBeDefined();
    await push('published');
  });

  afterAll(async () => {
    if (accessToken && hymn) await push('draft', { deleted: true });
  });

  it('le lien donne le programme publié : numéros, titres, moments, notes', async () => {
    const token = (await rpc('ensure_share_link', { p_service_id: serviceId })) as string;
    expect(token).toMatch(/^[A-Za-z0-9_-]{32,}$/);
    expect(await rpc('ensure_share_link', { p_service_id: serviceId })).toBe(token);

    const program = await fetchSharedProgram(token, config);
    expect(program).toEqual({
      title: 'Essai de partage (test d’intégration)',
      serviceDate: '2026-04-05',
      items: [
        { position: 0, label: 'Accueil', notes: 'Debout', hymn: null },
        {
          position: 1,
          label: null,
          notes: null,
          hymn: { id: hymn.hymn_id, numberLabel: hymn.numberLabel, title: hymn.title },
        },
      ],
    });
    // Rien sur le créateur (ni identifiant, ni e-mail) dans la réponse brute.
    const raw = JSON.stringify(program);
    expect(raw).not.toContain('integration-test');
    expect(raw).not.toMatch(/owner|user|email/i);
  });

  it('lien désactivé, programme dépublié, lien expiré, jeton au hasard : même réponse', async () => {
    const random = randomBytes(24).toString('base64url');
    expect(await fetchSharedProgram(random, config)).toBeNull();

    const revoked = (await rpc('ensure_share_link', { p_service_id: serviceId })) as string;
    await rpc('revoke_share_link', { p_service_id: serviceId });
    expect(await fetchSharedProgram(revoked, config), 'désactivé aussitôt').toBeNull();

    const live = (await rpc('ensure_share_link', { p_service_id: serviceId })) as string;
    expect(live).not.toBe(revoked);
    await push('draft');
    expect(await fetchSharedProgram(live, config), 'dépublié').toBeNull();
    await push('published');
    expect(await fetchSharedProgram(live, config)).not.toBeNull();

    // Marge de 8 s : sous charge, quelques appels réseau peuvent prendre du temps.
    const expiresAt = Date.now() + 8_000;
    const expiring = (await rpc('create_share_link', {
      p_service_id: serviceId,
      p_expires_at: new Date(expiresAt).toISOString(),
    })) as string;
    expect(await fetchSharedProgram(expiring, config)).not.toBeNull();
    await new Promise((r) => setTimeout(r, Math.max(0, expiresAt - Date.now())));
    let expired = await fetchSharedProgram(expiring, config);
    for (let i = 0; expired !== null && i < 10; i++) {
      await new Promise((r) => setTimeout(r, 500));
      expired = await fetchSharedProgram(expiring, config);
    }
    expect(expired, 'expiré').toBeNull();
  }, 45_000);
});
