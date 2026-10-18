'use server';

import { CatalogDraft } from '@lad/shared-contracts';
import { revalidatePath } from 'next/cache';

import { requireEditor } from '@/lib/auth';
import { errorMessage } from '@/lib/redirect';

export interface ImportSummary {
  editionCreated: boolean;
  batchId: string | null;
  inserted: string[];
  unchanged: string[];
  changed: string[];
  missingFromSource: string[];
  issuesCreated: number;
}

export interface ImportReport {
  fileName?: string;
  dryRun?: boolean;
  errors?: string[];
  edition?: string;
  issuesBySeverity?: Record<string, number>;
  summary?: ImportSummary;
}

const MAX_BYTES = 9 * 1024 * 1024;

/**
 * Import d'un catalogue brouillon (9.9) : validation par le contrat Zod, puis
 * import_catalog_draft avec la session de l'éditeur (RLS, journal). La
 * simulation donne le diff de réimport sans rien écrire.
 */
export async function importAction(_: ImportReport, form: FormData): Promise<ImportReport> {
  const text = String(form.get('draft') ?? '');
  const fileName = String(form.get('fileName') ?? '') || undefined;
  const dryRun = form.get('mode') !== 'import';
  if (!text) return { fileName, errors: ['Choisissez un fichier catalog.draft.json.'] };
  if (text.length > MAX_BYTES)
    return { fileName, errors: ['Fichier trop volumineux (9 Mo au plus).'] };

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return { fileName, errors: ['Ce fichier n’est pas un JSON valide.'] };
  }
  const parsed = CatalogDraft.safeParse(json);
  if (!parsed.success) {
    return {
      fileName,
      errors: parsed.error.issues
        .slice(0, 15)
        .map((issue) => `${issue.path.join('.') || 'fichier'} : ${issue.message}`),
    };
  }

  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('import_catalog_draft', {
    p_draft: parsed.data,
    p_dry_run: dryRun,
  });
  if (error) return { fileName, errors: [errorMessage(error, 'Import refusé.')] };
  if (!dryRun) revalidatePath('/', 'layout');

  const issuesBySeverity: Record<string, number> = {};
  for (const issue of parsed.data.issues) {
    issuesBySeverity[issue.severity] = (issuesBySeverity[issue.severity] ?? 0) + 1;
  }
  return {
    fileName,
    dryRun,
    edition: `${parsed.data.edition.name}${parsed.data.edition.editionNumber ? ` (${parsed.data.edition.editionNumber})` : ''}`,
    issuesBySeverity,
    summary: data as ImportSummary,
  };
}
