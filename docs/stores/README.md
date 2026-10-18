# Publication sur les stores (tâche 10.7)

Comptes **individuels** au nom du propriétaire (Q-17). Identifiant : `org.louangesadieu.app`.
Toutes les réponses ci-dessous découlent du fonctionnement réel de l'application et de la
politique de confidentialité (`https://<site>/confidentialite`) : toute évolution de l'une
impose de mettre à jour les autres.

## Fiche (commune)

| Champ | Contenu proposé |
|---|---|
| Nom | Louanges à Dieu |
| Sous-titre (Apple, 30 car.) | Recueil de cantiques |
| Description courte (Google, 80 car.) | Le recueil Louanges à Dieu : lire, chercher et projeter les cantiques, hors ligne. |
| Catégorie | Apple : Référence (secondaire : Livres) · Google : Livres et références |
| Langue | Français |
| Prix | Gratuit, sans achat intégré, sans publicité |
| Site / assistance | `https://<site>` · `louangesaDieu04@gmail.com` |
| Politique de confidentialité | `https://<site>/confidentialite` |
| Suppression de compte (Google) | `https://<site>/suppression-compte` |

**Description longue** (à relire) :

> Le recueil Louanges à Dieu dans votre poche, fidèle au livre imprimé.
>
> • Tous les cantiques, disponibles **sans connexion** une fois l'application installée.
> • Recherche instantanée par numéro, titre ou paroles, sans se soucier des accents.
> • Mode lecture en grands caractères, écran maintenu allumé, refrain répété au besoin.
> • Favoris, listes et programmes de culte, synchronisés si vous créez un compte (facultatif).
> • Partage d'un programme par un simple lien.
> • **Projection** sur l'ordinateur relié au vidéoprojecteur, pilotée depuis le téléphone, même
>   sans Internet.
>
> Sans publicité, sans pistage. Aucune donnée n'est collectée si vous n'utilisez pas de compte.

## Classification

- Apple : questionnaire d'âge → aucune catégorie de contenu sensible → **4+**.
- Google (IARC) : application de référence, pas de contenu généré visible publiquement
  (les programmes partagés ne sont visibles que par lien), pas d'achats → **Tout public**.
- Public cible (Google) : 13 ans et plus (création de compte possible) ; ne cible pas les enfants.

## Google Play — « Sécurité des données »

| Question | Réponse |
|---|---|
| Collecte ou partage de données ? | Oui (collecte) ; **aucun partage** avec des tiers à leurs propres fins |
| Chiffrement en transit | Oui (HTTPS) |
| Suppression à la demande | Oui : dans l'application et via `/suppression-compte` |
| Informations personnelles → Adresse e-mail | Collectée, **facultative** (compte), finalité : gestion du compte |
| Activité dans l'application → Autre contenu généré par l'utilisateur (listes, programmes, favoris) | Collecté, facultatif, finalité : fonctionnalités de l'application |
| Informations et performances de l'appli → Journaux de plantage, Diagnostics | Collectés (si Sentry est activé), finalité : analyse et correction ; non liés à l'identité |
| Localisation, contacts, photos, identifiants publicitaires, etc. | Non collectés |

## Apple — « Confidentialité de l'app »

| Type de données | Collecté | Lié à l'identité | Pistage | Finalité |
|---|---|---|---|---|
| Coordonnées → Adresse e-mail | Oui (compte facultatif) | Oui | Non | Fonctionnalités de l'app |
| Contenu utilisateur → Autre (listes, programmes, favoris) | Oui (compte) | Oui | Non | Fonctionnalités de l'app |
| Diagnostics → Données de plantage | Oui (si Sentry activé) | **Non** | Non | Fonctionnalités de l'app |
| Tout le reste | Non | — | — | — |

« Pistage » : **non** (aucune donnée combinée avec celles de tiers, aucune publicité).

## Exigences vérifiées dans l'application

- [x] Utilisable **sans compte** (Apple 5.1.1 : pas de connexion imposée).
- [x] **Suppression du compte dans l'application** (Plus → Mon compte → Supprimer mon compte),
      effective immédiatement (migration 0013, test réel).
- [x] Lien vers la politique de confidentialité dans l'application (Plus → Confidentialité).
- [x] Pas de connexion par un service tiers (Sign in with Apple non requis).
- [x] iOS : texte d'usage du réseau local (projection) ; Android : autorisation `INTERNET`.
- [ ] Notes pour l'examen : l'application fonctionne sans compte ; pour tester le compte,
      l'examinateur peut se connecter avec **sa propre adresse** (code reçu par e-mail).
      Expliquer la projection : « Plus » n'est pas nécessaire, ouvrir un cantique → Projeter.

## Visuels à produire (propriétaire, avec l'épi vectorisé)

| Élément | Apple | Google |
|---|---|---|
| Icône | 1024 × 1024, sans transparence | 512 × 512 ; icône adaptative (avant-plan + fond) |
| Écran de démarrage | storyboard (fond blanc + épi) | `flutter_native_splash` ou thème Android 12 |
| Captures | iPhone 6,9" et 6,5" ; iPad 13" | téléphone ; tablette 7" et 10" |
| Bannière | — | 1024 × 500 |

Captures suggérées : accueil, recherche « 37bis », fiche avec refrain, mode lecture, programme
de culte, pilote de projection, écran projeté.
