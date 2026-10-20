# ADR-014 — Design tokens source unique

**Décision.** `packages/design_tokens/tokens.json` est la seule source des couleurs,
typographies, espacements, rayons, durées. Des générateurs produisent `tokens.g.dart` (Flutter)
et `tokens.css` (web). Un test vérifie les contrastes. Direction visuelle : « Le recueil vivant »
(ivoire, brun, or patiné ; 2026-10-20, remplace « blanc pur » Q-11) ; polices OFL Cormorant
Garamond, Literata, Inter. Un bloc facultatif `app` peut surcharger des valeurs pour l'app seule.

**Conséquences.** Aucune valeur de style en dur dans le code des features.
