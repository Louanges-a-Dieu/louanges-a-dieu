import { describe, expect, it, vi } from 'vitest';

import { syncCatalog } from '../../src/lib/projection/catalog';
import { keyAction } from '../../src/lib/projection/keys';
import {
  listSavedPrograms,
  programEntries,
  removeProgram,
  saveProgram,
  toSavedProgram,
} from '../../src/lib/projection/saved-programs';
import { searchHymns } from '../../src/lib/projection/search';
import { memoryStore } from '../../src/lib/projection/store';
import { hymn } from './helpers';

const config = { url: 'https://exemple.supabase.co', publishableKey: 'sb_publishable_test' };
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('searchHymns', () => {
  const hymns = [
    hymn('37bis', 'Oh ! quel beau jour'),
    hymn('37', 'Au matin'),
    hymn('370', 'Trois cent soixante-dix'),
    hymn('12', 'L’Éternel est mon berger'),
    hymn('5', 'Chant', ['Mon cœur Te loue,']),
  ];
  const labels = (q: string) => searchHymns(hymns, q).map((h) => h.numberLabel);

  it('numéro exact d’abord, puis numéros qui commencent pareil', () => {
    expect(labels('37')).toEqual(['37', '37bis', '370']);
    expect(labels('37 bis')).toEqual(['37bis']);
    expect(labels('37BIS')).toEqual(['37bis']);
  });

  it('titres et premiers vers, sans accents ni apostrophes', () => {
    expect(labels('eternel')).toEqual(['12']);
    expect(labels('l eternel')).toEqual(['12']);
    expect(labels('coeur')).toEqual(['5']);
    expect(labels('beau jour')).toEqual(['37bis']);
  });

  it('saisie vide ou introuvable', () => {
    expect(labels('  ')).toEqual([]);
    expect(labels('introuvable')).toEqual([]);
  });
});

describe('syncCatalog', () => {
  const hymns = [hymn('1', 'Premier')];
  const snapshot = { releaseId: 7, contentHash: 'h7', hymns };

  it('premier téléchargement puis réutilisation tant que le contenu ne change pas', async () => {
    const store = memoryStore();
    const fetchImpl = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json({ releaseId: 7, contentHash: 'h7' }))
      .mockResolvedValueOnce(json(snapshot))
      .mockResolvedValueOnce(json({ releaseId: 7, contentHash: 'h7' }));
    const first = await syncCatalog(config, store, fetchImpl);
    expect(first.kind).toBe('fresh');
    expect(first.kind === 'fresh' && first.catalog.hymns).toHaveLength(1);
    const second = await syncCatalog(config, store, fetchImpl);
    expect(second.kind).toBe('fresh');
    expect(fetchImpl).toHaveBeenCalledTimes(3);
    expect(fetchImpl.mock.calls[1]![0]).toContain('get_catalog_snapshot');
    expect(fetchImpl.mock.calls[2]![0]).toContain('get_catalog_manifest');
  });

  it('sans Internet : copie locale, ou rien si jamais téléchargé', async () => {
    const offline = vi.fn<typeof fetch>().mockRejectedValue(new TypeError('fetch failed'));
    expect((await syncCatalog(config, memoryStore(), offline)).kind).toBe('missing');
    const store = memoryStore();
    await store.set('catalog', { ...snapshot, checkedAt: '2026-10-18T00:00:00Z' });
    const status = await syncCatalog(config, store, offline);
    expect(status.kind).toBe('cached');
  });

  it('une réponse invalide ne remplace pas la copie valide', async () => {
    const store = memoryStore();
    await store.set('catalog', { ...snapshot, checkedAt: '2026-10-18T00:00:00Z' });
    const bad = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json({ releaseId: 8, contentHash: 'h8' }))
      .mockResolvedValueOnce(json({ releaseId: 8, contentHash: 'h8', hymns: [{ id: 'x' }] }));
    const status = await syncCatalog(config, store, bad);
    expect(status.kind).toBe('cached');
    expect(status.kind === 'cached' && status.catalog.contentHash).toBe('h7');
  });
});

describe('programmes préparés', () => {
  const h = hymn('12', 'Cantique');
  const shared = {
    title: 'Culte du dimanche',
    serviceDate: '2026-10-25',
    items: [
      { position: 0, label: 'Accueil', notes: 'Debout', hymn: null },
      {
        position: 1,
        label: null,
        notes: null,
        hymn: { id: h.id, numberLabel: '12', title: 'Cantique' },
      },
      { position: 2, label: null, notes: null, hymn: { unavailable: true as const } },
    ],
  };

  it('ne garde que l’utile : identifiants des cantiques et moments libres', () => {
    const saved = toSavedProgram(shared, new Date('2026-10-18T10:00:00Z'));
    expect(saved).toEqual({
      id: 'Culte du dimanche|2026-10-25',
      title: 'Culte du dimanche',
      serviceDate: '2026-10-25',
      savedAt: '2026-10-18T10:00:00.000Z',
      items: [
        { hymnId: null, label: 'Accueil' },
        { hymnId: h.id, label: null },
        { hymnId: null, label: null },
      ],
    });
    expect(programEntries(saved, new Map([[h.id, h]]))).toEqual([
      { label: 'Accueil' },
      { hymn: h },
    ]);
  });

  it('enregistrer remplace le même programme ; retirer le supprime', async () => {
    const store = memoryStore();
    await saveProgram(store, toSavedProgram(shared));
    await saveProgram(store, toSavedProgram({ ...shared, title: 'Autre' }));
    await saveProgram(store, toSavedProgram(shared));
    expect((await listSavedPrograms(store)).map((p) => p.title)).toEqual([
      'Culte du dimanche',
      'Autre',
    ]);
    await removeProgram(store, 'Autre|2026-10-25');
    expect(await listSavedPrograms(store)).toHaveLength(1);
  });
});

describe('keyAction', () => {
  it('flèches, pages (télécommandes), espace, écran noir', () => {
    expect(['ArrowRight', 'PageDown', ' '].map(keyAction)).toEqual(['next', 'next', 'next']);
    expect(['ArrowLeft', 'PageUp'].map(keyAction)).toEqual(['previous', 'previous']);
    expect(['b', 'B', '.'].map(keyAction)).toEqual(['blank', 'blank', 'blank']);
    expect(keyAction('Home')).toBe('first');
    expect(keyAction('x')).toBeNull();
  });
});
