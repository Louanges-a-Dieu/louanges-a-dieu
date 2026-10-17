import { createHash } from 'node:crypto';

import { CatalogDraft } from '@lad/shared-contracts';

import { documentIssues } from './anomalies.ts';
import { extractParagraphs, readDocumentXml } from './docx.ts';
import { checkFidelity, type FidelityReport } from './fidelity.ts';
import { structure } from './structure.ts';

/** Version du parseur, enregistrée avec chaque import (provenance). */
export const PARSER_VERSION = '1.0.0';

export interface ImportOptions {
  filename: string;
  editionName: string;
  editionNumber: number | null;
}

export interface ImportResult {
  draft: CatalogDraft;
  fidelity: FidelityReport;
  stats: {
    paragraphs: number;
    hymns: number;
    sections: number;
    lines: number;
    refrains: number;
    bibleReferences: number;
    bisRelations: number;
    issuesBySeverity: Record<string, number>;
  };
}

/** .docx → catalogue brouillon validé par le contrat + contrôle de fidélité. */
export function importDocx(docx: Uint8Array, options: ImportOptions): ImportResult {
  const xml = readDocumentXml(docx);
  const paragraphs = extractParagraphs(xml);
  const result = structure(paragraphs);
  const bodyEnd = paragraphs.findIndex((p) => p.text.trim() === 'Index des cantiques');

  const issues = [
    ...result.issues,
    ...documentIssues(result.hymns, result.indexEntries, result.leftIndentRegime),
  ];

  // Un cantique sans vers ne peut pas entrer dans le catalogue (A-15, bloquant).
  const hymns = result.hymns.filter((h) => h.sections.length > 0);

  const draft = CatalogDraft.parse({
    format: 'lad.catalog-draft',
    version: 1,
    source: {
      filename: options.filename,
      sha256: createHash('sha256').update(docx).digest('hex'),
      parserVersion: PARSER_VERSION,
    },
    edition: { name: options.editionName, editionNumber: options.editionNumber },
    hymns,
    issues,
  });

  const fidelity = checkFidelity(
    xml,
    paragraphs.length,
    result.hymns,
    bodyEnd === -1 ? paragraphs.length : bodyEnd,
  );

  const issuesBySeverity: Record<string, number> = { info: 0, warning: 0, blocking: 0 };
  for (const i of issues) issuesBySeverity[i.severity] = (issuesBySeverity[i.severity] ?? 0) + 1;

  return {
    draft,
    fidelity,
    stats: {
      paragraphs: paragraphs.length,
      hymns: hymns.length,
      sections: hymns.reduce((n, h) => n + h.sections.length, 0),
      lines: hymns.reduce(
        (n, h) => n + h.sections.reduce((m, s) => m + s.text.split('\n').length, 0),
        0,
      ),
      refrains: hymns.filter((h) => h.sections.some((s) => s.type === 'refrain')).length,
      bibleReferences: hymns.reduce((n, h) => n + h.bibleReferences.length, 0),
      bisRelations: hymns.reduce((n, h) => n + h.relations.length, 0),
      issuesBySeverity,
    },
  };
}
