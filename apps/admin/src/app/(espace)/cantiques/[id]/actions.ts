'use server';

import { revalidatePath } from 'next/cache';
import { z } from 'zod';

import { requireEditor } from '@/lib/auth';
import { back, errorMessage } from '@/lib/redirect';
import { normalizeSectionText, themeSlug } from '@/lib/text';
import {
  OptionalInt,
  OptionalText,
  PublicationStatus,
  RelationType,
  RequiredText,
  RightsStatus,
  SectionType,
  Uuid,
} from '@/lib/validation';

const page = (id: string) => `/cantiques/${id}`;

function done(id: string, ok: string): never {
  revalidatePath(page(id));
  back(page(id), { ok });
}

async function run(
  id: string,
  ok: string,
  call: () => PromiseLike<{ error: { message?: string } | null }>,
) {
  const { error } = await call();
  if (error) back(page(id), { erreur: errorMessage(error, 'Modification refusée.') });
  done(id, ok);
}

// ------------------------------------------------------------- métadonnées

const Metadata = z.object({
  id: Uuid,
  title: RequiredText,
  opening_line: OptionalText,
  editorial_notes: OptionalText,
});

export async function updateMetadataAction(form: FormData) {
  const parsed = Metadata.safeParse(Object.fromEntries(form));
  const id = String(form.get('id'));
  if (!parsed.success) back(page(id), { erreur: 'Le titre est obligatoire.' });
  const { supabase } = await requireEditor();
  const { id: hymnId, ...values } = parsed.data;
  await run(hymnId, 'Informations enregistrées.', () =>
    supabase.from('hymns').update(values).eq('id', hymnId),
  );
}

// ---------------------------------------------------------------- sections

const Section = z.object({
  hymn_id: Uuid,
  section_id: Uuid.optional().or(z.literal('').transform(() => undefined)),
  section_type: SectionType,
  section_number: OptionalInt,
  text: RequiredText,
});

export async function saveSectionAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = Section.safeParse(Object.fromEntries(form));
  if (!parsed.success)
    back(page(hymnId), { erreur: 'Section invalide : le texte est obligatoire.' });
  const { supabase } = await requireEditor();
  const { section_id, hymn_id, ...rest } = parsed.data;
  const values = { ...rest, text: normalizeSectionText(rest.text) };
  if (section_id) {
    await run(hymn_id, 'Section enregistrée.', () =>
      supabase.from('hymn_sections').update(values).eq('id', section_id).eq('hymn_id', hymn_id),
    );
  }
  const { data: last } = await supabase
    .from('hymn_sections')
    .select('display_order')
    .eq('hymn_id', hymn_id)
    .order('display_order', { ascending: false })
    .limit(1);
  const display_order = (last?.[0]?.display_order ?? -1) + 1;
  await run(hymn_id, 'Section ajoutée.', () =>
    supabase.from('hymn_sections').insert({ ...values, hymn_id, display_order }),
  );
}

const SectionRef = z.object({ hymn_id: Uuid, section_id: Uuid });

export async function deleteSectionAction(form: FormData) {
  const parsed = SectionRef.parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  await run(parsed.hymn_id, 'Section supprimée.', () =>
    supabase
      .from('hymn_sections')
      .delete()
      .eq('id', parsed.section_id)
      .eq('hymn_id', parsed.hymn_id),
  );
}

const Move = SectionRef.extend({ direction: z.enum(['up', 'down']) });

/** Échange la position avec la section voisine. */
export async function moveSectionAction(form: FormData) {
  const parsed = Move.parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  const { data: sections } = await supabase
    .from('hymn_sections')
    .select('id, display_order')
    .eq('hymn_id', parsed.hymn_id)
    .order('display_order');
  const list = sections ?? [];
  const i = list.findIndex((s) => s.id === parsed.section_id);
  const j = parsed.direction === 'up' ? i - 1 : i + 1;
  if (i < 0 || j < 0 || j >= list.length) done(parsed.hymn_id, 'Ordre inchangé.');
  const [a, b] = [list[i]!, list[j]!];
  for (const [id, order] of [
    [a.id, b.display_order],
    [b.id, a.display_order],
  ] as const) {
    const { error } = await supabase
      .from('hymn_sections')
      .update({ display_order: order })
      .eq('id', id);
    if (error) back(page(parsed.hymn_id), { erreur: errorMessage(error, 'Déplacement refusé.') });
  }
  done(parsed.hymn_id, 'Ordre des sections modifié.');
}

// -------------------------------------------------------------- références

const Reference = z.object({
  hymn_id: Uuid,
  book: RequiredText,
  chapter_start: z.coerce.number().int().positive(),
  verse_start: OptionalInt,
  chapter_end: OptionalInt,
  verse_end: OptionalInt,
  display_text: OptionalText,
});

export async function addReferenceAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = Reference.safeParse(Object.fromEntries(form));
  if (!parsed.success)
    back(page(hymnId), { erreur: 'Référence invalide : livre et chapitre obligatoires.' });
  const { supabase } = await requireEditor();
  await run(parsed.data.hymn_id, 'Référence ajoutée.', () =>
    supabase.from('bible_references').insert(parsed.data),
  );
}

export async function deleteReferenceAction(form: FormData) {
  const parsed = z.object({ hymn_id: Uuid, reference_id: Uuid }).parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  await run(parsed.hymn_id, 'Référence supprimée.', () =>
    supabase
      .from('bible_references')
      .delete()
      .eq('id', parsed.reference_id)
      .eq('hymn_id', parsed.hymn_id),
  );
}

// --------------------------------------------------------------- relations

const Relation = z.object({
  hymn_id: Uuid,
  relation: RelationType,
  related_label: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[1-9]\d{0,3}(bis|ter)?$/),
  notes: OptionalText,
});

export async function addRelationAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = Relation.safeParse({
    ...Object.fromEntries(form),
    related_label: String(form.get('related_label') ?? '').replace(/\s+/g, ''),
  });
  if (!parsed.success)
    back(page(hymnId), { erreur: 'Numéro du cantique lié invalide (ex. 37 ou 37bis).' });
  const { supabase } = await requireEditor();
  const { data: hymn } = await supabase
    .from('hymns')
    .select('edition_id')
    .eq('id', hymnId)
    .single();
  const { data: related } = await supabase
    .from('hymns')
    .select('id')
    .eq('edition_id', hymn?.edition_id ?? '')
    .eq('number_label', parsed.data.related_label)
    .maybeSingle();
  if (!related)
    back(page(hymnId), { erreur: `Le cantique ${parsed.data.related_label} n’existe pas.` });
  if (related.id === hymnId)
    back(page(hymnId), { erreur: 'Un cantique ne peut pas être lié à lui-même.' });
  await run(hymnId, 'Relation ajoutée.', () =>
    supabase.from('hymn_relations').insert({
      hymn_id: hymnId,
      related_hymn_id: related.id,
      relation: parsed.data.relation,
      notes: parsed.data.notes,
    }),
  );
}

export async function deleteRelationAction(form: FormData) {
  const parsed = z
    .object({ hymn_id: Uuid, related_hymn_id: Uuid, relation: RelationType })
    .parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  await run(parsed.hymn_id, 'Relation supprimée.', () =>
    supabase
      .from('hymn_relations')
      .delete()
      .eq('hymn_id', parsed.hymn_id)
      .eq('related_hymn_id', parsed.related_hymn_id)
      .eq('relation', parsed.relation),
  );
}

// ------------------------------------------------------------------ droits

const Rights = z.object({
  hymn_id: Uuid,
  rights_status: RightsStatus,
  rights_holder: OptionalText,
  license_type: OptionalText,
  valid_until: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .catch(null),
  notes: OptionalText,
});

/** Registre des droits (9.11) : nouvel enregistrement, le plus récent fait foi. */
export async function addRightsAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = Rights.safeParse(Object.fromEntries(form));
  if (!parsed.success) back(page(hymnId), { erreur: 'Enregistrement de droits invalide.' });
  const { supabase } = await requireEditor();
  await run(hymnId, 'Droits enregistrés.', () =>
    supabase.from('rights_records').insert(parsed.data),
  );
}

// ------------------------------------------------------------------ statut

export async function setStatusAction(form: FormData) {
  const parsed = z.object({ id: Uuid, status: PublicationStatus }).parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('set_hymns_status', {
    p_hymn_ids: [parsed.id],
    p_status: parsed.status,
  });
  const result = (data as { ok: boolean; error: string | null }[] | null)?.[0];
  if (error || !result?.ok) {
    back(page(parsed.id), {
      erreur: result?.error ?? errorMessage(error, 'Changement de statut refusé.'),
    });
  }
  revalidatePath('/', 'layout');
  done(parsed.id, 'Statut modifié.');
}

// -------------------------------------------------------- auteurs, thèmes

const PersonRole = z.enum(['author', 'composer', 'translator', 'arranger']);

/** Auteur, compositeur… : personne existante (même nom) réutilisée, sinon créée. */
export async function addPersonAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = z
    .object({ hymn_id: Uuid, full_name: RequiredText, role: PersonRole })
    .safeParse(Object.fromEntries(form));
  if (!parsed.success) back(page(hymnId), { erreur: 'Nom et rôle obligatoires.' });
  const { supabase } = await requireEditor();
  const { data: existing } = await supabase
    .from('people')
    .select('id')
    .ilike('full_name', parsed.data.full_name.replace(/[%_\\]/g, '\\$&'))
    .limit(1);
  let personId = existing?.[0]?.id as string | undefined;
  if (!personId) {
    const { data, error } = await supabase
      .from('people')
      .insert({ full_name: parsed.data.full_name })
      .select('id')
      .single();
    if (error)
      back(page(hymnId), { erreur: errorMessage(error, 'Création de la personne refusée.') });
    personId = data.id;
  }
  await run(hymnId, 'Personne ajoutée.', () =>
    supabase
      .from('hymn_people')
      .insert({ hymn_id: hymnId, person_id: personId, role: parsed.data.role }),
  );
}

export async function deletePersonAction(form: FormData) {
  const parsed = z
    .object({ hymn_id: Uuid, person_id: Uuid, role: PersonRole })
    .parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  await run(parsed.hymn_id, 'Personne retirée.', () =>
    supabase
      .from('hymn_people')
      .delete()
      .eq('hymn_id', parsed.hymn_id)
      .eq('person_id', parsed.person_id)
      .eq('role', parsed.role),
  );
}

/** Thème existant (même nom) réutilisé, sinon créé. */
export async function addThemeAction(form: FormData) {
  const hymnId = String(form.get('hymn_id'));
  const parsed = z
    .object({ hymn_id: Uuid, name: RequiredText })
    .safeParse(Object.fromEntries(form));
  if (!parsed.success) back(page(hymnId), { erreur: 'Nom du thème obligatoire.' });
  const slug = themeSlug(parsed.data.name);
  if (!slug) back(page(hymnId), { erreur: 'Nom du thème invalide.' });
  const { supabase } = await requireEditor();
  const { data: existing } = await supabase.from('themes').select('id').eq('slug', slug).limit(1);
  let themeId = existing?.[0]?.id as string | undefined;
  if (!themeId) {
    const { data, error } = await supabase
      .from('themes')
      .insert({ name: parsed.data.name, slug })
      .select('id')
      .single();
    if (error) back(page(hymnId), { erreur: errorMessage(error, 'Création du thème refusée.') });
    themeId = data.id;
  }
  await run(hymnId, 'Thème ajouté.', () =>
    supabase
      .from('hymn_themes')
      .insert({ hymn_id: hymnId, theme_id: themeId, source: 'editorial' }),
  );
}

export async function deleteThemeAction(form: FormData) {
  const parsed = z.object({ hymn_id: Uuid, theme_id: Uuid }).parse(Object.fromEntries(form));
  const { supabase } = await requireEditor();
  await run(parsed.hymn_id, 'Thème retiré.', () =>
    supabase
      .from('hymn_themes')
      .delete()
      .eq('hymn_id', parsed.hymn_id)
      .eq('theme_id', parsed.theme_id),
  );
}
