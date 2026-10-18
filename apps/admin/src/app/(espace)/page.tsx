import type { Metadata } from 'next';
import Link from 'next/link';

import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { listEditions, param } from '@/lib/data';

import styles from './page.module.css';

export const metadata: Metadata = { title: 'Tableau de bord — Administration' };

interface Stats {
  byStatus: Record<string, number>;
  total: number;
  openIssues: Record<string, number>;
  latestRelease: {
    id: number;
    publishedAt: string;
    hymnCount: number;
    notes: string | null;
  } | null;
}

/** Tableau de bord (9.2). */
export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const editions = await listEditions(supabase);
  const edition = param(sp.edition) ?? editions[0]?.id;
  const { data } = await supabase.rpc('editorial_stats', { p_edition_id: edition ?? null });
  const stats = (data ?? { byStatus: {}, total: 0, openIssues: {}, latestRelease: null }) as Stats;
  const count = (s: string) => stats.byStatus[s] ?? 0;
  const validated = count('published');
  const reviewable = stats.total - count('archived');
  const progress = reviewable > 0 ? Math.round((validated / reviewable) * 100) : 0;
  const issues = (s: string) => stats.openIssues[s] ?? 0;

  return (
    <>
      <h1 className={ui.h1}>Tableau de bord</h1>
      {editions.length > 1 && (
        <form method="get" className={ui.row}>
          <select className={ui.select} name="edition" defaultValue={edition} aria-label="Édition">
            {editions.map((e) => (
              <option key={e.id} value={e.id}>
                {e.name}
              </option>
            ))}
          </select>
          <button className={ui.button} type="submit">
            Afficher
          </button>
        </form>
      )}
      <div className={styles.grid}>
        <Link className={styles.stat} href={`/cantiques?statut=published&edition=${edition ?? ''}`}>
          <span className={styles.value}>{validated}</span>
          Validés
        </Link>
        <Link className={styles.stat} href={`/cantiques?statut=review&edition=${edition ?? ''}`}>
          <span className={styles.value}>{count('review')}</span>
          En relecture
        </Link>
        <Link className={styles.stat} href={`/cantiques?statut=draft&edition=${edition ?? ''}`}>
          <span className={styles.value}>{count('draft')}</span>
          Brouillons
        </Link>
        <Link className={styles.stat} href="/anomalies?gravite=blocking">
          <span className={styles.value}>{issues('blocking')}</span>
          Anomalies bloquantes
        </Link>
        <Link className={styles.stat} href="/anomalies">
          <span className={styles.value}>
            {issues('blocking') + issues('warning') + issues('info')}
          </span>
          Anomalies ouvertes
        </Link>
      </div>

      <section className={ui.card}>
        <h2 className={ui.h2}>Progression de la revue</h2>
        <progress className={styles.progress} value={validated} max={Math.max(reviewable, 1)}>
          {progress} %
        </progress>
        <p>
          {validated} cantiques validés sur {reviewable} ({progress} %)
          {count('archived') > 0 && (
            <span className={ui.muted}> · {count('archived')} archivés</span>
          )}
        </p>
      </section>

      <section className={ui.card}>
        <h2 className={ui.h2}>Catalogue publié</h2>
        {stats.latestRelease ? (
          <p>
            Release n° {stats.latestRelease.id} du{' '}
            {new Date(stats.latestRelease.publishedAt).toLocaleString('fr-FR', {
              dateStyle: 'long',
              timeStyle: 'short',
            })}{' '}
            · {stats.latestRelease.hymnCount} cantiques
            {stats.latestRelease.notes && (
              <span className={ui.muted}> · {stats.latestRelease.notes}</span>
            )}
          </p>
        ) : (
          <p>Aucune release publiée.</p>
        )}
        <Link className={ui.button} href={`/publication?edition=${edition ?? ''}`}>
          Préparer une publication
        </Link>
      </section>
    </>
  );
}
