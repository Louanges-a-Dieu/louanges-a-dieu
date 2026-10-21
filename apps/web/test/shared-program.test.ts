import { describe, expect, it, vi } from 'vitest';

import {
  fetchSharedProgram,
  loadSharedProgram,
  formatServiceDate,
  isPlausibleToken,
  parseSharedProgram,
  SharedProgramServiceError,
} from '../src/lib/shared-program';

const config = { url: 'https://exemple.supabase.co', publishableKey: 'sb_publishable_test' };
const token = 'A'.repeat(32);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('isPlausibleToken', () => {
  it('accepte un jeton base64url de 32 caractères ou plus', () => {
    expect(isPlausibleToken(token)).toBe(true);
    expect(isPlausibleToken('abc_DEF-123'.padEnd(40, 'x'))).toBe(true);
  });

  it('refuse les jetons courts, trop longs ou hors alphabet', () => {
    expect(isPlausibleToken('court')).toBe(false);
    expect(isPlausibleToken('A'.repeat(129))).toBe(false);
    expect(isPlausibleToken(`${'A'.repeat(31)}%`)).toBe(false);
    expect(isPlausibleToken(`${'A'.repeat(32)}' or 1=1`)).toBe(false);
  });
});

describe('parseSharedProgram', () => {
  it('lit cantiques, moments libres et cantiques retirés, dans l’ordre', () => {
    const program = parseSharedProgram({
      title: 'Culte de Pâques',
      serviceDate: '2026-04-05',
      items: [
        { position: 2, label: null, notes: null, hymn: { unavailable: true } },
        { position: 0, label: 'Accueil', notes: '', hymn: null },
        {
          position: 1,
          label: null,
          notes: 'Couplets 1 et 3',
          hymn: { id: 'h1', numberLabel: '37 bis', title: 'Au matin' },
        },
      ],
    });
    expect(program).toEqual({
      title: 'Culte de Pâques',
      serviceDate: '2026-04-05',
      location: null,
      description: null,
      items: [
        { position: 0, label: 'Accueil', notes: null, hymn: null },
        {
          position: 1,
          label: null,
          notes: 'Couplets 1 et 3',
          hymn: { id: 'h1', numberLabel: '37 bis', title: 'Au matin' },
        },
        { position: 2, label: null, notes: null, hymn: { unavailable: true } },
      ],
    });
  });

  it('lit le lieu et la description', () => {
    const program = parseSharedProgram({
      title: 'Culte',
      serviceDate: null,
      location: 'Temple central',
      description: 'Louange et adoration.',
      items: [],
    });
    expect(program?.location).toBe('Temple central');
    expect(program?.description).toBe('Louange et adoration.');
  });

  it('null signifie « lien indisponible »', () => {
    expect(parseSharedProgram(null)).toBeNull();
  });

  it('rejette une réponse mal formée', () => {
    expect(() => parseSharedProgram({ title: 'x' })).toThrow(TypeError);
    expect(() =>
      parseSharedProgram({ title: 'x', items: [{ position: 0, hymn: { id: 'h' } }] }),
    ).toThrow(TypeError);
  });
});

describe('fetchSharedProgram', () => {
  it('n’interroge pas le serveur pour un jeton invalide', async () => {
    const fetchImpl = vi.fn<typeof fetch>();
    expect(await fetchSharedProgram('../../etc', config, fetchImpl)).toBeNull();
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('appelle get_shared_program avec la seule clé publique', async () => {
    const fetchImpl = vi.fn<typeof fetch>().mockResolvedValue(json(null));
    expect(await fetchSharedProgram(token, config, fetchImpl)).toBeNull();
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(url).toBe('https://exemple.supabase.co/rest/v1/rpc/get_shared_program');
    expect(init?.method).toBe('POST');
    expect(init?.body).toBe(JSON.stringify({ p_token: token }));
    expect(init?.cache).toBe('no-store');
    expect((init?.headers as Record<string, string>).apikey).toBe('sb_publishable_test');
    expect(init?.headers).not.toHaveProperty('Authorization');
  });

  it('distingue une panne du service d’un lien indisponible', async () => {
    await expect(
      fetchSharedProgram(token, config, vi.fn<typeof fetch>().mockResolvedValue(json({}, 503))),
    ).rejects.toBeInstanceOf(SharedProgramServiceError);
    await expect(
      fetchSharedProgram(
        token,
        config,
        vi.fn<typeof fetch>().mockRejectedValue(new TypeError('fetch failed')),
      ),
    ).rejects.toBeInstanceOf(SharedProgramServiceError);
  });
});

describe('formatServiceDate', () => {
  it('formate un jour civil en français, sans décalage de fuseau', () => {
    expect(formatServiceDate('2026-04-05')).toBe('dimanche 5 avril 2026');
    expect(formatServiceDate('2026-12-31')).toBe('jeudi 31 décembre 2026');
  });

  it('ignore une date mal formée', () => {
    expect(formatServiceDate('05/04/2026')).toBeNull();
  });
});

describe('loadSharedProgram', () => {
  const env = { SUPABASE_URL: config.url, SUPABASE_PUBLISHABLE_KEY: config.publishableKey };

  it('configuration absente : message de service, jamais d’erreur brute', async () => {
    const fetchImpl = vi.fn<typeof fetch>();
    expect(await loadSharedProgram(token, {}, fetchImpl)).toBe('service-error');
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('panne réseau : message de service ; lien inconnu : null', async () => {
    expect(
      await loadSharedProgram(
        token,
        env,
        vi.fn<typeof fetch>().mockRejectedValue(new TypeError('x')),
      ),
    ).toBe('service-error');
    expect(
      await loadSharedProgram(token, env, vi.fn<typeof fetch>().mockResolvedValue(json(null))),
    ).toBeNull();
  });
});
