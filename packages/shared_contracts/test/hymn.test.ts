import { readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

import { PublishedHymn } from '../src/hymn.ts';
import { SCHEMAS, toJsonSchemaText } from '../src/schemas.ts';

const dir = resolve(import.meta.dirname, '../fixtures/hymn');
const fixtures = readdirSync(dir).filter((f) => f.endsWith('.json'));
const load = (file: string): unknown => JSON.parse(readFileSync(resolve(dir, file), 'utf8'));

describe('PublishedHymn — fixtures partagées (aussi utilisées par les tests Dart)', () => {
  it('contient au moins une fixture valide et une invalide', () => {
    expect(fixtures.some((f) => f.startsWith('valid-'))).toBe(true);
    expect(fixtures.some((f) => f.startsWith('invalid-'))).toBe(true);
  });

  for (const file of fixtures) {
    const shouldPass = file.startsWith('valid-');
    it(`${file} est ${shouldPass ? 'accepté' : 'refusé'}`, () => {
      expect(PublishedHymn.safeParse(load(file)).success).toBe(shouldPass);
    });
  }
});

describe('règle « ne jamais inventer »', () => {
  it('refuse une chaîne vide pour une valeur inconnue', () => {
    const result = PublishedHymn.safeParse(load('invalid-unknown-as-text.json'));
    expect(result.success).toBe(false);
    expect(JSON.stringify(result.error?.issues)).toContain('utiliser null');
  });

  it('accepte des métadonnées absentes exprimées par null et des listes vides', () => {
    const hymn = PublishedHymn.parse(load('valid-minimal-unknown-metadata.json'));
    expect(hymn.openingLine).toBeNull();
    expect(hymn.people).toEqual([]);
    expect(hymn.themes).toEqual([]);
  });
});

describe('numéros spéciaux', () => {
  it('accepte « 37bis » cohérent avec 37 + bis', () => {
    expect(PublishedHymn.parse(load('valid-with-refrain-and-bis.json')).numberLabel).toBe('37bis');
  });

  it('refuse un libellé incohérent', () => {
    expect(PublishedHymn.safeParse(load('invalid-label-mismatch.json')).success).toBe(false);
  });
});

describe('JSON Schema', () => {
  const expectedRequired: Record<keyof typeof SCHEMAS, string[]> = {
    'published-hymn.schema.json': ['id', 'numberLabel', 'sections'],
    'catalog-draft.schema.json': ['format', 'version', 'source', 'hymns', 'issues'],
  };

  for (const [file, schema] of Object.entries(SCHEMAS)) {
    it(`${file} décrit les champs obligatoires`, () => {
      const json = JSON.parse(toJsonSchemaText(schema)) as { required?: string[] };
      expect(json.required).toEqual(
        expect.arrayContaining(expectedRequired[file as keyof typeof SCHEMAS]),
      );
    });
  }
});
