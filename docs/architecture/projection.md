# Projection (Phase 8)

## Vue d'ensemble

```
Téléphone pilote (app)                         Ordinateur du projecteur
┌──────────────────────────┐   Wi-Fi local    ┌────────────────────────────┐
│ Pilote (écran Flutter)   │   ou point       │ Navigateur                 │
│  ProjectionState         │   d'accès du     │  http://<ip>:47100/s/<code>/│
│        │ publish()       │   téléphone      │  screen.html / .css / .js  │
│ ProjectionServer (dart:io)│◄───────────────►│  WebSocket …/ws (lecture)  │
└──────────────────────────┘   sans Internet  └────────────────────────────┘
```

- **Diapositives** (8.1) : `apps/mobile/lib/core/projection/slides.dart` et
  `packages/shared_contracts/src/projection.ts`, vérifiés par les mêmes fixtures
  (`packages/shared_contracts/fixtures/projection`). Titre, puis une diapositive par section ;
  refrain répété après chaque couplet (Q-07, désactivable dans le pilote) ; section de plus de
  6 vers découpée en parties équilibrées ; sections « note » non projetées ; texte tel qu'imprimé.
- **Serveur** : `projection_server.dart`. Page, styles (tokens générés, thème `projection`),
  script et polices servis depuis les ressources de l'app ; en-têtes `no-store`, `nosniff`,
  `no-referrer`, CSP `default-src 'self'`.
- **Écran projeté** (8.2) : `apps/mobile/assets/projection/`. Plein écran au clic (ou touche F),
  texte ajusté à l'écran, curseur masqué, reconnexion automatique (0,5 s → 5 s), dernière
  diapositive conservée (y compris après rechargement de la page).
- **Pilote** (8.3) : `features/projection/projection_screen.dart`, depuis la fiche d'un cantique
  ou un programme (bouton « Projeter »). Aperçu, diapositive suivante, précédente/suivante,
  liste de toutes les diapositives (saut direct), écran noir, connexion par adresse et code QR,
  écran du téléphone maintenu allumé, confirmation avant d'arrêter si un écran est connecté.

## Protocole (serveur → écran)

```json
{ "type": "state", "v": 1, "index": 3, "count": 12, "blank": false,
  "slide": { "kind": "lyrics", "numberLabel": "37bis", "sectionType": "refrain",
             "sectionNumber": null, "part": 1, "parts": 1, "lines": ["…"] } }
{ "type": "end" }
```

`slide.kind` vaut `title` (`numberLabel`, `title`), `lyrics` ou `section` (`label`, moment libre
d'un programme). L'écran n'envoie rien ; tout message reçu par le serveur est ignoré.

## Liste de contrôle sur appareils réels (propriétaire, avant la Phase 10)

À faire avec un téléphone Android, un iPhone et l'ordinateur habituel du projecteur.

1. **Point d'accès** : activer le point d'accès du téléphone, y relier l'ordinateur, couper les
   données mobiles. Ouvrir un cantique → « Projeter » → « Connecter un écran » → taper
   l'adresse dans le navigateur de l'ordinateur. Attendu : la page s'affiche, « 1 écran
   connecté » sur le téléphone.
2. **iOS, première fois** : accepter l'autorisation « réseau local ». La refuser une fois pour
   vérifier le message, puis la réactiver (Réglages → Louanges à Dieu → Réseau local).
3. **Suivante / Précédente / Écran noir** : l'écran change en moins d'une demi-seconde, sans
   rechargement.
4. **Coupure** : couper puis rétablir le Wi-Fi de l'ordinateur ; puis mettre l'app en
   arrière-plan 30 s et revenir. Attendu : la dernière diapositive reste affichée, puis
   l'écran se reconnecte seul.
5. **Wi-Fi de l'église** : refaire l'essai 1 sur le Wi-Fi de l'église (certains réseaux « invités »
   isolent les appareils entre eux ; dans ce cas, utiliser le point d'accès du téléphone).
6. **Durée** : projeter 1 h 30 ; vérifier que le téléphone ne se met pas en veille et noter la
   consommation de batterie.

Consigner les résultats (modèles, versions, réseau) dans ADR-013.
