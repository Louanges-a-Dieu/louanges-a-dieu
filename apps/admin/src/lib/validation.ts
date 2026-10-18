import { z } from 'zod';

/** Chemin de retour interne uniquement (pas de redirection vers un autre site). */
export const ReturnPath = z
  .string()
  .regex(/^\/(?![/\\])[^\s]*$/)
  .catch('/');

export const Uuid = z.uuid();
export const PublicationStatus = z.enum(['draft', 'review', 'published', 'archived']);
export const RightsStatus = z.enum([
  'unknown',
  'pending',
  'cleared',
  'restricted',
  'public_domain',
]);
export const SectionType = z.enum(['verse', 'refrain', 'bridge', 'intro', 'outro', 'note']);
export const RelationType = z.enum(['same_melody', 'variant', 'bis_of', 'related']);
export const IssueStatus = z.enum(['open', 'resolved', 'ignored']);

/** Texte facultatif : vide → null (jamais de valeur fictive, règle éditoriale). */
export const OptionalText = z
  .string()
  .transform((v) => v.trim())
  .transform((v) => (v === '' ? null : v))
  .nullable()
  .catch(null);

/** Entier facultatif : vide → null. */
export const OptionalInt = z.preprocess(
  (v) => (v === '' || v === null || v === undefined ? null : Number(v)),
  z.int().positive().nullable(),
);

export const RequiredText = z
  .string()
  .transform((v) => v.trim())
  .pipe(z.string().min(1, 'Champ obligatoire'));
