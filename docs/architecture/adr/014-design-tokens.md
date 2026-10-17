# ADR-014 — Design tokens source unique

**Décision.** `packages/design_tokens/tokens.json` est la seule source des couleurs,
typographies, espacements, rayons, durées. Des générateurs produisent `tokens.g.dart` (Flutter)
et `tokens.css` (web). Un test vérifie les contrastes. Direction visuelle : blanc, pur, épuré
(Q-11) ; polices OFL Cormorant Garamond, Literata, Inter.

**Conséquences.** Aucune valeur de style en dur dans le code des features.
