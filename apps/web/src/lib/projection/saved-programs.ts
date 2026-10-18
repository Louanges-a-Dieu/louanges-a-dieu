import type { ProgramEntry, PublishedHymn } from '@lad/shared-contracts';

import type { SharedProgram } from '../shared-program';
import type { KeyValueStore } from './store';

/** Programme préparé pour la projection hors ligne (depuis son lien de partage). */
export interface SavedProgram {
  id: string;
  title: string;
  serviceDate: string | null;
  savedAt: string;
  items: Array<{ hymnId: string | null; label: string | null }>;
}

const KEY = 'programs';

export function toSavedProgram(program: SharedProgram, now = new Date()): SavedProgram {
  return {
    id: `${program.title}|${program.serviceDate ?? ''}`,
    title: program.title,
    serviceDate: program.serviceDate,
    savedAt: now.toISOString(),
    items: program.items.map((item) => ({
      hymnId: item.hymn && !item.hymn.unavailable ? item.hymn.id : null,
      label: item.hymn ? null : item.label,
    })),
  };
}

export async function listSavedPrograms(store: KeyValueStore): Promise<SavedProgram[]> {
  return (await store.get<SavedProgram[]>(KEY)) ?? [];
}

/** Enregistre (ou remplace, même titre et même date) un programme. */
export async function saveProgram(store: KeyValueStore, program: SavedProgram): Promise<void> {
  const others = (await listSavedPrograms(store)).filter((p) => p.id !== program.id);
  await store.set(KEY, [program, ...others]);
}

export async function removeProgram(store: KeyValueStore, id: string): Promise<void> {
  await store.set(
    KEY,
    (await listSavedPrograms(store)).filter((p) => p.id !== id),
  );
}

/** Éléments projetables : cantiques retrouvés dans le recueil local, moments libres. */
export function programEntries(
  program: SavedProgram,
  hymnsById: Map<string, PublishedHymn>,
): ProgramEntry[] {
  return program.items.flatMap((item): ProgramEntry[] => {
    if (item.hymnId) return [{ hymn: hymnsById.get(item.hymnId) ?? null }];
    return item.label ? [{ label: item.label }] : [];
  });
}
