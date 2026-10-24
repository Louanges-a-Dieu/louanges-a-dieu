import type { Metadata } from 'next';
import Link from 'next/link';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import { RIGHTS_LABELS, STATUS_LABELS, StatusBadge } from '@/components/status';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { listEditions, param } from '@/lib/data';

import { batchStatusAction, createHymnAction } from './actions';
import styles from './cantiques.module.css';

export const metadata: Metadata = { title: 'Cantiques — Administration' };

const PAGE_SIZE = 50;

interface Row {
  id: string;
  number_label: string;
  title: string;
  opening_line: string | null;
  status: string;
  rights_status: string;
  open_issues: number;
  blocking_issues: number;
  updated_at: string;
  total_count: number;
}

/** Liste des cantiques (9.3) : filtres, recherche, validation par lots (9.6). */
export default async function HymnsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const editions = await listEditions(supabase);
  const q = param(sp.q);
  const statut = param(sp.statut);
  const anomalies = param(sp.anomalies);
  const droits = param(sp.droits);
  const edition = param(sp.edition) ?? editions[0]?.id;
  const page = Math.max(1, Number(param(sp.page) ?? 1) || 1);

  const { data, error } = await supabase.rpc('search_hymns_admin', {
    p_query: q ?? null,
    p_status: statut ?? null,
    p_issues: anomalies ?? null,
    p_rights: droits ?? null,
    p_limit: PAGE_SIZE,
    p_offset: (page - 1) * PAGE_SIZE,
    p_edition_id: edition ?? null,
  });
  const rows = (data ?? []) as Row[];
  const total = rows[0]?.total_count ?? 0;
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const query = new URLSearchParams();
  for (const [k, v] of Object.entries({ q, statut, anomalies, droits, edition })) {
    if (v) query.set(k, v);
  }
  const pageLink = (n: number) => {
    const next = new URLSearchParams(query);
    next.set('page', String(n));
    return `/cantiques?${next}`;
  };
  const retour = `/cantiques?${query}${page > 1 ? `&page=${page}` : ''}`;

  return (
    <>
      <h1 className={ui.h1}>Cantiques</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />

      <details className={ui.card}>
        <summary>
          <strong>Nouveau cantique</strong>
        </summary>
        <p className={ui.hint}>
          Créé en brouillon. Paroles : une strophe par paragraphe, avec une ligne vide entre deux
          strophes. Le refrain, les références et les droits se règlent ensuite sur la fiche.
        </p>
        <form action={createHymnAction} className={ui.field}>
          <div className={ui.row}>
            <label className={ui.field}>
              <span className={ui.label}>Numéro</span>
              <input className={ui.input} name="number" required placeholder="1139 ou 37bis" />
            </label>
            <label className={ui.field}>
              <span className={ui.label}>Titre</span>
              <input className={ui.input} name="title" required />
            </label>
            <label className={ui.field}>
              <span className={ui.label}>Édition</span>
              <select className={ui.select} name="edition_id" defaultValue={edition}>
                {editions.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.name}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label className={ui.field}>
            <span className={ui.label}>Paroles (facultatif)</span>
            <textarea className={ui.textarea} name="lyrics" rows={10} />
          </label>
          <div className={ui.row}>
            <SubmitButton variant="primary">Créer le cantique</SubmitButton>
          </div>
        </form>
      </details>

      <form className={styles.filters} method="get" role="search">
        <label className={ui.field}>
          <span className={ui.label}>Recherche (numéro, titre, texte)</span>
          <input className={ui.input} name="q" defaultValue={q} placeholder="37bis, gloire…" />
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Statut</span>
          <select className={ui.select} name="statut" defaultValue={statut ?? ''}>
            <option value="">Tous</option>
            {Object.entries(STATUS_LABELS).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Anomalies</span>
          <select className={ui.select} name="anomalies" defaultValue={anomalies ?? ''}>
            <option value="">Indifférent</option>
            <option value="open">Avec anomalie ouverte</option>
            <option value="blocking">Avec anomalie bloquante</option>
            <option value="none">Sans anomalie</option>
          </select>
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Droits</span>
          <select className={ui.select} name="droits" defaultValue={droits ?? ''}>
            <option value="">Tous</option>
            {Object.entries(RIGHTS_LABELS).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </label>
        {editions.length > 1 && (
          <label className={ui.field}>
            <span className={ui.label}>Édition</span>
            <select className={ui.select} name="edition" defaultValue={edition}>
              {editions.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.name}
                </option>
              ))}
            </select>
          </label>
        )}
        <button type="submit" className={ui.button}>
          Filtrer
        </button>
      </form>

      <form action={batchStatusAction}>
        <input type="hidden" name="retour" value={retour} />
        <div className={styles.toolbar}>
          <span className={ui.muted}>
            {total} cantique{total > 1 ? 's' : ''} · page {page}/{pages}
          </span>
          <span className={ui.row}>
            <span className={ui.muted}>Sélection :</span>
            <SubmitButton name="status" value="review">
              Soumettre en relecture
            </SubmitButton>
            <SubmitButton
              name="status"
              value="published"
              variant="primary"
              confirm="Valider les cantiques sélectionnés ? Ils seront inclus dans la prochaine publication."
            >
              Valider
            </SubmitButton>
            <SubmitButton name="status" value="draft">
              Renvoyer en brouillon
            </SubmitButton>
          </span>
        </div>
        <table className={ui.table}>
          <thead>
            <tr>
              <th scope="col">
                <span className={styles.visuallyHidden}>Sélection</span>
              </th>
              <th scope="col">N°</th>
              <th scope="col">Titre</th>
              <th scope="col">Statut</th>
              <th scope="col">Anomalies</th>
              <th scope="col">Droits</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((h) => (
              <tr key={h.id}>
                <td>
                  <input
                    type="checkbox"
                    name="ids"
                    value={h.id}
                    aria-label={`Sélectionner le ${h.number_label}`}
                  />
                </td>
                <td className={ui.number}>{h.number_label}</td>
                <td>
                  <Link href={`/cantiques/${h.id}`}>{h.title}</Link>
                  {h.opening_line && h.opening_line !== h.title && (
                    <div className={ui.muted}>{h.opening_line}</div>
                  )}
                </td>
                <td>
                  <StatusBadge status={h.status} />
                </td>
                <td>
                  {h.blocking_issues > 0 ? (
                    <span className={`${ui.badge} ${ui.blocking}`}>
                      {h.blocking_issues} bloquante(s)
                    </span>
                  ) : h.open_issues > 0 ? (
                    <span className={`${ui.badge} ${ui.warning}`}>{h.open_issues}</span>
                  ) : (
                    <span className={ui.muted}>—</span>
                  )}
                </td>
                <td className={ui.muted}>{RIGHTS_LABELS[h.rights_status] ?? h.rights_status}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {rows.length === 0 && <p className={ui.muted}>Aucun cantique ne correspond.</p>}
      </form>

      {pages > 1 && (
        <nav className={styles.pager} aria-label="Pages">
          {page > 1 && (
            <Link className={ui.button} href={pageLink(page - 1)}>
              ‹ Précédente
            </Link>
          )}
          {page < pages && (
            <Link className={ui.button} href={pageLink(page + 1)}>
              Suivante ›
            </Link>
          )}
        </nav>
      )}
    </>
  );
}
