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
