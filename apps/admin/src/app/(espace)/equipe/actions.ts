'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireSuperAdmin } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { Uuid } from '@/lib/validation';

const Role = z.enum(['editor', 'super_admin']);

export async function grantRoleAction(form: FormData) {
  const parsed = z
    .object({ email: z.string().trim().toLowerCase().pipe(z.email()), role: Role })
    .safeParse({ email: form.get('email'), role: form.get('role') });
  if (!parsed.success) back('/equipe', { erreur: 'Adresse e-mail ou rôle invalide.' });
  const { supabase } = await requireSuperAdmin();
  const { error } = await supabase.rpc('admin_grant_role', {
    p_email: parsed.data.email,
    p_role: parsed.data.role,
  });
  if (error) back('/equipe', { erreur: errorMessage(error, 'Attribution refusée.') });
  revalidatePath('/equipe');
  back('/equipe', { ok: `Rôle attribué à ${parsed.data.email}.` });
}

export async function revokeRoleAction(form: FormData) {
  const parsed = z
    .object({ user: Uuid, role: Role })
    .safeParse({ user: form.get('user'), role: form.get('role') });
  if (!parsed.success) back('/equipe', { erreur: 'Demande invalide.' });
  const { supabase } = await requireSuperAdmin();
  const { error } = await supabase.rpc('admin_revoke_role', {
    p_user_id: parsed.data.user,
    p_role: parsed.data.role,
  });
  if (error) back('/equipe', { erreur: errorMessage(error, 'Retrait refusé.') });
  revalidatePath('/equipe');
  back('/equipe', { ok: 'Rôle retiré.' });
}
