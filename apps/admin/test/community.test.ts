import { describe, expect, it } from 'vitest';

import { barHeight, period, stars, statsCsv, trend, type UsageDay } from '../src/lib/community';

const day = (d: string, view: number): UsageDay => ({ day: d, view, listen: 0, project: 0 });

describe('statistiques', () => {
  it('période : 7, 30 ou 90 jours, 30 par défaut', () => {
    expect(period('7')).toBe(7);
    expect(period('90')).toBe(90);
    expect(period('365')).toBe(30);
    expect(period(undefined)).toBe(30);
  });

  it('barres et évolution', () => {
    expect(barHeight(5, 10)).toBe(50);
    expect(barHeight(3, 0)).toBe(0);
    const daily = [
      day('2026-10-18', 2),
      day('2026-10-19', 2),
      day('2026-10-20', 3),
      day('2026-10-21', 3),
    ];
    expect(trend(daily, 'view')).toBe(50);
    expect(trend([day('2026-10-21', 3)], 'view')).toBeNull();
    expect(trend([day('a', 0), day('b', 4)], 'view')).toBeNull();
  });

  it('export CSV : séparateur « ; », formules neutralisées', () => {
    const csv = statsCsv({
      days: 7,
      totals: { view: 1, listen: 0, project: 0 },
      daily: [day('2026-10-21', 1)],
      top: [{ hymnId: 'h', numberLabel: '12', title: '=HYPERLINK("x"); "Titre"', views: 1 }],
    });
    expect(csv.startsWith('﻿Jour;Consultations;Écoutes;Projections\r\n2026-10-21;1;0;0')).toBe(
      true,
    );
    expect(csv).toContain(`1;12;"'=HYPERLINK(""x""); ""Titre""";1`);
  });

  it('étoiles', () => {
    expect(stars(4)).toBe('★★★★☆');
  });
});

import {
  cueProblems,
  editableCues,
  parseTenths,
  shiftCues,
  tenths,
  toCueRows,
} from '../src/lib/karaoke';

describe('ajustement de la synchronisation karaoké', () => {
  const lines = [
    { sectionId: 's1', lineIndex: 0, text: 'Premier vers', section: 'Couplet 1' },
    { sectionId: 's1', lineIndex: 1, text: 'Deuxième vers', section: null },
    { sectionId: 'r', lineIndex: 0, text: 'Refrain', section: 'Refrain' },
  ];
  const cues = [
    { section_id: 's1', line_index: 0, start_ms: 1000, end_ms: 4000 },
    { section_id: 's1', line_index: 1, start_ms: 4000, end_ms: 8000 },
    { section_id: 'r', line_index: 0, start_ms: 9000, end_ms: 12000 },
  ];

  it('retrouve le texte et la section de chaque vers synchronisé', () => {
    const rows = editableCues(cues, lines);
    expect(rows.map((r) => r.text)).toEqual(['Premier vers', 'Deuxième vers', 'Refrain']);
    expect(rows.map((r) => r.section)).toEqual(['Couplet 1', null, 'Refrain']);
    expect(toCueRows(rows)).toEqual(cues);
  });

  it('signale fin avant début et chevauchement, sans rien effacer', () => {
    const rows = editableCues(cues, lines);
    rows[1] = { ...rows[1]!, start: 3500 };
    rows[2] = { ...rows[2]!, end: 9000 };
    expect(cueProblems(rows)).toEqual([
      null,
      'commence avant la fin du vers précédent',
      'la fin doit suivre le début',
    ]);
  });

  it('décale tous les vers, jamais avant 0', () => {
    const rows = shiftCues(editableCues(cues, lines), -1500);
    expect(rows.map((r) => [r.start, r.end])).toEqual([
      [0, 2500],
      [2500, 6500],
      [7500, 10500],
    ]);
  });

  it('temps au dixième de seconde', () => {
    expect(tenths(65_340)).toBe('1:05.3');
    expect(parseTenths('1:05.3')).toBe(65_300);
    expect(parseTenths('65,25')).toBe(65_250);
    expect(parseTenths('1:75')).toBeNull();
    expect(parseTenths('abc')).toBeNull();
  });
});
