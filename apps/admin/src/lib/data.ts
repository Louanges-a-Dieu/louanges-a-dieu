import type { Supabase } from './supabase/server';

export interface Edition {
  id: string;
  name: string;
  edition_number: number | null;
}

/** Éditions, la plus récemment publiée d'abord (puis la plus récente). */
export async function listEditions(supabase: Supabase): Promise<Edition[]> {
  const [{ data: editions }, { data: releases }] = await Promise.all([
    supabase.from('editions').select('id, name, edition_number, created_at').order('created_at', {
      ascending: false,
    }),
    supabase.from('catalog_releases').select('edition_id, id').order('id', { ascending: false }),
  ]);
  const rank = new Map<string, number>();
  for (const r of releases ?? []) if (!rank.has(r.edition_id)) rank.set(r.edition_id, r.id);
  return (editions ?? [])
    .map((e) => ({ id: e.id, name: e.name, edition_number: e.edition_number }))
    .sort((a, b) => (rank.get(b.id) ?? 0) - (rank.get(a.id) ?? 0));
}

/** Paramètre d'adresse unique (les tableaux sont ignorés). */
export function param(value: string | string[] | undefined): string | undefined {
  return typeof value === 'string' && value !== '' ? value : undefined;
}
