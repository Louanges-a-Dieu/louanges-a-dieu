import { z } from 'zod';

import { CatalogDraft } from './catalog-draft.ts';
import { PublishedHymn } from './hymn.ts';

/** Contrats exportés en JSON Schema (consommés par les tests Dart). */
export const SCHEMAS = {
  'published-hymn.schema.json': PublishedHymn,
  'catalog-draft.schema.json': CatalogDraft,
} as const;

export function toJsonSchemaText(schema: z.ZodType): string {
  return `${JSON.stringify(z.toJSONSchema(schema, { target: 'draft-2020-12' }), null, 2)}\n`;
}
