import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import ui from '@/components/ui.module.css';
import { createClient } from '@/lib/supabase/server';

import { signOutAction } from '../actions';
import styles from '../auth.module.css';
import { MfaForm } from './mfa-form';

export const metadata: Metadata = { title: 'Second facteur — Administration' };

export default async function MfaPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/connexion');
  const { data: roles } = await supabase.from('user_roles').select('role').eq('user_id', user.id);
  if (!roles?.length) redirect('/acces-refuse');
  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel === 'aal2') redirect('/');
  const { data: factors } = await supabase.auth.mfa.listFactors();
  const verified = factors?.totp.find((f) => f.status === 'verified') ?? null;

  return (
    <main className={styles.page}>
      <div className={styles.panel}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={ui.h1}>Second facteur</h1>
        <p className={ui.hint}>Connecté : {user.email}</p>
        <MfaForm factorId={verified?.id ?? null} />
        <form action={signOutAction}>
          <button type="submit" className={ui.buttonGhost}>
            Se déconnecter
          </button>
        </form>
      </div>
    </main>
  );
}
