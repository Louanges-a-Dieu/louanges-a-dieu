import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { PublishedHymn } from '../src/hymn.ts';
import {
  goTo,
  hymnSlides,
  programSlides,
  slideLabel,
  splitLines,
  stateMessage,
  type ProgramEntry,
} from '../src/projection.ts';

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

describe('état de projection', () => {
  const slides = hymnSlides(
    PublishedHymn.parse(fixtures.find((f) => f.name === 'refrain-repete.json')!.hymn),
  );

  it('borne la position et produit le message des écrans', () => {
    const state = { slides, index: 0, blank: false };
    expect(goTo(state, -3).index).toBe(0);
    expect(goTo(state, 99).index).toBe(slides.length - 1);
    expect(stateMessage(goTo(state, 1))).toEqual({
      type: 'state',
      v: 1,
      index: 1,
      count: slides.length,
      blank: false,
      slide: slides[1],
    });
    expect(stateMessage({ slides: [], index: 0, blank: true }).slide).toBeNull();
  });

  it('libellés identiques à ceux de l’app', () => {
    expect(slides.map(slideLabel)).toEqual([
      '12 — Cantique A',
      'Couplet 1',
      'Refrain',
      'Couplet 2',
      'Refrain',
      'Couplet 3',
      'Refrain',
    ]);
    expect(slideLabel({ kind: 'section', label: 'Prière' })).toBe('Prière');
    const split = hymnSlides(
      PublishedHymn.parse(fixtures.find((f) => f.name === 'decoupe-et-note.json')!.hymn),
    );
    expect(slideLabel(split[2]!)).toBe('Couplet 1 (1/2)');
  });
});
