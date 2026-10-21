import type { Metadata } from 'next';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { param } from '@/lib/data';

import { createThemeAction, deleteThemeAction, renameThemeAction } from './actions';

export const metadata: Metadata = { title: 'Thèmes — Administration' };

/**
 * Thèmes du recueil (planche 8, écran 7) : liste, nombre de cantiques,
 * création, renommage, suppression. Un thème s'attribue sur la fiche d'un
 * cantique ; il apparaît dans l'app après publication.
 */
export default async function ThemesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const { data, error } = await supabase
    .from('themes')
    .select('id, name, slug, hymn_themes(count)')
    .order('name');
  const themes = (data ?? []).map((t) => ({
    id: t.id as string,
    name: t.name as string,
    count: ((t.hymn_themes as unknown as { count: number }[])[0]?.count ?? 0) as number,
  }));

  return (
    <>
      <h1 className={ui.h1}>Thèmes</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      <p className={ui.hint}>
        À attribuer seulement quand le thème est sûr, depuis la fiche du cantique (section « Auteurs
        et thèmes »). Les thèmes apparaissent dans l’application après la prochaine publication.
      </p>
      {themes.length === 0 ? (
        <p className={ui.muted}>Aucun thème pour le moment.</p>
      ) : (
        <table className={ui.table}>
          <thead>
            <tr>
              <th>Thème</th>
              <th>Cantiques</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {themes.map((t) => (
              <tr key={t.id}>
                <td>
                  <form action={renameThemeAction} className={ui.row}>
                    <input type="hidden" name="id" value={t.id} />
                    <input
                      className={ui.input}
                      name="name"
                      defaultValue={t.name}
                      required
                      aria-label={`Nom du thème ${t.name}`}
                    />
                    <SubmitButton variant="ghost">Renommer</SubmitButton>
                  </form>
                </td>
                <td>{t.count}</td>
                <td>
                  <form action={deleteThemeAction}>
                    <input type="hidden" name="id" value={t.id} />
                    <SubmitButton
                      variant="danger"
                      confirm={`Supprimer le thème « ${t.name} » ? Il sera retiré de ${t.count} cantique(s).`}
                    >
                      Supprimer
                    </SubmitButton>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <section className={ui.card}>
        <h2 className={ui.h2}>Nouveau thème</h2>
        <form action={createThemeAction} className={ui.row}>
          <input className={ui.input} name="name" required aria-label="Nom du thème" />
          <SubmitButton variant="primary">Créer</SubmitButton>
        </form>
      </section>
    </>
  );
}
