import type { Metadata } from 'next';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireSuperAdmin } from '@/lib/auth';
import { param } from '@/lib/data';

import { grantRoleAction, revokeRoleAction } from './actions';

export const metadata: Metadata = { title: 'Équipe — Administration' };

const ROLES: Record<string, string> = { editor: 'Éditeur', super_admin: 'Super administrateur' };

/** Équipe éditoriale (9.1, super administrateur uniquement). */
export default async function TeamPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase, id: me } = await requireSuperAdmin();
  const { data, error } = await supabase.rpc('admin_list_team');
  const team = (data ?? []) as {
    user_id: string;
    email: string;
    roles: string[];
    last_sign_in_at: string | null;
  }[];

  return (
    <>
      <h1 className={ui.h1}>Équipe</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      <table className={ui.table}>
        <thead>
          <tr>
            <th>Adresse</th>
            <th>Rôles</th>
            <th>Dernière connexion</th>
          </tr>
        </thead>
        <tbody>
          {team.map((m) => (
            <tr key={m.user_id}>
              <td>
                {m.email}
                {m.user_id === me && <span className={ui.muted}> (vous)</span>}
              </td>
              <td>
                {m.roles.map((role) => (
                  <form key={role} action={revokeRoleAction} className={ui.row}>
                    <input type="hidden" name="user" value={m.user_id} />
                    <input type="hidden" name="role" value={role} />
                    {ROLES[role] ?? role}
                    <SubmitButton
                      variant="ghost"
                      confirm={`Retirer le rôle « ${ROLES[role]} » à ${m.email} ?`}
                    >
                      Retirer
                    </SubmitButton>
                  </form>
                ))}
              </td>
              <td className={ui.muted}>
                {m.last_sign_in_at ? new Date(m.last_sign_in_at).toLocaleString('fr-FR') : '—'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <section className={ui.card}>
        <h2 className={ui.h2}>Ajouter un membre</h2>
        <p className={ui.hint}>
          La personne doit s’être connectée une première fois (application ou administration) avec
          cette adresse. Elle devra ensuite configurer son second facteur.
        </p>
        <form action={grantRoleAction} className={ui.row}>
          <input
            className={ui.input}
            type="email"
            name="email"
            placeholder="adresse@exemple.org"
            required
            aria-label="Adresse e-mail"
          />
          <select className={ui.select} name="role" defaultValue="editor" aria-label="Rôle">
            <option value="editor">Éditeur</option>
            <option value="super_admin">Super administrateur</option>
          </select>
          <SubmitButton variant="primary">Attribuer</SubmitButton>
        </form>
      </section>
    </>
  );
}
