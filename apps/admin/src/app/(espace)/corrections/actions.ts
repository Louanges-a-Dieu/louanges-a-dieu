'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { normalizeReplacement } from '@/lib/corrections';
import { back, errorMessage } from '@/lib/redirect';
import { ReturnPath, Uuid } from '@/lib/validation';

const Apply = z.object({
  id: Uuid,
  replacements: z.array(z.string().max(20_000)).max(20),
});

/**
 * Applique une proposition de correction (A-13) : texte proposé, ou texte
 * ajusté par l'éditeur. La base vérifie que le passage est toujours là,
 * journalise et repasse le cantique en brouillon s'il était validé.
 */
export async function applyCorrectionAction(form: FormData) {
  const retour = ReturnPath.parse(form.get('retour'));
  const parsed = Apply.safeParse({
    id: form.get('id'),
    replacements: form.getAll('remplacement').map((v) => normalizeReplacement(String(v))),
  });
  if (!parsed.success) back(retour, { erreur: 'Demande invalide.' });
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('apply_correction', {
    p_issue_id: parsed.data.id,
    p_replacements: parsed.data.replacements.length ? parsed.data.replacements : null,
  });
  if (error) back(retour, { erreur: errorMessage(error, 'Correction refusée.') });
  revalidatePath('/', 'layout');
  const n = (data as { applied?: unknown[] } | null)?.applied?.length ?? 0;
  back(retour, {
    ok: `Correction appliquée (${n} passage${n > 1 ? 's' : ''}). S’il était validé, le cantique repasse en brouillon jusqu’à sa prochaine validation.`,
  });
}

const Decision = z.object({
  id: Uuid,
  status: z.enum(['ignored', 'resolved']),
  note: z
    .string()
    .transform((v) => v.trim())
    .catch(''),
});

/**
 * Refuser une proposition (justification obligatoire : elle ne reviendra pas
 * au prochain chargement des tableurs) ou la marquer traitée à la main.
 */
export async function decideCorrectionAction(form: FormData) {
  const retour = ReturnPath.parse(form.get('retour'));
  const parsed = Decision.safeParse({
    id: form.get('id'),
    status: form.get('status'),
    note: form.get('note') ?? '',
  });
  if (!parsed.success) back(retour, { erreur: 'Demande invalide.' });
  const { id, status, note } = parsed.data;
  if (status === 'ignored' && !note)
    back(retour, { erreur: 'Indiquez pourquoi la proposition est refusée.' });
  const { supabase } = await requireEditor();
  const { error } = await supabase.rpc('resolve_issues', {
    p_issue_ids: [id],
    p_status: status,
    p_note: note || (status === 'resolved' ? 'Traitée à la main dans la fiche du cantique' : null),
  });
  if (error) back(retour, { erreur: errorMessage(error, 'Décision refusée.') });
  revalidatePath('/', 'layout');
  back(retour, {
    ok: status === 'ignored' ? 'Proposition refusée.' : 'Proposition marquée traitée.',
  });
}
