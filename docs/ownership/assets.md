# Registre des assets graphiques

Chaque asset embarqué dans une application doit figurer ici avec sa source et sa licence.

## Polices (SIL Open Font License 1.1)

| Police | Usage | Source |
|---|---|---|
| Space Grotesk (variable, romain) | app : interface, titres | github.com/google/fonts `ofl/spacegrotesk` |
| Manrope (variable, romain) | app : paroles | github.com/google/fonts `ofl/manrope` |
| IBM Plex Mono (Regular, Medium, SemiBold) | app : numéros, intitulés techniques | github.com/google/fonts `ofl/ibmplexmono` |
| Cormorant Garamond (variable, romain) | site, back-office, écran projeté : numéros, titres | github.com/google/fonts `ofl/cormorantgaramond` |
| Literata (variable, romain + italique) | site, back-office, écran projeté : paroles | github.com/google/fonts `ofl/literata` |
| Inter (variable, romain) | site, back-office, écran projeté : interface | github.com/google/fonts `ofl/inter` |

Fichiers dans `apps/mobile/assets/fonts/`, chacun accompagné de son `OFL.txt` (Cormorant,
Literata, Inter téléchargées le 2026-10-17 ; Space Grotesk, Manrope, IBM Plex Mono le
2026-10-19, branche `main` du dépôt google/fonts). Licences affichées dans l'écran « Licences »
de l'app. Aucune des polices de l'app n'a le caractère U+202F (espace fine insécable, avant
« ! ? ; : ») : le système le dessine avec sa police de repli, sans effet visible.

Les polices de la couverture imprimée (Baskerville, Brush Script MT) sont sous licence
propriétaire et **ne sont pas embarquées**.

## Photos (licence Pexels)

| Fichier | Usage | URL source | Auteur | Date d'ajout |
|---|---|---|---|---|
| — | — | — | — | — |

## Identité

| Asset | Source | Remarques |
|---|---|---|
| Épi de blé | à vectoriser depuis la couverture (Affinity) | à fournir par le propriétaire |
| Icône **provisoire** de la PWA de projection (`apps/web/public/icons/icon-192.png`, `icon-512.png`) | monogramme « L » en Cormorant Garamond (OFL), créé pour le projet le 2026-10-18 | à remplacer par l'épi dès qu'il est fourni |
