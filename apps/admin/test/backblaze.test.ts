import { afterEach, describe, expect, it, vi } from 'vitest';

import { StorageKey } from '@lad/shared-contracts';

import { uploadKey } from '../src/lib/audio';
import {
  b2Config,
  b2ErrorMessage,
  bucketName,
  fileExists,
  uploadTarget,
} from '../src/lib/backblaze';

const config = { keyId: 'id', applicationKey: 'secret', bucket: 'CantiquesEA' };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status });
}

function authorization(
  buckets: { id: string; name: string }[] | null,
  capabilities = ['writeFiles'],
) {
  return json({
    accountId: 'acc',
    authorizationToken: 'tok',
    apiInfo: {
      storageApi: { apiUrl: 'https://api004.example', allowed: { buckets, capabilities } },
    },
  });
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('dépôt sur Backblaze', () => {
  it('compartiment tiré de AUDIO_BASE_URL, ou B2_BUCKET', () => {
    vi.stubEnv('B2_BUCKET', '');
    vi.stubEnv('AUDIO_BASE_URL', 'https://f004.backblazeb2.com/file/CantiquesEA');
    expect(bucketName()).toBe('CantiquesEA');
    vi.stubEnv('AUDIO_BASE_URL', 'https://audio.example.org');
    expect(bucketName()).toBeNull();
    vi.stubEnv('B2_BUCKET', 'autre');
    expect(bucketName()).toBe('autre');
  });

  it('non configuré sans clé', () => {
    vi.stubEnv('AUDIO_BASE_URL', 'https://f004.backblazeb2.com/file/CantiquesEA');
    vi.stubEnv('B2_KEY_ID', '');
    vi.stubEnv('B2_APPLICATION_KEY', '');
    expect(b2Config()).toBeNull();
    vi.stubEnv('B2_KEY_ID', 'id');
    vi.stubEnv('B2_APPLICATION_KEY', 'secret');
    expect(b2Config()).toEqual(config);
  });

  it('adresse d’envoi : clé restreinte au compartiment', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(authorization([{ id: 'b1', name: 'CantiquesEA' }]))
      .mockResolvedValueOnce(
        json({ uploadUrl: 'https://pod.example/up', authorizationToken: 'up' }),
      );
    vi.stubGlobal('fetch', fetch);
    await expect(uploadTarget(config)).resolves.toEqual({
      uploadUrl: 'https://pod.example/up',
      authorizationToken: 'up',
    });
    expect(fetch.mock.calls[0]![1].headers.Authorization).toBe(
      `Basic ${Buffer.from('id:secret').toString('base64')}`,
    );
    expect(fetch.mock.calls[1]![0]).toBe(
      'https://api004.example/b2api/v4/b2_get_upload_url?bucketId=b1',
    );
  });

  it('adresse d’envoi : clé générale → recherche du compartiment par son nom', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(authorization(null))
      .mockResolvedValueOnce(json({ buckets: [{ bucketId: 'b2' }] }))
      .mockResolvedValueOnce(
        json({ uploadUrl: 'https://pod.example/up', authorizationToken: 'up' }),
      );
    vi.stubGlobal('fetch', fetch);
    await uploadTarget(config);
    expect(JSON.parse(fetch.mock.calls[1]![1].body)).toEqual({
      accountId: 'acc',
      bucketName: 'CantiquesEA',
    });
    expect(fetch.mock.calls[2]![0]).toContain('bucketId=b2');
  });

  it('erreurs lisibles : clé refusée, lecture seule, compartiment absent', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ code: 'unauthorized' }, 401)));
    await expect(uploadTarget(config).catch(b2ErrorMessage)).resolves.toMatch(
      /Clé Backblaze refusée/,
    );
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(authorization([], ['readFiles'])));
    await expect(uploadTarget(config).catch(b2ErrorMessage)).resolves.toMatch(/Read and Write/);
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValueOnce(authorization([{ id: 'x', name: 'Autre' }]))
        .mockResolvedValueOnce(json({ buckets: [] })),
    );
    await expect(uploadTarget(config).catch(b2ErrorMessage)).resolves.toMatch(/inaccessible/);
  });

  it('présence d’un fichier : 404 → absent, réseau → inconnu', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 200 })));
    await expect(fileExists('https://x/a.mp3')).resolves.toBe(true);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 404 })));
    await expect(fileExists('https://x/a.mp3')).resolves.toBe(false);
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('réseau')));
    await expect(fileExists('https://x/a.mp3')).resolves.toBeNull();
  });

  it('les chemins générés sont acceptés par la base', () => {
    for (const type of ['melody', 'accompaniment', 'choir', 'tenor', 'bass', 'other']) {
      for (const ext of ['mp3', 'm4a', 'aac']) {
        const key = uploadKey({ number_numeric: 37, number_suffix: 'bis' }, type, ext, 3);
        expect(StorageKey.safeParse(key).success).toBe(true);
      }
    }
  });
});
