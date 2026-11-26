import { describe, expect, it } from 'vitest';

import { highlight, normalizeReplacement, parseCorrection } from '../src/lib/corrections';

const details = {
  key: 'c.xlsx|F|80|h1',
  suggestion: 'pending',
  passages: [
    {
      unit: 'section',
      sectionId: 's1',
      offset: 33,
      current: 'Sépares-toi',
      replacement: 'Sépare-toi',
      context: 'Sépares-toi des œuvres des ténèbres',
    },
  ],
  source: {
    file: 'c.xlsx',
    row: 80,
    original: 'Sépares-toi',
    proposed: 'Sépare-toi',
    confidence: 42,
  },
};

describe('propositions de correction (A-13)', () => {
  it('lit les détails enregistrés par la base', () => {
    const d = parseCorrection(details);
    expect(d?.suggestion).toBe('pending');
    expect(d?.passages[0]?.replacement).toBe('Sépare-toi');
    // Une colonne au format inattendu ne fait pas disparaître la proposition.
    expect(d?.source.confidence).toBeNull();
  });

  it('ignore une anomalie qui n’a pas la forme attendue', () => {
    expect(parseCorrection({ key: 'x' })).toBeNull();
    expect(parseCorrection(null)).toBeNull();
  });

  it('surligne le passage dans ses vers', () => {
    expect(highlight('Le Lion de la tribu de Judas,', 'tribu de Judas')).toEqual([
      'Le Lion de la ',
      'tribu de Judas',
      ',',
    ]);
    expect(highlight('', 'Judas')).toEqual(['', 'Judas', '']);
    expect(highlight('autre texte', 'Judas')).toEqual(['', 'Judas', '']);
  });

  it('ramène les fins de ligne du navigateur à celles du recueil', () => {
    expect(normalizeReplacement('Le Lion\r\nÔ Jésus !\rFin')).toBe('Le Lion\nÔ Jésus !\nFin');
  });
});
