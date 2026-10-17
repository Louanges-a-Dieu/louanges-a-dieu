import { z } from 'zod';

import { NumberLabel, NumberSuffix } from './hymn.ts';

/**
 * Contrat du catalogue BROUILLON produit par l'import du recueil source
 * (packages/content_tools) et chargé dans la copie de travail éditoriale.
 *
 * Tout ce qui est ici est une DÉTECTION AUTOMATIQUE, soumise à validation
 * humaine (IMPORT → DRAFT → REVIEW → PUBLISHED). Aucune métadonnée n'est
 * inventée : auteurs, thèmes, tonalités sont absents du contrat.
 */

const nonBlank = z.string().refine((s) => s.trim().length > 0, {
  message: 'chaîne vide interdite : utiliser null pour une valeur inconnue',
});

export const IssueSeverity = z.enum(['info', 'warning', 'blocking']);
export const IssueCode = z.string().regex(/^[A-Z]-[0-9]{2}$/);

export const DraftSection = z.object({
  type: z.enum(['verse', 'refrain']),
  order: z.int().nonnegative(),
  /** Vers séparés par « \n », texte verbatim (seuls les espaces de fin de vers sont retirés). */
  text: nonBlank,
});

export const DraftBibleReference = z.object({
  /** Tel qu'imprimé, sans les tirets d'encadrement. */
  displayText: nonBlank,
  book: nonBlank,
  chapterStart: z.int().positive(),
  verseStart: z.int().positive().nullable(),
  chapterEnd: z.int().positive().nullable(),
  verseEnd: z.int().positive().nullable(),
});

export const DraftRelation = z.object({
  type: z.literal('bis_of'),
  relatedNumberLabel: NumberLabel,
});

export const DraftHymn = z
  .object({
    numberLabel: NumberLabel,
    numberNumeric: z.int().positive().max(9999),
    numberSuffix: NumberSuffix.nullable(),
    title: nonBlank,
    openingLine: nonBlank.nullable(),
    sourceParagraphStart: z.int().nonnegative(),
    sourceParagraphEnd: z.int().nonnegative(),
    sections: z.array(DraftSection).min(1),
    bibleReferences: z.array(DraftBibleReference),
    relations: z.array(DraftRelation),
  })
  .superRefine((hymn, ctx) => {
    const expected = `${hymn.numberNumeric}${hymn.numberSuffix ?? ''}`;
    if (hymn.numberLabel !== expected) {
      ctx.addIssue({
        code: 'custom',
        path: ['numberLabel'],
        message: `incohérent (attendu « ${expected} »)`,
      });
    }
    if (hymn.sourceParagraphEnd < hymn.sourceParagraphStart) {
      ctx.addIssue({ code: 'custom', path: ['sourceParagraphEnd'], message: 'plage inversée' });
    }
  });

export const DraftIssue = z.object({
  code: IssueCode,
  severity: IssueSeverity,
  /** Cantique concerné, ou null pour une anomalie du document entier. */
  numberLabel: NumberLabel.nullable(),
  message: nonBlank,
  details: z.record(z.string(), z.unknown()),
});

export const CatalogDraft = z.object({
  format: z.literal('lad.catalog-draft'),
  version: z.literal(1),
  source: z.object({
    filename: nonBlank,
    sha256: z.string().regex(/^[0-9a-f]{64}$/),
    parserVersion: nonBlank,
  }),
  edition: z.object({
    name: nonBlank,
    editionNumber: z.int().positive().nullable(),
  }),
  hymns: z.array(DraftHymn),
  issues: z.array(DraftIssue),
});

export type CatalogDraft = z.infer<typeof CatalogDraft>;
export type DraftHymn = z.infer<typeof DraftHymn>;
export type DraftSection = z.infer<typeof DraftSection>;
export type DraftBibleReference = z.infer<typeof DraftBibleReference>;
export type DraftIssue = z.infer<typeof DraftIssue>;
