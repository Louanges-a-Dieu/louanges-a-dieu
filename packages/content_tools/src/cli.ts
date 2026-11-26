#!/usr/bin/env node
/**
 * content-tools — import du recueil source.
 *
 *   content-tools import <recueil.docx> --edition-name "<nom>" [--edition-number 6] [--out <dossier>]
 *   content-tools load <catalog.draft.json> --as <uuid-éditeur> [--dry-run]
 *   content-tools export-snapshot --config <apps/mobile/config/env.json> [--snapshot-out <fichier.gz>]
 *   content-tools corrections <tableur.xlsx>… --as <uuid-éditeur> [--edition <uuid>] [--dry-run]
 *
 * Produit dans le dossier de sortie (par défaut ./content/out, hors Git) :
 *   catalog.draft.json   catalogue brouillon (contrat CatalogDraft)
 *   report.html          rapport d'anomalies pour la relecture éditoriale
 * Code de sortie non nul si le contrôle de fidélité échoue.
 *
 * « load » charge le catalogue brouillon dans la copie de travail (base de
 * développement), en tant que l'éditeur indiqué : tout entre en brouillon,
 * rien d'existant n'est écrasé (voir src/load.ts).
 *
 * « corrections » rapproche les tableurs de relecture (Q-04, A-13) du texte
 * actuel de la copie de travail et met les propositions encore utiles dans la
 * file éditoriale (anomalies A-13, écran « Corrections » du back-office). Rien
 * n'est appliqué : chaque proposition est validée ou refusée par un éditeur.
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { CatalogDraft } from '@lad/shared-contracts';
import pg from 'pg';

import { connectionConfig } from './db.ts';
import { exportSnapshot } from './export-snapshot.ts';
import { loadDraft } from './load.ts';
import { parseCorrections } from './corrections.ts';
import { importDocx } from './pipeline.ts';
import { renderReport } from './report.ts';
import { loadCorrections } from './suggestions.ts';
import { readXlsx } from './xlsx.ts';

const USAGE = [
  'Usage : content-tools import <recueil.docx> --edition-name "<nom>" [--edition-number <n>] [--out <dossier>]',
  '        content-tools load <catalog.draft.json> --as <uuid-éditeur> [--dry-run]',
  '        content-tools export-snapshot --config <apps/mobile/config/env.json> [--snapshot-out <fichier.gz>]',
  '        content-tools corrections <tableur.xlsx>… --as <uuid-éditeur> [--edition <uuid>] [--dry-run]',
].join('\n');

const repoRoot = resolve(import.meta.dirname, '../../..');

async function load(file: string, actor: string, dryRun: boolean): Promise<number> {
  const draft = CatalogDraft.parse(JSON.parse(readFileSync(file, 'utf8')));
  const client = new pg.Client(connectionConfig(repoRoot));
  await client.connect();
  try {
    const s = await loadDraft(client, draft, actor, { dryRun });
    console.log(`Édition             : ${s.editionId}${s.editionCreated ? ' (créée)' : ''}`);
    console.log(`Nouveaux (brouillon): ${s.inserted.length}`);
    console.log(`Inchangés           : ${s.unchanged.length}`);
    console.log(
      `Modifiés à arbitrer : ${s.changed.length}${s.changed.length ? ` (${s.changed.slice(0, 20).join(', ')})` : ''}`,
    );
    console.log(`Absents de la source: ${s.missingFromSource.length}`);
    console.log(`Anomalies créées    : ${s.issuesCreated}`);
    console.log(
      dryRun
        ? 'Simulation : rien n’a été enregistré.'
        : `Lot d’import        : ${s.batchId ?? 'aucun (rien de nouveau)'}`,
    );
    return 0;
  } finally {
    await client.end();
  }
}

async function corrections(
  paths: string[],
  actor: string,
  editionId: string | undefined,
  dryRun: boolean,
): Promise<number> {
  const files = paths.map((path) => ({ name: basename(path), bytes: readFileSync(path) }));
  const rows = files.flatMap((f) => parseCorrections(readXlsx(f.bytes), f.name));
  const client = new pg.Client(connectionConfig(repoRoot));
  await client.connect();
  try {
    const s = await loadCorrections(client, { files, rows }, actor, { editionId, dryRun });
    console.log(`Propositions lues        : ${rows.length} (${files.length} fichier(s))`);
    console.log(`Déjà dans le texte       : ${s.stats.applied}`);
    console.log(`Refusées dans le tableur : ${s.stats.declined}`);
    console.log(`À appliquer              : ${s.stats.pending}`);
    console.log(`À arbitrer (retouchées)  : ${s.stats.conflict}`);
    console.log(`Introuvables             : ${s.stats.not_found}`);
    console.log(`Déjà dans la file        : ${s.alreadyKnown}`);
    console.log(
      dryRun
        ? `Simulation : ${s.new} proposition(s) entreraient dans la file ; rien n’a été enregistré.`
        : `Ajoutées à la file (A-13): ${s.created}${s.batchId ? ` — lot ${s.batchId}` : ''}`,
    );
    return 0;
  } finally {
    await client.end();
  }
}

async function main(argv: string[]): Promise<number> {
  const { positionals, values } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      'edition-name': { type: 'string' },
      'edition-number': { type: 'string' },
      out: { type: 'string', default: 'content/out' },
      as: { type: 'string' },
      edition: { type: 'string' },
      'dry-run': { type: 'boolean', default: false },
      config: { type: 'string' },
      'snapshot-out': {
        type: 'string',
        default: resolve(repoRoot, 'apps/mobile/assets/catalog/catalog_snapshot.json.gz'),
      },
    },
  });

  const [command, file] = positionals;
  if (command === 'corrections') {
    const paths = positionals.slice(1);
    if (paths.length === 0 || !values.as) {
      console.error(USAGE);
      return 2;
    }
    return corrections(paths, values.as, values.edition, values['dry-run']);
  }
  if (command === 'export-snapshot') {
    if (!values.config) {
      console.error(USAGE);
      return 2;
    }
    const r = await exportSnapshot(values.config, values['snapshot-out']);
    console.log(
      `Release ${r.releaseId} : ${r.hymnCount} cantiques conformes au contrat, ${Math.round(r.bytes / 1024)} Ko → ${values['snapshot-out']}`,
    );
    return 0;
  }
  if (command === 'load') {
    if (!file || !values.as) {
      console.error(USAGE);
      return 2;
    }
    return load(file, values.as, values['dry-run']);
  }
  if (command !== 'import' || !file || !values['edition-name']) {
    console.error(USAGE);
    return 2;
  }

  const editionNumber = values['edition-number'] ? Number(values['edition-number']) : null;
  if (editionNumber !== null && !(Number.isInteger(editionNumber) && editionNumber > 0)) {
    console.error('--edition-number doit être un entier positif');
    return 2;
  }

  const result = importDocx(readFileSync(file), {
    filename: basename(file),
    editionName: values['edition-name'],
    editionNumber,
  });

  const out = resolve(values.out);
  mkdirSync(out, { recursive: true });
  writeFileSync(resolve(out, 'catalog.draft.json'), `${JSON.stringify(result.draft, null, 2)}\n`);
  writeFileSync(resolve(out, 'report.html'), renderReport(result));

  const { stats, fidelity } = result;
  console.log(`Cantiques           : ${stats.hymns} (dont ${stats.bisRelations} « bis »)`);
  console.log(`Sections / vers     : ${stats.sections} / ${stats.lines}`);
  console.log(`Références          : ${stats.bibleReferences}`);
  console.log(
    `Anomalies           : ${stats.issuesBySeverity.blocking} bloquante(s), ${stats.issuesBySeverity.warning} à vérifier, ${stats.issuesBySeverity.info} info`,
  );
  const faithful = fidelity.paragraphCountMatches && fidelity.mismatches.length === 0;
  console.log(
    `Fidélité            : ${faithful ? 'conforme' : `NON CONFORME (${fidelity.mismatches.length} écart(s))`}`,
  );
  console.log(`Sorties             : ${out}/catalog.draft.json, ${out}/report.html`);
  return faithful ? 0 : 1;
}

process.exitCode = await main(process.argv.slice(2));
