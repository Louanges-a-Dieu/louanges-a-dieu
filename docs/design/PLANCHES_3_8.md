# Planches 3 à 8 — mise en œuvre

2026-10-21 · Sources : [`planche_3.png`](planche_3.png) (lecture et chant),
[`planche_4.png`](planche_4.png) (favoris, listes, programmes),
[`planche_5.png`](planche_5.png) (projection et télécommande),
[`planche_6.png`](planche_6.png) (chorale, **écartée**),
[`planche_7.png`](planche_7.png) (hors connexion et paramètres),
[`planche_8.png`](planche_8.png) (administration éditoriale).
Fait suite à [`PLANCHE_2.md`](PLANCHE_2.md) ; ses règles restent valables (écrans sans
données masqués, barre du bas inchangée).

## Décisions du propriétaire (2026-10-21)

- **Chorale hors périmètre pour le moment** : planche 6 entière, vue équipe / musiciens (4·14),
  mode chorale (4·15), chant en groupe (3·15).
- Lecture : **toujours une strophe à la fois** (décision du 20/10 maintenue) ; pas d'option
  « Continu » (3·10).
- Inclus : **statistiques anonymes** (compteurs sans identité) et **commentaires notés**,
  modérés dans le back-office.
- Exclus : notifications push (7·11, 8·12), anglais (7·12).
- Partage d'un programme : **lien + image + texte** (pas de PDF ni d'impression).
- Programme : **lieu, description, image** en plus du titre et de la date ; **pas d'heure**.

## Règles appliquées sans arbitrage

- Partitions, accords, tonalités, compositeurs : aucune donnée → écrans et options masqués
  (3·7, 3·8, 5·11, 5·12, 5·13, « Afficher les accords », « Afficher le compositeur »).
- Projection : architecture sans Internet conservée (ADR-013). Pas de Chromecast : les écrans
  sont des navigateurs qui se connectent au téléphone ; la liste « écrans disponibles » montre
  les écrans connectés.
- Le recueil complet est toujours embarqué dans l'app : il n'y a rien à « télécharger » pour
  les paroles. Le téléchargement concerne les enregistrements audio.
- Sauvegarde et restauration de la base (8·14) : assurées par Supabase et la procédure
  `docs/operations` ; pas d'écran.

## Lots

| Lot | Contenu | État |
| --- | ------- | ---- |
| A | Lecture : thème sépia, réglages de lecture, plein écran sur l'appareil avec défilement automatique, cantique suivant, lecture d'une liste ou d'un programme ; audio : vitesse, boucle ; paramètres regroupés (apparence, lecture, audio, confidentialité, aide, à propos) | fait |
| B | Favoris (récents), listes (icône, couleur, description, ajout multiple, cases à cocher), programmes (lieu, description, image, à venir / historique, modèles, options de projection, partage en image) | à faire |
| C | Projection : choix de la projection, apparence (fond clair / sombre / image, numéro, titre, taille), masquer, relancer, mode automatique, transitions, message de fin, écran retour, télécommande tablette | à faire |
| D | Hors connexion (vue d'ensemble, téléchargements audio choisis, place occupée, mode avion), compte | à faire |
| E | Statistiques anonymes et commentaires (base, app, back-office) ; back-office : tableau de bord, thèmes et auteurs, utilisateurs, paramètres de l'app, notes de version | à faire |
