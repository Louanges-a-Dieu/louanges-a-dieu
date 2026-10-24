# Registre des assets graphiques

Chaque asset embarqué dans une application doit figurer ici avec sa source et sa licence.

## Polices (SIL Open Font License 1.1)

| Police | Usage | Source |
|---|---|---|
| Cormorant Garamond (variable, romain) | partout : numéros, titres | github.com/google/fonts `ofl/cormorantgaramond` |
| Literata (variable, romain + italique) | partout : paroles (italique : refrains) | github.com/google/fonts `ofl/literata` |
| Inter (variable, romain) | partout : interface | github.com/google/fonts `ofl/inter` |

Fichiers dans `apps/mobile/assets/fonts/`, chacun accompagné de son `OFL.txt` (téléchargées le
2026-10-17, branche `main` du dépôt google/fonts). Space Grotesk, Manrope et IBM Plex Mono
(direction « clair net », 2026-10-19) ont été retirées le 2026-10-20 avec la direction « Le
recueil vivant ». Licences affichées dans l'écran « Licences »
de l'app. Aucune des polices de l'app n'a le caractère U+202F (espace fine insécable, avant
« ! ? ; : ») : le système le dessine avec sa police de repli, sans effet visible.

Les polices de la couverture imprimée (Baskerville, Brush Script MT) sont sous licence
propriétaire et **ne sont pas embarquées**.

## Photos (licence Pexels)

Licence Pexels (https://www.pexels.com/license/) : usage gratuit, y compris commercial,
modification autorisée, attribution non obligatoire ; interdits : revendre la photo telle
quelle, laisser croire à un soutien des personnes ou marques représentées. Les photos ci-dessous
ne montrent ni personne ni marque.

| Fichier (`apps/mobile/assets/images/`) | Usage | URL source | Auteur | Traitement | Date d'ajout |
|---|---|---|---|---|---|
| `hero_wheat_sunset.jpg` | carte héro de l'accueil | https://www.pexels.com/photo/close-up-photo-of-wheat-1600139/ | Tetyana Kovyrina (pexels.com/@kovyrina) | recadrée 3:2 au tiers haut, retournée horizontalement, 1440×960, JPEG q74 | 2026-10-20 |
| `banner_wheat_ears.jpg` | bandeau de la fiche cantique | https://www.pexels.com/photo/wheat-field-2275222/ | rehan verma (pexels.com/@rehanverma) | redimensionnée 1440×960, JPEG q72 | 2026-10-20 |

## Identité

| Asset | Source | Remarques |
|---|---|---|
| Épi de blé | à vectoriser depuis la couverture (Affinity) | à fournir par le propriétaire |
| Icône de l'app, écran de démarrage, icônes du site et du back-office | image `app_android_louanges_icone.png` (trois épis dorés dans un cercle, fond blanc, 1254×1254) **fournie par le propriétaire** le 2026-10-23 ; copie : `apps/mobile/assets/branding/icone_source.png` | dérivés produits par `tools/branding/icones.py` (recadrage, fond blanc pur, zone sûre Android), puis `flutter_launcher_icons` et `flutter_native_splash` (`apps/mobile/*.yaml`) ; a remplacé le 2026-10-24 le monogramme « L » provisoire de la PWA de projection et les icônes par défaut de Flutter et Next.js |
