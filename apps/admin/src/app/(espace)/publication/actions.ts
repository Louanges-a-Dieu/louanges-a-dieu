'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { OptionalText, Uuid } from '@/lib/validation';

/** Publication d'une release (9.7). */
export async function publishAction(form: FormData) {
  const parsed = z
    .object({ edition: Uuid, notes: OptionalText })
    .safeParse({ edition: form.get('edition'), notes: form.get('notes') ?? '' });
  if (!parsed.success) back('/publication', { erreur: 'Édition invalide.' });
  const { supabase } = await requireEditor();
  const { data: before } = await supabase
    .from('catalog_releases')
    .select('id')
    .order('id', { ascending: false })
    .limit(1);
  const { data, error } = await supabase.rpc('publish_release', {
    p_edition_id: parsed.data.edition,
    p_notes: parsed.data.notes,
  });
  if (error) back('/publication', { erreur: errorMessage(error, 'Publication refusée.') });
  revalidatePath('/', 'layout');
  if (before?.[0]?.id === data)
    back('/publication', { ok: 'Aucun changement : rien n’a été publié.' });
  back('/publication', {
    ok: `Release n° ${data} publiée : les applications la recevront à leur prochaine vérification.`,
  });
}

/** Retour arrière : nouvelle release au contenu d'une release précédente. */
export async function rollbackAction(form: FormData) {
  const parsed = z
    .object({ edition: Uuid, release: z.coerce.number().int().positive() })
    .safeParse({ edition: form.get('edition'), release: form.get('release') });
  if (!parsed.success) back('/publication', { erreur: 'Release invalide.' });
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('rollback_release', {
    p_edition_id: parsed.data.edition,
    p_release_id: parsed.data.release,
  });
  if (error) back('/publication', { erreur: errorMessage(error, 'Retour arrière refusé.') });
  revalidatePath('/', 'layout');
  back('/publication', {
    ok: `Release n° ${data} publiée avec le contenu de la release n° ${parsed.data.release}.`,
  });
}
