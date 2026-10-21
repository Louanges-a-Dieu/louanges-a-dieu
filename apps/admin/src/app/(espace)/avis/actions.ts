'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { Uuid } from '@/lib/validation';

const Moderation = z.object({
  id: Uuid,
  status: z.enum(['approved', 'rejected', 'pending']),
  reply: z.string().trim().max(1000).optional(),
  retour: z.string().startsWith('/avis').optional(),
});

const MESSAGES = {
  approved: 'Avis publié.',
  rejected: 'Avis refusé.',
  pending: 'Avis remis en attente.',
} as const;

/** Modération d'un avis (planche 8, écran 11) : publier, refuser, répondre. */
export async function moderateReviewAction(form: FormData) {
  const parsed = Moderation.safeParse(Object.fromEntries(form));
  const retour = parsed.success ? (parsed.data.retour ?? '/avis') : '/avis';
  if (!parsed.success) back(retour, { erreur: 'Demande invalide.' });
  const { supabase } = await requireEditor();
  const { error } = await supabase.rpc('moderate_review', {
    p_id: parsed.data.id,
    p_status: parsed.data.status,
    p_reply: parsed.data.reply ?? null,
  });
  if (error) back(retour, { erreur: errorMessage(error, 'Modération refusée.') });
  revalidatePath('/avis');
  back(retour, { ok: MESSAGES[parsed.data.status] });
}
