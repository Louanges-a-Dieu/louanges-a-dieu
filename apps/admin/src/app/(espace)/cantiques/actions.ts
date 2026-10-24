'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { STATUS_LABELS } from '@/components/status';
import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { parseHymnNumber, splitStanzas } from '@/lib/text';
import { PublicationStatus, RequiredText, ReturnPath, Uuid } from '@/lib/validation';

const Batch = z.object({
  ids: z.array(Uuid).min(1, 'Sélectionnez au moins un cantique.').max(500),
  status: PublicationStatus,
  retour: ReturnPath,
});

/**
 * Changement de statut par lots (Q-03). Chaque cantique est traité seul : les
 * refus (anomalie bloquante, droits restreints, transition interdite) sont
 * détaillés sans bloquer les autres. Règles appliquées par la base.
 */
export async function batchStatusAction(form: FormData) {
  const retour = ReturnPath.parse(form.get('retour'));
  const parsed = Batch.safeParse({
    ids: form.getAll('ids'),
    status: form.get('status'),
    retour,
  });
  if (!parsed.success)
    back(retour, { erreur: parsed.error.issues[0]?.message ?? 'Demande invalide.' });
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('set_hymns_status', {
    p_hymn_ids: parsed.data.ids,
    p_status: parsed.data.status,
  });
  if (error) back(retour, { erreur: errorMessage(error, 'Changement de statut impossible.') });

  const results = (data ?? []) as { hymn_id: string; ok: boolean; error: string | null }[];
  const failed = results.filter((r) => !r.ok);
  const { data: labels } = failed.length
    ? await supabase
        .from('hymns')
        .select('id, number_label')
        .in(
          'id',
          failed.map((f) => f.hymn_id),
        )
    : { data: [] };
  const label = new Map((labels ?? []).map((h) => [h.id, h.number_label]));
  revalidatePath('/', 'layout');

  const done = results.length - failed.length;
  const summary = `${done} cantique${done > 1 ? 's' : ''} → « ${STATUS_LABELS[parsed.data.status]} »`;
  if (failed.length === 0) back(retour, { ok: summary });
  back(retour, {
    erreur: [
      `${summary} ; ${failed.length} refusé${failed.length > 1 ? 's' : ''} :`,
      ...failed.slice(0, 20).map((f) => `• ${label.get(f.hymn_id) ?? f.hymn_id} : ${f.error}`),
      failed.length > 20 ? `… et ${failed.length - 20} autres` : '',
    ]
      .filter(Boolean)
      .join('\n'),
  });
}

const NewHymn = z.object({
  edition_id: Uuid,
  number: z.string(),
  title: RequiredText,
  lyrics: z.string().catch(''),
});

/**
 * Nouveau cantique (hors import) : toujours en brouillon (déclencheur de la
 * base), une strophe par paragraphe des paroles ; refrain, références et
 * droits se complètent ensuite sur sa fiche.
 */
export async function createHymnAction(form: FormData) {
  const parsed = NewHymn.safeParse(Object.fromEntries(form));
  if (!parsed.success)
    back('/cantiques', { erreur: 'Numéro, titre et édition sont obligatoires.' });
  const number = parseHymnNumber(parsed.data.number);
  if (!number) {
    back('/cantiques', {
      erreur: 'Numéro invalide : par exemple « 1139 », « 37bis » ou « 12 ter ».',
    });
  }
  const stanzas = splitStanzas(parsed.data.lyrics);
  const { supabase } = await requireEditor();
  const { data: hymn, error } = await supabase
    .from('hymns')
    .insert({
      edition_id: parsed.data.edition_id,
      number_label: number.label,
      number_numeric: number.numeric,
      number_suffix: number.suffix,
      title: parsed.data.title,
      opening_line: stanzas[0]?.split('\n')[0]?.trim() || null,
    })
    .select('id')
    .single();
  if (error) {
    back('/cantiques', {
      erreur:
        error.code === '23505'
          ? `Le numéro ${number.label} existe déjà dans cette édition.`
          : errorMessage(error, 'Création refusée.'),
    });
  }
  if (stanzas.length > 0) {
    const { error: sectionsError } = await supabase.from('hymn_sections').insert(
      stanzas.map((text, i) => ({
        hymn_id: hymn.id,
        section_type: 'verse',
        section_number: i + 1,
        display_order: i,
        text,
      })),
    );
    if (sectionsError) {
      back(`/cantiques/${hymn.id}`, {
        erreur: `Cantique créé, mais paroles refusées : ${errorMessage(sectionsError, 'erreur')}. Ajoutez-les ci-dessous.`,
      });
    }
  }
  revalidatePath('/', 'layout');
  back(`/cantiques/${hymn.id}`, {
    ok: `Cantique ${number.label} créé en brouillon${stanzas.length ? ` (${stanzas.length} strophe${stanzas.length > 1 ? 's' : ''})` : ''}. Marquez le refrain s'il y en a un, puis validez-le.`,
  });
}
