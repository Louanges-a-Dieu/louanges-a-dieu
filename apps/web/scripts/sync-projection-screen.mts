/**
 * Copie l'écran projeté de l'app (source unique : apps/mobile/assets/projection)
 * dans public/projection-ecran/, pour le mode « ordinateur seul » (Phase 8.4).
 * Lancé avant `dev` et `build` ; le dossier copié n'est pas versionné.
 */
import { copyFileSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const web = resolve(import.meta.dirname, '..');
const mobile = resolve(web, '../mobile');
const out = resolve(web, 'public/projection-ecran');

const files: Array<[string, string]> = [
  ['assets/projection/screen.html', 'screen.html'],
  ['assets/projection/screen.css', 'screen.css'],
  ['assets/projection/screen.js', 'screen.js'],
  ['assets/projection/tokens.css', 'tokens.css'],
  ['assets/fonts/CormorantGaramond/CormorantGaramond-VF.ttf', 'fonts/cormorant.ttf'],
  ['assets/fonts/Literata/Literata-VF.ttf', 'fonts/literata.ttf'],
  ['assets/fonts/Literata/Literata-Italic-VF.ttf', 'fonts/literata-italic.ttf'],
];

rmSync(out, { recursive: true, force: true });
for (const [from, to] of files) {
  const target = resolve(out, to);
  mkdirSync(dirname(target), { recursive: true });
  copyFileSync(resolve(mobile, from), target);
}
console.log(`Écran projeté copié dans public/projection-ecran (${files.length} fichiers).`);
