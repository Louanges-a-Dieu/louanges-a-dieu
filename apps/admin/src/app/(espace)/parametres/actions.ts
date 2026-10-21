'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireSuperAdmin } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';

const Setting = z.object({
  key: z.enum(['comments_enabled', 'stats_enabled']),
  value: z.enum(['true', 'false']),
});

/** Paramètres de l'app (planche 8, écran 13), super administrateur. */
export async function setSettingAction(form: FormData) {
  const parsed = Setting.safeParse(Object.fromEntries(form));
  if (!parsed.success) back('/parametres', { erreur: 'Demande invalide.' });
  const { supabase, id } = await requireSuperAdmin();
  const { data, error } = await supabase
    .from('app_settings')
    .update({
      value: parsed.data.value === 'true',
      updated_at: new Date().toISOString(),
      updated_by: id,
    })
    .eq('key', parsed.data.key)
    .select('key');
  if (error || !data?.length)
    back('/parametres', { erreur: errorMessage(error, 'Modification refusée.') });
  revalidatePath('/parametres');
  back('/parametres', { ok: 'Paramètre enregistré.' });
}
