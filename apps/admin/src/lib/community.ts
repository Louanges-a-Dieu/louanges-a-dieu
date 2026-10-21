/** Statistiques anonymes et avis (planche 8) : types et mises en forme. */

export interface UsageTotals {
  view: number;
  listen: number;
  project: number;
}

export interface UsageDay extends UsageTotals {
  day: string;
}

export interface UsageStats {
  days: number;
  totals: UsageTotals;
  daily: UsageDay[];
  top: { hymnId: string; numberLabel: string; title: string; views: number }[];
}

export interface Overview {
  users: number;
  programs: number;
  sharedPrograms: number;
  pendingReviews: number;
  approvedReviews: number;
  hymnsWithAudio: number;
}

export const PERIODS = [7, 30, 90] as const;

/** Période demandée (7, 30 ou 90 jours ; 30 par défaut). */
export function period(value: string | undefined): number {
  const n = Number(value);
  return (PERIODS as readonly number[]).includes(n) ? n : 30;
}

export const EMPTY_STATS: UsageStats = {
  days: 30,
  totals: { view: 0, listen: 0, project: 0 },
  daily: [],
  top: [],
};

/** Hauteur relative d'une barre (0 à 100), arrondie. */
export function barHeight(value: number, max: number): number {
  return max <= 0 ? 0 : Math.round((value / max) * 100);
}

/** Évolution entre la première et la seconde moitié de la période, en %. */
export function trend(daily: UsageDay[], key: keyof UsageTotals): number | null {
  if (daily.length < 2) return null;
  const half = Math.floor(daily.length / 2);
  const sum = (days: UsageDay[]) => days.reduce((n, d) => n + d[key], 0);
  const before = sum(daily.slice(0, half));
  const after = sum(daily.slice(daily.length - half));
  return before === 0 ? null : Math.round(((after - before) / before) * 100);
}

/** Valeur CSV : guillemets doublés ; neutralise les formules des tableurs. */
function cell(value: string | number): string {
  let text = String(value);
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[";\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

/** Export CSV (séparateur « ; », tableurs français) : jours, puis classement. */
export function statsCsv(stats: UsageStats): string {
  const rows: (string | number)[][] = [
    ['Jour', 'Consultations', 'Écoutes', 'Projections'],
    ...stats.daily.map((d) => [d.day, d.view, d.listen, d.project]),
    [],
    ['Rang', 'Numéro', 'Titre', 'Consultations'],
    ...stats.top.map((t, i) => [i + 1, t.numberLabel, t.title, t.views]),
  ];
  return `﻿${rows.map((r) => r.map(cell).join(';')).join('\r\n')}\r\n`;
}

export const REVIEW_STATUS: Record<string, string> = {
  pending: 'En attente',
  approved: 'Publiés',
  rejected: 'Refusés',
};

export function stars(rating: number): string {
  return '★'.repeat(rating) + '☆'.repeat(Math.max(0, 5 - rating));
}
