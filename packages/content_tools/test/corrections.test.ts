import { strToU8, zipSync } from 'fflate';
import { describe, expect, it } from 'vitest';

import {
  CorrectionMatcher,
  parseCorrections,
  type CorrectionRow,
  type TextUnit,
} from '../src/corrections.ts';
import { buildSuggestions, sourceDigest } from '../src/suggestions.ts';
import { readXlsx } from '../src/xlsx.ts';

const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');

/** Classeur minimal : chaînes partagées pour l'en-tête, chaînes en ligne ensuite. */
function xlsx(rows: string[][]): Uint8Array {
  const header = rows[0]!;
  const col = (i: number) => String.fromCharCode(65 + i);
  const sheet = rows
    .map((cells, r) => {
      const xml = cells
        .map((v, i) => {
          if (v === '') return '';
          const ref = `${col(i)}${r + 1}`;
          return r === 0
            ? `<c r="${ref}" t="s"><v>${i}</v></c>`
            : `<c r="${ref}" t="inlineStr"><is><t>${esc(v)}</t></is></c>`;
        })
        .join('');
      return `<row r="${r + 1}">${xml}</row>`;
    })
    .join('');
  return zipSync({
    'xl/workbook.xml': strToU8(
      '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Corrections" r:id="rId1"/></sheets></workbook>',
    ),
    'xl/_rels/workbook.xml.rels': strToU8(
      '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
    ),
    'xl/sharedStrings.xml': strToU8(
      `<sst>${header.map((h) => `<si><r><t>${esc(h)}</t></r><rPh><t>x</t></rPh></si>`).join('')}</sst>`,
    ),
    'xl/worksheets/sheet1.xml': strToU8(`<worksheet><sheetData>${sheet}</sheetData></worksheet>`),
  });
}

const HEADER = [
  'N° du cantique',
  'Titre',
  'Extrait fautif',
  'Problème',
  'Correction proposée',
  'Confiance',
  'Validation',
  'Commentaire',
];

const units: TextUnit[] = [
  {
    hymnId: 'h1',
    numberLabel: '37',
    hymnTitle: 'O jour heureux',
    unit: 'title',
    sectionId: null,
    text: 'O jour heureux',
  },
  {
    hymnId: 'h1',
    numberLabel: '37',
    hymnTitle: 'O jour heureux',
    unit: 'section',
    sectionId: 's1',
    text: 'Ô jour heureux, jour de bonheur,\nSépares-toi des œuvres des ténèbres\nQue l’Éternel soit béni',
  },
  {
    hymnId: 'h2',
    numberLabel: '1110',
    hymnTitle: 'Mon âme',
    unit: 'section',
    sectionId: 's2',
    text: 'Le Lion de la tribu de Judas,\nÔ Jésus !',
  },
  {
    hymnId: 'h3',
    numberLabel: '403',
    hymnTitle: 'Rassasié',
    unit: 'section',
    sectionId: 's3',
    text: 'Tu combles mon cœur\nEt mon âme satisfaite,',
  },
];

function row(
  original: string,
  proposed: string,
  extra: Partial<CorrectionRow> = {},
): CorrectionRow {
  return {
    file: 'c.xlsx',
    sheet: 'Corrections',
    row: 2,
    number: null,
    title: null,
    original,
    proposed,
    problem: null,
    confidence: null,
    validation: null,
    comment: null,
    ...extra,
  };
}

describe('lecture des tableurs de corrections', () => {
  it('lit les colonnes par leur en-tête et ignore les lignes incomplètes', () => {
    const file = xlsx([
      HEADER,
      ['12', 'O jour heureux', 'O jour', 'Accent', 'Ô jour', 'Haute', '', ''],
      ['13', 'Autre', 'sans correction', '', '', '', '', ''],
      ['14', 'Mon âme', 'Judas', 'Nom', 'Juda', '', 'Non', 'Voulu & assumé'],
    ]);
    const rows = parseCorrections(readXlsx(file), 'c.xlsx');
    expect(rows).toHaveLength(2);
    expect(rows[0]).toMatchObject({
      row: 2,
      number: '12',
      original: 'O jour',
      proposed: 'Ô jour',
      confidence: 'Haute',
    });
    expect(rows[1]).toMatchObject({ row: 4, validation: 'Non', comment: 'Voulu & assumé' });
  });

  it('refuse un classeur sans colonnes « Extrait » et « Correction »', () => {
    expect(() =>
      parseCorrections(
        readXlsx(
          xlsx([
            ['A', 'B'],
            ['1', '2'],
          ]),
        ),
        'x.xlsx',
      ),
    ).toThrow(/Extrait/);
  });
});

describe('rapprochement avec le texte actuel', () => {
  const matcher = new CorrectionMatcher(units);

  it('à appliquer : le passage fautif est encore là', () => {
    const m = matcher.match(
      row('Sépares-toi des œuvres des ténèbres', 'Sépare-toi des œuvres des ténèbres'),
    );
    expect(m.status).toBe('pending');
    if (m.status !== 'pending') return;
    expect(m.passages[0]).toMatchObject({
      current: 'Sépares-toi des œuvres des ténèbres',
      replacement: 'Sépare-toi des œuvres des ténèbres',
      offset: 33,
    });
  });

  it('déjà fait : le texte contient la correction', () => {
    expect(
      matcher.match(row('O jour heureux, jour de bonheur,', 'Ô jour heureux, jour de bonheur,'))
        .status,
    ).toBe('applied');
  });

  it('apostrophe typographique du recueil conservée dans la correction', () => {
    const m = matcher.match(row("Que l'Eternel soit béni", "Que l'Éternel soit béni"));
    expect(m.status).toBe('applied');
  });

  it('à arbitrer : le passage a été retouché autrement (passage le plus proche du cantique désigné)', () => {
    const m = matcher.match(
      row('Et satisfait mon âme', 'Et satisfais mon âme', { title: 'Rassasié' }),
    );
    expect(m.status).toBe('conflict');
    expect(m.passages[0]?.current).toBe('Et mon âme satisfaite,');
    // Sans titre pour désigner le cantique, rien n'est proposé.
    expect(matcher.match(row('Et satisfait mon âme', 'Et satisfais mon âme')).status).toBe(
      'not_found',
    );
  });

  it('refusée dans le tableur', () => {
    expect(matcher.match(row('Judas', 'Juda', { validation: 'Non' })).status).toBe('declined');
  });

  it('introuvable', () => {
    expect(matcher.match(row('les pêcheurs se relèvent', 'les pécheurs se relèvent')).status).toBe(
      'not_found',
    );
  });

  it('le titre du tableur départage plusieurs cantiques', () => {
    const m = matcher.match(row('O jour', 'Ô jour', { title: 'O jour heureux' }));
    expect(m.status).toBe('pending');
    if (m.status !== 'pending') return;
    expect(m.passages.map((p) => p.unit.unit)).toEqual(['title']);
  });
});

describe('propositions pour la file éditoriale', () => {
  it('regroupe par cantique, compte tout, ne garde que l’utile', () => {
    const { stats, suggestions } = buildSuggestions(
      [
        row('Sépares-toi', 'Sépare-toi', { row: 2 }),
        row('O jour heureux', 'Ô jour heureux', { row: 3, title: 'O jour heureux' }),
        row('tribu de Judas', 'tribu de Juda', { row: 4 }),
        row('Et satisfait mon âme', 'Et satisfais mon âme', { row: 5, title: 'Rassasié' }),
        row('les pêcheurs', 'les pécheurs', { row: 6 }),
        row('Judas', 'Juda', { row: 7, validation: 'non' }),
        row('O jour heureux, jour de bonheur,', 'Ô jour heureux, jour de bonheur,', { row: 8 }),
      ],
      units,
    );
    expect(stats).toEqual({ applied: 1, pending: 3, conflict: 1, not_found: 1, declined: 1 });
    expect(suggestions.map((s) => [s.key, s.status])).toEqual([
      ['c.xlsx|Corrections|2|h1', 'pending'],
      ['c.xlsx|Corrections|3|h1', 'pending'],
      ['c.xlsx|Corrections|4|h2', 'pending'],
      ['c.xlsx|Corrections|5|h3', 'conflict'],
      ['c.xlsx|Corrections|6', 'not_found'],
    ]);
    const judah = suggestions[2]!.passages[0]!;
    expect(judah).toEqual({
      unit: 'section',
      sectionId: 's2',
      offset: 14,
      current: 'tribu de Judas',
      replacement: 'tribu de Juda',
      context: 'Le Lion de la tribu de Judas,',
    });
    const conflict = suggestions[3]!;
    expect(conflict.passages[0]).toMatchObject({
      replacement: null,
      context: 'Et mon âme satisfaite,',
    });
    // Titre corrigé, section déjà juste : seul le titre est proposé.
    expect(suggestions[1]!.passages.map((p) => p.unit)).toEqual(['title']);
    expect(suggestions[4]).toMatchObject({ hymnId: null, passages: [] });
  });

  it('empreinte des sources : dépend du nom et du contenu', () => {
    const a = sourceDigest([{ name: 'a.xlsx', bytes: strToU8('1') }]);
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(sourceDigest([{ name: 'b.xlsx', bytes: strToU8('1') }])).not.toBe(a);
    expect(sourceDigest([{ name: 'a.xlsx', bytes: strToU8('2') }])).not.toBe(a);
  });
});
