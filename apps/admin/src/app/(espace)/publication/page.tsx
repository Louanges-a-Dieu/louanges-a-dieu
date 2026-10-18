import type { Metadata } from 'next';
import Link from 'next/link';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { listEditions, param } from '@/lib/data';

import { publishAction, rollbackAction } from './actions';

export const metadata: Metadata = { title: 'Publication — Administration' };

const CHANGES = { added: 'Ajouté', changed: 'Modifié', removed: 'Retiré' } as const;

/** Publication (9.7) : résumé du diff, publication, historique et retour arrière. */
export default async function PublicationPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const editions = await listEditions(supabase);
  const edition = param(sp.edition) ?? editions[0]?.id;
  if (!edition) {
    return (
      <>
        <h1 className={ui.h1}>Publication</h1>
        <p>
          Aucune édition : commencez par un <Link href="/import">import</Link>.
        </p>
      </>
    );
  }
  const [{ data: diff, error }, { data: releases }] = await Promise.all([
    supabase.rpc('preview_release', { p_edition_id: edition }),
    supabase
      .from('catalog_releases')
      .select('id, published_at, hymn_count, notes')
      .eq('edition_id', edition)
      .order('id', { ascending: false })
      .limit(30),
  ]);
  const changes = (diff ?? []) as {
    hymn_id: string;
    number_label: string;
    title: string;
    change: keyof typeof CHANGES;
  }[];
  const tally = (c: keyof typeof CHANGES) => changes.filter((x) => x.change === c).length;
  const latest = releases?.[0]?.id;

  return (
    <>
      <h1 className={ui.h1}>Publication</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
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
            Changer d’édition
          </button>
        </form>
      )}

      <section className={ui.card}>
        <h2 className={ui.h2}>Prochaine publication</h2>
        {changes.length === 0 ? (
          <p>Rien à publier : la dernière release contient déjà tous les cantiques validés.</p>
        ) : (
          <>
            <p>
              {tally('added')} ajouté(s), {tally('changed')} modifié(s), {tally('removed')}{' '}
              retiré(s). Seuls les cantiques <strong>validés</strong> changent ; les autres gardent
              leur version publiée.
            </p>
            <table className={ui.table}>
              <thead>
                <tr>
                  <th>N°</th>
                  <th>Titre</th>
                  <th>Changement</th>
                </tr>
              </thead>
              <tbody>
                {changes.slice(0, 300).map((c) => (
                  <tr key={c.hymn_id}>
                    <td className={ui.number}>{c.number_label}</td>
                    <td>
                      <Link href={`/cantiques/${c.hymn_id}`}>{c.title}</Link>
                    </td>
                    <td>{CHANGES[c.change]}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {changes.length > 300 && (
              <p className={ui.muted}>… et {changes.length - 300} autres.</p>
            )}
            <form action={publishAction}>
              <input type="hidden" name="edition" value={edition} />
              <label className={ui.field}>
                <span className={ui.label}>Note de publication (facultative)</span>
                <input className={ui.input} name="notes" maxLength={500} />
              </label>
              <SubmitButton
                variant="primary"
                confirm={`Publier ces ${changes.length} changement(s) ? Toutes les applications les recevront.`}
              >
                Publier
              </SubmitButton>
            </form>
          </>
        )}
      </section>

      <section className={ui.card}>
        <h2 className={ui.h2}>Releases publiées</h2>
        <table className={ui.table}>
          <thead>
            <tr>
              <th>N°</th>
              <th>Date</th>
              <th>Cantiques</th>
              <th>Note</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {(releases ?? []).map((r) => (
              <tr key={r.id}>
                <td>{r.id}</td>
                <td>{new Date(r.published_at).toLocaleString('fr-FR')}</td>
                <td>{r.hymn_count}</td>
                <td>{r.notes ?? ''}</td>
                <td>
                  {r.id === latest ? (
                    <span className={ui.muted}>Courante</span>
                  ) : (
                    <form action={rollbackAction}>
                      <input type="hidden" name="edition" value={edition} />
                      <input type="hidden" name="release" value={r.id} />
                      <SubmitButton
                        variant="ghost"
                        confirm={`Revenir au contenu de la release n° ${r.id} ? Une nouvelle release sera publiée avec ce contenu.`}
                      >
                        Revenir à ce contenu
                      </SubmitButton>
                    </form>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}
