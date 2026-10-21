import type { Metadata } from 'next';
import Link from 'next/link';

import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { barHeight, EMPTY_STATS, period, PERIODS, trend, type UsageStats } from '@/lib/community';
import { param } from '@/lib/data';

import styles from '../page.module.css';

export const metadata: Metadata = { title: 'Statistiques — Administration' };

const LABELS = { view: 'Consultations', listen: 'Écoutes', project: 'Projections' } as const;

/**
 * Statistiques d'utilisation (planche 8, écran 10) : compteurs anonymes
 * envoyés par l'app (aucune donnée personnelle), par jour et par cantique.
 */
export default async function StatsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const days = period(param(sp.jours));
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('usage_stats', { p_days: days });
  const stats = (data ?? EMPTY_STATS) as UsageStats;
  const max = Math.max(1, ...stats.daily.map((d) => d.view));

  return (
    <>
      <h1 className={ui.h1}>Statistiques</h1>
      {error && (
        <p className={ui.error} role="alert">
          {error.message}
        </p>
      )}
      <p className={ui.hint}>
        Compteurs anonymes envoyés par l’application (sans compte, appareil ni adresse) ; chaque
        fidèle peut les désactiver.
      </p>
      <nav className={ui.row} aria-label="Période">
        {PERIODS.map((p) => (
          <Link
            key={p}
            href={`/statistiques?jours=${p}`}
            className={p === days ? ui.buttonPrimary : ui.button}
            aria-current={p === days ? 'page' : undefined}
          >
            {p} jours
          </Link>
        ))}
        <a className={ui.buttonGhost} href={`/statistiques/export?jours=${days}`} download>
          Exporter (CSV)
        </a>
      </nav>

      <div className={styles.grid}>
        {(Object.keys(LABELS) as (keyof typeof LABELS)[]).map((key) => {
          const change = trend(stats.daily, key);
          return (
            <div key={key} className={styles.stat}>
              <span className={styles.value}>{stats.totals[key].toLocaleString('fr-FR')}</span>
              {LABELS[key]}
              {change !== null && (
                <span className={ui.muted}>
                  {' '}
                  · {change > 0 ? '+' : ''}
                  {change} %
                </span>
              )}
            </div>
          );
        })}
      </div>

      <section className={ui.card}>
        <h2 className={ui.h2}>Consultations par jour</h2>
        {stats.totals.view === 0 ? (
          <p className={ui.muted}>Aucune consultation sur la période.</p>
        ) : (
          <figure className={styles.chart}>
            <div
              className={styles.bars}
              role="img"
              aria-label={`Consultations par jour sur ${days} jours, maximum ${max}`}
            >
              {stats.daily.map((d) => (
                <span
                  key={d.day}
                  className={styles.bar}
                  style={{ height: `${barHeight(d.view, max)}%` }}
                  title={`${new Date(d.day).toLocaleDateString('fr-FR')} : ${d.view}`}
                />
              ))}
            </div>
            <figcaption className={styles.axis}>
              <span>{new Date(stats.daily[0]!.day).toLocaleDateString('fr-FR')}</span>
              <span>{new Date(stats.daily.at(-1)!.day).toLocaleDateString('fr-FR')}</span>
            </figcaption>
          </figure>
        )}
      </section>

      <section className={ui.card}>
        <h2 className={ui.h2}>Cantiques les plus consultés</h2>
        {stats.top.length === 0 ? (
          <p className={ui.muted}>Aucune consultation sur la période.</p>
        ) : (
          <table className={ui.table}>
            <thead>
              <tr>
                <th>Rang</th>
                <th>Cantique</th>
                <th>Consultations</th>
              </tr>
            </thead>
            <tbody>
              {stats.top.map((t, i) => (
                <tr key={t.hymnId}>
                  <td>{i + 1}</td>
                  <td>
                    <Link href={`/cantiques/${t.hymnId}`}>
                      <span className={ui.number}>{t.numberLabel}</span> {t.title}
                    </Link>
                  </td>
                  <td>{t.views.toLocaleString('fr-FR')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  );
}
