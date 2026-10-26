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

export const MediaType = z.enum([
  'melody',
  'accompaniment',
  'choir',
  'soprano',
  'alto',
  'tenor',
  'bass',
  'instrumental',
  'other',
]);

/**
 * Clé RELATIVE d'un fichier audio dans le stockage des médias (Backblaze B2,
 * ADR-016) : jamais une URL. Les clients la joignent à l'adresse de base de
 * leur configuration. MP3 ou AAC, lisibles sur iOS, Android et le web.
 */
export const StorageKey = z
  .string()
  .regex(/^[A-Za-z0-9][A-Za-z0-9._/-]*\.(mp3|m4a|aac)$/, {
    message: 'clé de stockage invalide (attendu : chemin relatif .mp3, .m4a ou .aac)',
  })
  .refine((key) => !key.includes('..') && !key.includes('//'), {
    message: 'clé de stockage invalide (« .. » ou « // » interdits)',
  });

/** Passage d'un enregistrement correspondant à une section des paroles. */
export const AudioSegment = z
  .object({
    /** Section chantée ; null si le passage n'en suit aucune (introduction…). */
    sectionId: z.uuid().nullable(),
    /**
     * Vers chanté (0 = premier vers de la section) pour une piste synchronisée
     * ligne par ligne (karaoké) ; null ou absent : la section entière.
     */
    lineIndex: z.int().nonnegative().nullable().optional(),
    startMs: z.int().nonnegative(),
    endMs: z.int().positive(),
    order: z.int().nonnegative(),
  })
  .refine((s) => s.endMs > s.startMs, { message: 'fin avant le début du passage' })
  .refine((s) => s.lineIndex == null || s.sectionId !== null, {
    message: 'une ligne appartient à une section',
  });

export const AudioTrack = z.object({
  id: z.uuid(),
  mediaType: MediaType,
  storageKey: StorageKey,
  durationSeconds: z.number().positive().nullable(),
  segments: z.array(AudioSegment),
});

/** Identifiant d'une vidéo YouTube (11 caractères) : jamais une adresse. */
export const YoutubeId = z.string().regex(/^[A-Za-z0-9_-]{11}$/, {
  message: 'identifiant YouTube invalide (11 caractères attendus)',
});

/** Vidéo d'un cantique, hébergée sur YouTube et lue dans l'app (migration 0026). */
export const HymnVideo = z.object({
  id: z.uuid(),
  mediaType: MediaType,
  youtubeId: YoutubeId,
  title: nonBlank.max(300).nullable(),
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
    /** Enregistrements diffusables ; clé absente si le cantique n'en a aucun. */
    audio: z.array(AudioTrack).min(1).optional(),
    /** Vidéos diffusables ; clé absente si le cantique n'en a aucune. */
    videos: z.array(HymnVideo).min(1).optional(),
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
    const lineCounts = new Map(hymn.sections.map((s) => [s.id, s.lines.length]));
    hymn.audio?.forEach((track, t) =>
      track.segments.forEach((segment, i) => {
        if (segment.sectionId === null) return;
        const lines = lineCounts.get(segment.sectionId);
        if (lines === undefined) {
          ctx.addIssue({
            code: 'custom',
            path: ['audio', t, 'segments', i, 'sectionId'],
            message: 'section inconnue de ce cantique',
          });
        } else if (segment.lineIndex != null && segment.lineIndex >= lines) {
          ctx.addIssue({
            code: 'custom',
            path: ['audio', t, 'segments', i, 'lineIndex'],
            message: 'ligne inexistante dans la section',
          });
        }
      }),
    );
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
export type AudioTrack = z.infer<typeof AudioTrack>;
export type AudioSegment = z.infer<typeof AudioSegment>;
