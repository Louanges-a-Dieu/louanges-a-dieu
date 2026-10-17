import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { SCHEMAS, toJsonSchemaText } from './schemas.ts';

const generatedDir = resolve(dirname(fileURLToPath(import.meta.url)), '../generated');

function main(command: string | undefined): number {
  if (command !== 'generate' && command !== 'check') {
    console.error('Usage : node src/cli.ts <generate|check>');
    return 2;
  }
  let stale = 0;
  mkdirSync(generatedDir, { recursive: true });
  for (const [file, schema] of Object.entries(SCHEMAS)) {
    const path = resolve(generatedDir, file);
    const content = toJsonSchemaText(schema);
    if (command === 'generate') {
      writeFileSync(path, content);
      console.log(`écrit : generated/${file}`);
      continue;
    }
    let current: string | null;
    try {
      current = readFileSync(path, 'utf8');
    } catch {
      current = null;
    }
    if (current !== content) {
      console.error(`JSON Schema absent ou périmé : generated/${file}`);
      stale++;
    }
  }
  if (command === 'check') {
    if (stale > 0) {
      console.error('Lancer : pnpm --filter @lad/shared-contracts generate');
      return 1;
    }
    console.log('JSON Schemas à jour.');
  }
  return 0;
}

process.exitCode = main(process.argv[2]);
