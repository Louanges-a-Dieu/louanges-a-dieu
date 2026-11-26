import { z } from 'zod';

/**
 * Propositions de correction des tableurs de relecture (Q-04, A-13) : lecture
 * des détails enregistrés par `public.import_corrections` (migration 0027).
 */

export const SuggestionKind = z.enum(['pending', 'conflict', 'not_found']);
export type SuggestionKind = z.infer<typeof SuggestionKind>;

const Passage = z.object({
  unit: z.enum(['title', 'opening_line', 'section']),
  sectionId: z.string().nullable(),
  offset: z.number(),
  current: z.string(),
  replacement: z.string().nullable(),
  context: z.string().catch(''),
});
export type SuggestionPassage = z.infer<typeof Passage>;

const text = z.string().nullable().optional().catch(null);

export const CorrectionDetails = z.object({
  key: z.string(),
  suggestion: SuggestionKind,
  passages: z.array(Passage),
  source: z.object({
    file: text,
    sheet: text,
    row: z.number().nullable().optional().catch(null),
    number: text,
    title: text,
    original: text,
    proposed: text,
    problem: text,
    confidence: text,
    comment: text,
  }),
  applied: z
    .array(z.object({ unit: z.string(), before: z.string(), after: z.string() }))
    .optional()
    .catch(undefined),
});
export type CorrectionDetails = z.infer<typeof CorrectionDetails>;

export const KIND_LABELS: Record<SuggestionKind, string> = {
  pending: 'À appliquer',
  conflict: 'À arbitrer',
  not_found: 'Introuvable',
};

export const KIND_HINTS: Record<SuggestionKind, string> = {
  pending: 'Le passage fautif est toujours dans le texte : la correction est prête.',
  conflict: 'Le passage a été retouché depuis la relecture : saisissez le texte voulu, ou refusez.',
  not_found: 'Aucun passage correspondant dans le recueil : à corriger à la main si besoin.',
};

export const UNIT_LABELS: Record<SuggestionPassage['unit'], string> = {
  title: 'Titre',
  opening_line: 'Premier vers (listes)',
  section: 'Texte',
};

/** Ordre d'affichage : à appliquer, à arbitrer, introuvables. */
export const KIND_ORDER: SuggestionKind[] = ['pending', 'conflict', 'not_found'];

/** Détails d'une anomalie A-13, ou null s'ils ne sont pas au format attendu. */
export function parseCorrection(details: unknown): CorrectionDetails | null {
  const parsed = CorrectionDetails.safeParse(details);
  return parsed.success ? parsed.data : null;
}

/** Contexte découpé autour du passage, pour le surligner : [avant, passage, après]. */
export function highlight(context: string, passage: string): [string, string, string] {
  const at = context.indexOf(passage);
  if (!context || at < 0) return ['', passage, ''];
  return [context.slice(0, at), passage, context.slice(at + passage.length)];
}

/** Texte saisi dans le formulaire : fins de ligne du navigateur (CRLF) ramenées à LF. */
export function normalizeReplacement(value: string): string {
  return value.replace(/\r\n?/g, '\n');
}
