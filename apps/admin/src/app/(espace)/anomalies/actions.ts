'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { IssueStatus, OptionalText, ReturnPath, Uuid } from '@/lib/validation';

const Decision = z.object({
  ids: z.array(Uuid).min(1, 'Sélectionnez au moins une anomalie.').max(500),
  status: IssueStatus,
  note: OptionalText,
});

const LABELS = { open: 'rouverte', resolved: 'résolue', ignored: 'ignorée' } as const;

/** Résoudre, ignorer (justification obligatoire) ou rouvrir des anomalies (9.8). */
export async function resolveIssuesAction(form: FormData) {
  const retour = ReturnPath.parse(form.get('retour'));
  const parsed = Decision.safeParse({
    ids: form.getAll('ids'),
    status: form.get('status'),
    note: form.get('note') ?? '',
  });
  if (!parsed.success)
    back(retour, { erreur: parsed.error.issues[0]?.message ?? 'Demande invalide.' });
  if (parsed.data.status === 'ignored' && !parsed.data.note) {
    back(retour, { erreur: 'Indiquez pourquoi l’anomalie est ignorée.' });
  }
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('resolve_issues', {
    p_issue_ids: parsed.data.ids,
    p_status: parsed.data.status,
    p_note: parsed.data.note,
  });
  if (error) back(retour, { erreur: errorMessage(error, 'Décision refusée.') });
  revalidatePath('/', 'layout');
  const n = Number(data ?? 0);
  back(retour, {
    ok: `${n} anomalie${n > 1 ? 's' : ''} ${LABELS[parsed.data.status]}${n > 1 ? 's' : ''}.`,
  });
}
