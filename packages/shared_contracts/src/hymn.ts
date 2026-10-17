import { z } from 'zod';

/**
 * Contrat d'un cantique PUBLIÉ, tel que distribué aux clients (release de
 * catalogue, ADR-004/005).
 *
 * Règle éditoriale absolue : une information inconnue vaut `null` (ou une
 * liste vide). Une chaîne vide ou composée d'espaces est refusée, pour qu'aucun
 * client ne puisse afficher une valeur « fantôme ».
 */

/** Chaîne non vide après suppression des espaces (y compris insécables). */
const nonBlank = z.string().refine((s) => s.trim().length > 0, {
  message: 'chaîne vide interdite : utiliser null pour une valeur inconnue',
});

export const NumberSuffix = z.enum(['bis', 'ter']);

/** Libellé imprimé : « 37 », « 37bis ». */
export const NumberLabel = z.string().regex(/^[1-9]\d{0,3}(bis|ter)?$/, {
  message: 'libellé de numéro invalide (attendu : 37 ou 37bis)',
});

export const SectionType = z.enum(['verse', 'refrain', 'bridge', 'intro', 'outro', 'note']);

/** Répétition d'une ligne : « (bis) » → 2, « (ter) » → 3, « (4x) » → 4. */
export const LineRepeat = z.object({
  count: z.int().min(2).max(12),
  /** Marqueur tel qu'imprimé dans la source, conservé pour la traçabilité. */
  marker: nonBlank,
});

export const HymnLine = z.object({
  /** Texte verbatim, marqueur de répétition inclus (ADR-008). */
  text: nonBlank,
  repeat: LineRepeat.nullable(),
});

export const HymnSection = z.object({
  id: z.uuid(),
  type: SectionType,
  /** Numéro de couplet ; null pour un refrain ou si non numéroté. */
  number: z.int().positive().nullable(),
  order: z.int().nonnegative(),
  lines: z.array(HymnLine).min(1),
});

export const BibleReference = z.object({
  /** Référence telle qu'imprimée (« Psaumes 47 »). */
  displayText: nonBlank,
  book: nonBlank.nullable(),
  chapterStart: z.int().positive().nullable(),
  verseStart: z.int().positive().nullable(),
  chapterEnd: z.int().positive().nullable(),
  verseEnd: z.int().positive().nullable(),
});

export const RelationType = z.enum(['same_melody', 'variant', 'bis_of', 'related']);

export const HymnRelation = z.object({
  type: RelationType,
  relatedHymnId: z.uuid(),
});

export const PersonRole = z.enum(['author', 'composer', 'translator', 'arranger']);

export const HymnPerson = z.object({
  role: PersonRole,
  fullName: nonBlank,
});

export const PublishedHymn = z
  .object({
    id: z.uuid(),
    numberLabel: NumberLabel,
    numberNumeric: z.int().positive().max(9999),
    numberSuffix: NumberSuffix.nullable(),
    title: nonBlank,
    openingLine: nonBlank.nullable(),
    languageCode: z.string().regex(/^[a-z]{2,3}$/),
    sections: z.array(HymnSection).min(1),
    bibleReferences: z.array(BibleReference),
    relations: z.array(HymnRelation),
    people: z.array(HymnPerson),
    themes: z.array(nonBlank),
  })
  .superRefine((hymn, ctx) => {
    const expected = `${hymn.numberNumeric}${hymn.numberSuffix ?? ''}`;
    if (hymn.numberLabel !== expected) {
      ctx.addIssue({
        code: 'custom',
        path: ['numberLabel'],
        message: `incohérent avec numberNumeric/numberSuffix (attendu « ${expected} »)`,
      });
    }
    const orders = hymn.sections.map((s) => s.order);
    if (new Set(orders).size !== orders.length) {
      ctx.addIssue({ code: 'custom', path: ['sections'], message: 'ordre de section dupliqué' });
    }
    if (hymn.relations.some((r) => r.relatedHymnId === hymn.id)) {
      ctx.addIssue({
        code: 'custom',
        path: ['relations'],
        message: 'un cantique ne peut pas être en relation avec lui-même',
      });
    }
  });

export type PublishedHymn = z.infer<typeof PublishedHymn>;
export type HymnSection = z.infer<typeof HymnSection>;
export type HymnLine = z.infer<typeof HymnLine>;
