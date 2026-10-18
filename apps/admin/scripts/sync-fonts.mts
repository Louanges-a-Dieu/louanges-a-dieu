/**
 * Copie les polices de l'application (source unique : apps/mobile/assets/fonts,
 * licence OFL) dans public/fonts/, pour l'aperçu « comme sur mobile ».
 * Lancé avant `dev` et `build` ; le dossier copié n'est pas versionné.
 */
import { copyFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const admin = resolve(import.meta.dirname, '..');
const fonts = resolve(admin, '../mobile/assets/fonts');
const out = resolve(admin, 'public/fonts');
mkdirSync(out, { recursive: true });
for (const [from, to] of [
  ['CormorantGaramond/CormorantGaramond-VF.ttf', 'cormorant.ttf'],
  ['Literata/Literata-VF.ttf', 'literata.ttf'],
  ['Literata/Literata-Italic-VF.ttf', 'literata-italic.ttf'],
  ['Inter/Inter-VF.ttf', 'inter.ttf'],
]) {
  copyFileSync(resolve(fonts, from!), resolve(out, to!));
}
console.log('Polices copiées dans public/fonts.');
