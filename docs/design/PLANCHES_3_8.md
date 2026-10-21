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
| B | Favoris (récents), listes (icône, couleur, description, ajout multiple, cases à cocher, lecture à la suite, partage), programmes (lieu, description, image, à venir / historique, modèles, options de projection, lecture et plein écran, partage lien / image / texte) ; migration 0022, base locale v2, page publique avec lieu et description | fait |
| C | Projection : choix depuis la fiche (écran, plein écran, lecture, programme, partage), mode d’affichage (fond sombre / clair / photo, numéro, taille), masquer, refrain, relancer, cantique suivant, défilement automatique, transitions et message de fin (options du programme), écran retour (`?role=retour`), mise en page tablette ; le serveur local sert les photos de l’app | fait |
| D | Hors connexion : vue d’ensemble (recueil, enregistrements sur l’appareil, place occupée), « Sans Internet, vous pouvez », gestionnaire d’écoute hors connexion (choix, favoris, avancement, annulation, suppression, libérer l’espace) ; compte : favoris, listes, programmes, synchronisation | fait |
| E | Statistiques anonymes (compteurs par jour et par cantique, désactivables dans l’app et le back-office), avis notés modérés (onglet « Avis » de la fiche, page « Avis » du back-office) ; back-office : tableau de bord enrichi (consultations, comptes, programmes, avis à modérer, activité), Statistiques (7 / 30 / 90 jours, classement, export CSV), Thèmes, Paramètres de l’app ; politique de confidentialité mise à jour ; migrations 0023–0025 | fait |

## Écarts restants (non faits, à décider)

- Planche 8 : liste complète des utilisateurs (8·9 ; la page Équipe gère les rôles), notifications
  et annonces (8·12, exclues), sauvegardes (8·14, voir `docs/operations/backup-restore.md`),
  modèles de programmes proposés par l’équipe (8·8), filtre des cantiques par thème dans la liste.
- Planche 7 : couleur principale au choix (7·8) non retenue : l’identité et les contrastes vérifiés
  reposent sur l’or ; langue (7·12) exclue.
- Planche 5 : diffusion différente par écran (5·15) limitée à l’écran retour ; Chromecast écarté
  (projection sans Internet, ADR-013).
- Partitions, accords, tonalités, compositeurs : écrans masqués tant que les données n’existent pas.
- Recette sur appareils réels (Android, iPhone, vidéoprojecteur) à faire par le propriétaire.
