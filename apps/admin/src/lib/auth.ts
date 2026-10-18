import { redirect } from 'next/navigation';

import { createClient, type Supabase } from './supabase/server';

export type AppRole = 'editor' | 'super_admin';

export interface Editor {
  id: string;
  email: string;
  roles: AppRole[];
  isSuperAdmin: boolean;
  supabase: Supabase;
}

/**
 * Couche d'accès (9.1) : session valide, rôle éditorial, second facteur
 * vérifié (aal2). Sinon, redirection vers l'étape manquante. La base applique
 * de toute façon les mêmes règles (RLS, has_role exigeant aal2).
 */
export async function requireEditor(): Promise<Editor> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/connexion');

  // Ses propres rôles restent lisibles sans second facteur (pour le demander).
  const { data: roleRows } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id);
  const roles = (roleRows ?? []).map((r) => r.role as AppRole);
  if (roles.length === 0) redirect('/acces-refuse');

  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel !== 'aal2') redirect('/connexion/mfa');

  return {
    id: user.id,
    email: user.email ?? '',
    roles,
    isSuperAdmin: roles.includes('super_admin'),
    supabase,
  };
}

export async function requireSuperAdmin(): Promise<Editor> {
  const editor = await requireEditor();
  if (!editor.isSuperAdmin) redirect('/acces-refuse');
  return editor;
}
