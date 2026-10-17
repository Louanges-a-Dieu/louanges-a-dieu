import { z } from 'zod';

import { PublishedHymn } from './hymn.ts';

/** Contrats exportés en JSON Schema (consommés par les tests Dart). */
export const SCHEMAS = {
  'published-hymn.schema.json': PublishedHymn,
} as const;

export function toJsonSchemaText(schema: z.ZodType): string {
  return `${JSON.stringify(z.toJSONSchema(schema, { target: 'draft-2020-12' }), null, 2)}\n`;
}
