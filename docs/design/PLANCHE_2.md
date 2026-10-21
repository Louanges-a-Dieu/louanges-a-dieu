# Planche 2 — Recherche et consultation : mise en œuvre

2026-10-21 · Source : [`planche_2_recherche_consultation.png`](planche_2_recherche_consultation.png)
(copiée depuis `~/Downloads`). Complète [`UI_ALIGNMENT_PLAN.md`](UI_ALIGNMENT_PLAN.md).

## Décisions du propriétaire (2026-10-21)

- Écrans ou champs **sans données** (thèmes, auteurs/compositeurs, partitions, accords,
  tempo, chorale) : **masqués** ; ils apparaîtront quand la donnée existera.
- Barre du bas **inchangée** : Accueil · Recueil · Favoris · Culte · Plus (pas de « Profil »).
- Partage : texte + **image** (pas de PDF). Pas de lien vers un cantique : le site n'a pas
  de page publique par cantique.
- Mode lecture **sombre** : bouton dans la lecture, mémorisé (`pref.readerTheme`).

## Écran par écran

| N° | Planche                 | État dans l'app                                                                      |
| -- | ----------------------- | ------------------------------------------------------------------------------------ |
| 1  | Accueil                 | Verset (Psaume 92.2, Segond 1910) dans le bandeau. Vignette « Chorale » : masquée.   |
| 2  | Recueil (liste)         | Champ de recherche dans la page ; onglets N° / A–Z. Onglet « Thèmes » : masqué.      |
| 3  | Filtres                 | Masqué (aucun thème, auteur ni compositeur en base).                                  |
| 4  | Recherche               | Suggestions en temps réel, extrait du vers trouvé (existait).                         |
| 5  | Résultats               | Nombre, filtres Tous / Titres / Paroles avec compteurs, tri pertinence/numéro/titre. |
| 6  | Fiche cantique          | Onglets Paroles · Détails · Médias* · Similaires* ; barre Lire · Écouter* · Chanter* · Projeter. |
| 7  | Actions rapides         | Feuille « Actions » (⋮) : lire, écouter*, chanter*, projeter, favori, liste, programme, partager, télécharger*. |
| 8  | Informations            | Onglet Détails : numéro, titre, premier vers, structure, personnes, références, thèmes — seulement si connus. |
| 9  | Lecture (clair)         | Existait ; taille du texte par curseur (bouton « Taille du texte »).                  |
| 10 | Lecture (sombre)        | Bouton clair/sombre dans la lecture.                                                  |
| 11 | Navigation strophes     | Liste des strophes (ordre chanté) + « Aller au refrain » (prochain refrain).          |
| 12 | Détails étendus         | Tempo, tonalité, historique : masqués (pas de données).                               |
| 13 | Médias                  | Onglet Médias : versions audio publiées + karaoké. Partitions, accords : masqués.     |
| 14 | Cantiques similaires    | Relations publiées (même mélodie, variante, bis, lié). Pas de « même thème ».         |
| 15 | Ajouter au culte        | Depuis la fiche : programme, puis position (sous un moment du programme ou à la fin). |
| 16 | Partager                | Image (aperçu : bandeau + premier couplet), texte, copie. WhatsApp/e-mail : partage du système. |

\* seulement si un enregistrement est publié et l'hébergement audio configuré.

## Reste à faire (selon les données)

Saisie des thèmes, auteurs/compositeurs, partitions et tonalités dans le back-office :
les écrans 3, 12, 13 (partitions) et 14 (même thème) s'en serviront.
