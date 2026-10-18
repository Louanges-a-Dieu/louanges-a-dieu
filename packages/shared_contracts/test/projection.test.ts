import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { PublishedHymn } from '../src/hymn.ts';
import { hymnSlides, programSlides, splitLines, type ProgramEntry } from '../src/projection.ts';

/** Mêmes fixtures que les tests Dart (apps/mobile/test/core/projection). */
const dir = join(import.meta.dirname, '../fixtures/projection');
const fixtures = readdirSync(dir)
  .filter((f) => f.endsWith('.json'))
  .map((f) => ({ name: f, ...JSON.parse(readFileSync(join(dir, f), 'utf8')) }));

describe('diapositives (fixtures partagées)', () => {
  it('les fixtures existent', () => expect(fixtures.length).toBeGreaterThanOrEqual(7));

  for (const f of fixtures) {
    it(`${f.name} — ${f.description}`, () => {
      const slides = f.program
        ? programSlides(
            (f.program as { label?: string; hymn?: unknown }[]).map((e): ProgramEntry =>
              e.label !== undefined
                ? { label: e.label }
                : { hymn: e.hymn ? PublishedHymn.parse(e.hymn) : null },
            ),
            f.options,
          )
        : hymnSlides(PublishedHymn.parse(f.hymn), f.options);
      expect(slides).toEqual(f.expected);
    });
  }
});

describe('splitLines', () => {
  it('équilibre les parties', () => {
    const n = (k: number) => Array.from({ length: k }, (_, i) => String(i));
    expect(splitLines(n(6), 6).map((p) => p.length)).toEqual([6]);
    expect(splitLines(n(7), 6).map((p) => p.length)).toEqual([4, 3]);
    expect(splitLines(n(13), 6).map((p) => p.length)).toEqual([5, 4, 4]);
    expect(splitLines(n(12), 6).map((p) => p.length)).toEqual([6, 6]);
  });

  it('refuse maxLines < 1', () => expect(() => splitLines(['a'], 0)).toThrow(RangeError));
});
