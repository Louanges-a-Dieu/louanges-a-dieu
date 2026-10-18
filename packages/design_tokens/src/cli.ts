import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { checkContrast } from './contrast.ts';
import { generateCss, generateDart } from './generate.ts';
import { loadTokens } from './tokens.ts';

const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repoDir = resolve(packageDir, '../..');

const outputs = (css: string, dart: string): Array<[string, string]> => [
  [resolve(packageDir, 'generated/tokens.css'), css],
  [resolve(repoDir, 'apps/mobile/lib/core/design_system/tokens.g.dart'), dart],
  // Servi par le serveur de projection de l'app (écran projeté, Phase 8).
  [resolve(repoDir, 'apps/mobile/assets/projection/tokens.css'), css],
];

function main(command: string | undefined): number {
  const tokens = loadTokens(resolve(packageDir, 'tokens.json'));

  const violations = checkContrast(tokens);
  if (violations.length > 0) {
    for (const v of violations) {
      console.error(
        `Contraste insuffisant [${v.theme}] ${v.foreground} sur ${v.background} : ${v.ratio} < ${v.min}`,
      );
    }
    return 1;
  }

  const files = outputs(generateCss(tokens), generateDart(tokens));

  if (command === 'generate') {
    for (const [path, content] of files) {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, content);
      console.log(`écrit : ${path.slice(repoDir.length + 1)}`);
    }
    return 0;
  }

  if (command === 'check') {
    let stale = 0;
    for (const [path, content] of files) {
      let current: string | null = null;
      try {
        current = readFileSync(path, 'utf8');
      } catch {
        current = null;
      }
      if (current !== content) {
        console.error(`Fichier généré absent ou périmé : ${path.slice(repoDir.length + 1)}`);
        stale++;
      }
    }
    if (stale > 0) {
      console.error('Lancer : pnpm tokens');
      return 1;
    }
    console.log('Tokens valides, contrastes conformes, fichiers générés à jour.');
    return 0;
  }

  console.error('Usage : node src/cli.ts <generate|check>');
  return 2;
}

process.exitCode = main(process.argv[2]);
