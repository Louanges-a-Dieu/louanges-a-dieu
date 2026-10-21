'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { themeSlug } from '@/lib/text';
import { RequiredText, Uuid } from '@/lib/validation';

/** Nom d'un thème, et son identifiant d'adresse (unique). */
function named(form: FormData) {
  const parsed = z.object({ name: RequiredText }).safeParse({ name: form.get('name') });
  const slug = parsed.success ? themeSlug(parsed.data.name) : '';
  if (!parsed.success || !slug) back('/themes', { erreur: 'Nom du thème invalide.' });
  return { name: parsed.data.name, slug };
}

export async function createThemeAction(form: FormData) {
  const theme = named(form);
  const { supabase } = await requireEditor();
  const { error } = await supabase.from('themes').insert(theme);
  if (error) {
    back('/themes', {
      erreur:
        error.code === '23505' ? 'Ce thème existe déjà.' : errorMessage(error, 'Création refusée.'),
    });
  }
  revalidatePath('/themes');
  back('/themes', { ok: `Thème « ${theme.name} » créé.` });
}

export async function renameThemeAction(form: FormData) {
  const id = Uuid.safeParse(form.get('id'));
  if (!id.success) back('/themes', { erreur: 'Demande invalide.' });
  const theme = named(form);
  const { supabase } = await requireEditor();
  const { error } = await supabase.from('themes').update(theme).eq('id', id.data);
  if (error) {
    back('/themes', {
      erreur:
        error.code === '23505'
          ? 'Ce thème existe déjà.'
          : errorMessage(error, 'Modification refusée.'),
    });
  }
  revalidatePath('/themes');
  back('/themes', { ok: 'Thème renommé. Il sera dans l’app à la prochaine publication.' });
}

export async function deleteThemeAction(form: FormData) {
  const id = Uuid.safeParse(form.get('id'));
  if (!id.success) back('/themes', { erreur: 'Demande invalide.' });
  const { supabase } = await requireEditor();
  const { error } = await supabase.from('themes').delete().eq('id', id.data);
  if (error) back('/themes', { erreur: errorMessage(error, 'Suppression refusée.') });
  revalidatePath('/themes');
  back('/themes', { ok: 'Thème supprimé (retiré des cantiques).' });
}
