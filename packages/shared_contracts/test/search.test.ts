import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { fold } from '../src/search.ts';

/** Mêmes cas que les tests Dart (apps/mobile/test/core/search/normalize_test.dart). */
const fixture = JSON.parse(
  readFileSync(join(import.meta.dirname, '../fixtures/search/normalization.json'), 'utf8'),
) as { cases: { input: string; folded: string }[] };

describe('fold', () => {
  it('le jeu de cas n’est pas vide', () => expect(fixture.cases.length).toBeGreaterThan(10));
  for (const c of fixture.cases) {
    it(JSON.stringify(c.input), () => expect(fold(c.input)).toBe(c.folded));
  }
  it('est idempotent', () => {
    for (const c of fixture.cases) expect(fold(fold(c.input))).toBe(fold(c.input));
  });
});
