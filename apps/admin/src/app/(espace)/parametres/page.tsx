import type { Metadata } from 'next';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireSuperAdmin } from '@/lib/auth';
import { param } from '@/lib/data';

import { setSettingAction } from './actions';

export const metadata: Metadata = { title: 'Paramètres — Administration' };

const SETTINGS = [
  {
    key: 'comments_enabled',
    title: 'Avis des fidèles',
    hint: 'Permet de noter et commenter un cantique dans l’app (publication après modération).',
  },
  {
    key: 'stats_enabled',
    title: 'Statistiques anonymes',
    hint: 'Compteurs de consultations, d’écoutes et de projections, sans aucune donnée personnelle.',
  },
] as const;

/** Paramètres de l'application (planche 8, écran 13), super administrateur. */
export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireSuperAdmin();
  const { data, error } = await supabase.from('app_settings').select('key, value, updated_at');
  const values = new Map((data ?? []).map((s) => [s.key as string, s]));

  return (
    <>
      <h1 className={ui.h1}>Paramètres de l’application</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      {SETTINGS.map((s) => {
        const row = values.get(s.key);
        const enabled = row?.value === true;
        return (
          <section key={s.key} className={ui.card}>
            <h2 className={ui.h2}>{s.title}</h2>
            <p className={ui.hint}>{s.hint}</p>
            <form action={setSettingAction} className={ui.row}>
              <input type="hidden" name="key" value={s.key} />
              <input type="hidden" name="value" value={enabled ? 'false' : 'true'} />
              <strong>{enabled ? 'Activé' : 'Désactivé'}</strong>
              <SubmitButton variant={enabled ? 'danger' : 'primary'}>
                {enabled ? 'Désactiver' : 'Activer'}
              </SubmitButton>
              {row?.updated_at && (
                <span className={ui.muted}>
                  modifié le {new Date(row.updated_at).toLocaleString('fr-FR')}
                </span>
              )}
            </form>
          </section>
        );
      })}
    </>
  );
}
