# Référence UX/UI — Louanges à Dieu
Version 1.0 · Document de référence pour l’alignement visuel de l’application existante

## 1. Objectif et règle de priorité

Ce document décrit la direction UX/UI cible à partir du prototype visuel interactif « Louanges à Dieu ».

**Mission : aligner l’application déjà développée sur Claude Code sur cette direction visuelle, sans réécrire l’application ni casser ses fonctionnalités existantes.**

Le prototype est une référence de présentation, de hiérarchie visuelle, de navigation et de micro-interactions. Ce n’est pas une spécification backend. Les exemples de cantiques, paroles, numéros et références qui apparaissent dans le prototype sont fictifs/illustratifs : ne jamais les importer dans le catalogue de production.

### Règles impératives
1. Commencer par inspecter le dépôt, le framework, les routes, les composants, le système de styles et les fonctionnalités existantes.
2. Conserver le framework, l’architecture, la gestion d’état, le backend et les conventions déjà en place, sauf blocage technique démontré.
3. Ne pas remplacer les vraies données par les exemples du prototype.
4. Ne pas supprimer ou dégrader une fonctionnalité existante pour obtenir une ressemblance visuelle.
5. Réutiliser et améliorer les composants existants avant d’en créer de nouveaux.
6. Procéder écran par écran, avec tests et captures de contrôle.
7. En cas de conflit entre le prototype et une exigence fonctionnelle déjà implémentée, conserver le comportement fonctionnel et adapter le design autour.
8. Ne pas ajouter de fausses fonctions : audio, synchronisation, projection temps réel ou mode hors ligne ne doivent pas être présentés comme fonctionnels s’ils ne le sont pas réellement.

## 2. Intention de design

### Concept
**« Le recueil vivant »** : une expérience qui combine la noblesse d’un livre de cantiques imprimé, une interface éditoriale contemporaine et un mode de lecture immersif.

### Sensations à transmettre
- Recueil précieux, spirituel, intemporel.
- Chaleur du papier, lumière dorée, simplicité.
- Grande lisibilité des paroles.
- Élégance sans surcharge décorative.
- Modernité discrète, jamais une interface générique de tableau de bord.
- L’application doit sembler appartenir à l’univers graphique de la couverture du recueil « Louanges à Dieu ».

### Signature visuelle
- Fonds ivoire/crème.
- Brun profond pour les textes.
- Or patiné pour les accents, états actifs et actions primaires.
- Formes arrondies modérées.
- Typographie éditoriale serif pour les titres, sans-serif pour l’interface.
- Blé / épi comme motif secondaire, utilisé avec parcimonie.
- Sur l’écran de lecture et de projection : mode sombre immersif optionnel ou contextuel.

## 3. Design tokens

Créer ou mettre à jour les tokens dans le système de styles existant. Ne pas disperser les valeurs de couleur dans les composants.

### Palette
| Token sémantique | Valeur indicative | Utilisation |
|---|---|---|
| `color.canvas` | `#F7F0E4` | Fond général ivoire |
| `color.surface` | `#FFFAF1` | Cartes, panneaux, champs |
| `color.surface-warm` | `#F0E5D2` | Navigation latérale, zones secondaires |
| `color.text` | `#392A1B` | Texte principal brun profond |
| `color.text-muted` | `#89765D` | Texte secondaire |
| `color.gold` | `#A86D13` | Accent, action principale, état actif |
| `color.gold-light` | `#D7A84F` | Filets et accents discrets |
| `color.gold-pale` | `#E8D1A6` | Cartes mises en avant |
| `color.border` | `#E8D9BF` | Bordures fines |
| `color.dark` | `#171F1F` | Fond du mode immersif |
| `color.dark-surface` | `#222B29` | Surface sombre |

Contraste : vérifier la lisibilité réelle, en particulier le texte doré sur fond clair. Ne pas utiliser l’or clair pour de longs textes.

### Typographie
- Titres de page et titres de cantique : serif élégante (Georgia ou serif de marque déjà disponible).
- Titres d’écran principal : 24–28 px desktop, 21–24 px mobile.
- Titres de cartes : 16–21 px selon la hiérarchie.
- Corps de l’interface : sans-serif lisible, généralement 13–15 px.
- Métadonnées / libellés : 10–12 px, capitales espacées avec parcimonie.
- Paroles : serif confortable, 18–20 px dans la fiche, 22–28 px dans le mode lecture, avec interligne généreux.
- Ne jamais imposer une taille de texte fixe qui empêche l’agrandissement.

### Espacements, rayons, profondeur
- Échelle d’espacement cohérente : 4, 8, 12, 16, 20, 24, 32, 40, 48 px.
- Cartes : rayons de 12–18 px.
- Grandes zones éditoriales : rayon de 20–24 px.
- Boutons : rayon de 10–14 px ou pilule pour filtres.
- Bordures fines plutôt que grosses ombres.
- Ombres douces, rares et peu contrastées.
- Utiliser de l’espace vide pour rendre la lecture plus calme.

## 4. Structure de navigation

### Desktop / tablette large
Préférer une navigation latérale fixe ou persistante si cela correspond au modèle de navigation actuel :
- Marque « LOUANGES À DIEU » avec motif épi discret.
- Accueil.
- Recueil.
- Rechercher.
- Favoris.
- Programme du culte.
- Projection.
- Hors connexion / téléchargements, uniquement si cette fonction existe.

La zone de marque est séparée de la navigation par un filet fin. En bas, une courte citation biblique peut apparaître si le produit en possède une validée.

### Mobile
- Ne pas transposer la barre latérale en un menu encombrant.
- Utiliser la navigation mobile déjà présente ; si elle n’existe pas, privilégier une barre inférieure compacte de 4 à 5 destinations principales.
- Garder la recherche facile d’accès.
- Respecter les zones de sécurité iOS et Android.
- Les libellés doivent rester visibles et compréhensibles ; ne pas s’appuyer uniquement sur les icônes.

### Navigation et état actif
- Fond légèrement doré pâle ou accent doré pour l’élément actif.
- Texte brun ou or foncé.
- Transitions courtes et discrètes.
- Retour cohérent depuis une fiche cantique.
- Les boutons doivent toujours mener à une vraie action ou être explicitement désactivés avec une explication.

## 5. Spécification des écrans

### A. Accueil
**Objectif :** inspirer immédiatement, puis donner accès au recueil en un geste.

Ordre de priorité :
1. En-tête sobre : signature « Le recueil vivant » et titre de page.
2. Grande carte héroïque sombre et chaude, inspirée de la lumière du coucher de soleil et des champs de blé.
3. Message éditorial : « Que chaque chant devienne une prière. » (texte de direction artistique, modifiable selon la communication officielle).
4. Barre de recherche immédiatement visible sous la carte.
5. Carte « Cantique du jour » avec numéro mis en évidence, titre, extrait et bouton d’ouverture.
6. Quatre raccourcis maximum : Explorer le recueil, Favoris, Préparer un culte, Projection (uniquement si ces fonctions existent).
7. Éventuellement « Reprendre votre lecture » si l’application conserve réellement l’historique.

Le héro ne doit pas repousser la recherche trop bas sur mobile. Limiter les éléments décoratifs et conserver un contraste élevé.

### B. Recueil
- Titre « Le recueil », sous-titre discret.
- Filtres simples : par numéro, A–Z, catégories si les données le permettent.
- Recherche locale accessible.
- Liste de cantiques en lignes/cartes fines, pas une grille surchargée.
- Chaque ligne : numéro dans un petit bloc ivoire-or, titre serif, extrait en texte secondaire, favori si cette action existe.
- Préserver fidèlement les numéros spéciaux (ex. suffixes bis) et le tri éditorial prévu.
- Ne jamais afficher les titres ou extraits fictifs du prototype en production.

### C. Recherche
- Titre éditorial court et clair, par exemple « La bonne parole, retrouvée. »
- Champ de recherche proéminent, avec exemple discret.
- Résultats dans le même composant de liste que le recueil.
- Afficher un extrait pertinent et distinguer le numéro du titre.
- États à concevoir : vide initial, chargement, aucun résultat, erreur, résultat hors ligne.
- Les filtres « Titres », « Paroles » ou « Références » ne doivent être affichés que si la recherche les prend réellement en charge.
- Conserver les règles de recherche actuelles ; l’alignement visuel ne doit pas modifier la logique métier.

### D. Fiche cantique
- Grande bannière chaude brun-or, mais de hauteur raisonnable sur mobile.
- Numéro clairement lisible, titre principal et première ligne/extrait.
- Favori en haut à droite si la fonction existe.
- Actions secondaires dans un groupe : Lire, Écouter, Projeter, Partager. Afficher uniquement les fonctions réellement disponibles ; les autres doivent être masquées ou indiquées comme à venir, sans fausse interactivité.
- Paroles sur une surface ivoire distincte.
- Distinguer visuellement strophes et refrain avec libellés sobres et un filet or discret.
- Références bibliques, auteurs et autres métadonnées uniquement si présents et vérifiés.
- Les paroles doivent être la partie la plus lisible de la page.
- Ne pas inventer de refrain ou de strophe pour compléter visuellement la fiche.

### E. Mode lecture
- Surface calme, centrée, largeur de lecture limitée.
- Numéro discret en haut, titre serif, strophe très lisible.
- Contrôles Précédent / Suivant bien espacés.
- Taille de texte réglable.
- Option de mode sombre si cohérente avec l’application.
- Réduire les boutons et métadonnées pendant la lecture.
- Préserver la structure réelle des strophes, refrains et répétitions du dataset.
- Sur mobile, éviter le défilement horizontal et garder les contrôles accessibles.

### F. Favoris
- Titre « Vos chants précieux » ou équivalent.
- Compteur si exact.
- Liste identique à celle du recueil pour garder la cohérence.
- État vide chaleureux avec une explication et un lien vers le recueil.
- Le clic sur un cœur met à jour immédiatement l’état visuel et les données.

### G. Programme du culte
- Présenter le programme comme un conducteur clair, pas comme un formulaire administratif.
- Nom/date/heure si ces champs existent.
- Sections de programme (ex. Ouverture, Louange, Adoration) seulement si elles sont configurables ou réellement utilisées.
- Chaque item : numéro, titre, section et action de suppression/réorganisation.
- Ajouter un cantique avec un champ simple.
- Actions : projeter et partager uniquement si elles sont opérationnelles.
- Prévoir les états brouillon, vide, enregistré, erreur et absence de réseau.
- Ne pas inventer de programme ou de contenu réel.

### H. Projection
- Surface sombre immersive : vert-noir / charbon, avec lumière subtile.
- Paroles très grandes, centrées et aérées.
- Métadonnées minimales : numéro et titre discrets.
- Contrôles précédent/suivant réservés au mode de prévisualisation ou au conducteur ; les masquer sur l’écran réellement projeté si nécessaire.
- Plein écran lorsque pris en charge.
- Le prototype visuel ne prouve pas que la synchronisation temps réel est implémentée. Ne pas simuler une fonctionnalité inexistante.
- Vérifier la lisibilité à distance et les contrastes en salle.

### I. Hors connexion / téléchargements
- Présenter clairement ce qui est réellement disponible hors connexion.
- Indiquer le statut exact : téléchargé, en cours, en attente, erreur.
- Barre de progression seulement si la progression réelle est connue.
- Ne pas afficher « Disponible » ou une barre complète fictive.
- Si la fonctionnalité n’existe pas encore, afficher un état honnête ou ne pas afficher l’entrée dans la navigation principale.

### J. Back-office / écrans non couverts par le prototype
Le prototype ne spécifie pas le design détaillé du back-office. Conserver les outils administratifs existants et appliquer les tokens, typographies, champs, tableaux, boutons, états et bordures du même système visuel. Ne pas transformer un back-office de gestion en interface décorative : priorité à l’efficacité et à la densité lisible.

## 6. Composants UI à standardiser

Créer ou consolider des composants réutilisables, selon les conventions du projet :
- `AppShell` / navigation responsive.
- `PageHeader`.
- `HeroCard`.
- `SearchField`.
- `HymnListItem`.
- `HymnNumberBadge`.
- `FavoriteButton`.
- `PrimaryButton` et `SecondaryButton`.
- `SectionHeading`.
- `HymnLyrics` avec strophe/refrain.
- `EmptyState`.
- `LoadingState`.
- `ErrorState`.
- `OfflineStatus`.
- `ProgramItem`.
- `ProjectionCanvas`.

Ne pas imposer ces noms si le codebase possède déjà des équivalents. L’objectif est la cohérence et la réutilisation, pas le renommage gratuit.

## 7. Micro-interactions

- Survol desktop très léger : bordure dorée ou élévation subtile.
- Appui mobile avec retour visuel immédiat.
- Favori : transition courte et état accessible.
- Navigation : transition discrète, sans animation lourde.
- Recherche : conserver le texte et les résultats lors d’un retour si le comportement actuel le permet.
- Boutons désactivés : apparence distincte et raison compréhensible.
- Toasts / notifications : courts, non bloquants et cohérents avec la palette.
- Respecter `prefers-reduced-motion` si le framework le permet.

## 8. Responsive design

### Mobile (priorité)
- Une seule colonne.
- Marges latérales autour de 16 px.
- Hero raccourci ; recherche et action principale visibles rapidement.
- Cartes compactes, sans perte de lisibilité.
- Navigation basse si appropriée.
- Cibles tactiles idéalement d’au moins 44 × 44 px.

### Tablette
- Une ou deux colonnes selon le contenu.
- Conserver l’espace de lecture et éviter les lignes de texte trop longues.
- Navigation latérale uniquement si elle reste confortable.

### Desktop
- Largeur maximale du contenu contrôlée.
- Navigation latérale possible.
- Les listes et panneaux peuvent utiliser une grille à deux colonnes pour les écrans de gestion, mais le recueil doit rester facile à parcourir.

## 9. Accessibilité et robustesse
- Contraste conforme aux bonnes pratiques WCAG.
- Icônes accompagnées de libellés ou de noms accessibles.
- Navigation clavier sur le web.
- Focus visible.
- Labels explicites pour les champs.
- Taille de texte ajustable.
- États non communiqués uniquement par la couleur.
- Textes longs et numéros bis correctement gérés.
- Tests sur petits écrans et grands caractères.
- Pas d’animation indispensable à la compréhension.

## 10. Données et contenus : interdictions

Les libellés et paroles du prototype servent à illustrer le rendu. Ils ne sont pas une source éditoriale.

- Ne pas recopier les exemples du prototype dans la base réelle.
- Ne pas substituer les données existantes à une liste fictive.
- Ne pas compléter des paroles manquantes.
- Ne pas inventer des références bibliques, auteurs ou tonalités.
- Ne pas afficher un extrait tronqué comme si c’était la totalité du cantique.
- Ne pas utiliser de fausse progression de téléchargement ou de fausse synchronisation.
- Utiliser le catalogue existant et les champs réellement disponibles.

## 11. Plan d’alignement conseillé

### Étape 1 — Audit visuel
- Identifier toutes les routes/pages.
- Repérer les composants et tokens existants.
- Capturer les écrans actuels en mobile et desktop si possible.
- Établir une matrice : écran existant → changement visuel → risque fonctionnel.

### Étape 2 — Fondations
- Définir les tokens.
- Harmoniser les polices et la hiérarchie.
- Mettre à jour le shell et la navigation responsive.
- Consolider boutons, champs, cartes, badges et états.

### Étape 3 — Écrans prioritaires
1. Accueil.
2. Recueil et recherche.
3. Fiche cantique.
4. Mode lecture.
5. Favoris.
6. Programme de culte.
7. Projection.
8. Hors connexion.
9. Back-office et écrans secondaires.

### Étape 4 — Contrôle
- Comparer les captures avant/après.
- Tester tous les parcours existants.
- Vérifier les données et états vides.
- Exécuter lint, tests et build.
- Corriger les régressions avant de passer à l’écran suivant.

## 12. Définition de « terminé »

L’alignement UI est terminé lorsque :
- la palette, les typographies, les rayons et espacements sont cohérents ;
- l’accueil possède une composition éditoriale forte sans gêner l’accès à la recherche ;
- les listes de cantiques ont une présentation cohérente ;
- les paroles sont très lisibles et leur structure est préservée ;
- la navigation est adaptée au mobile et au desktop ;
- les états vide/chargement/erreur/hors ligne sont honnêtes et soignés ;
- les fonctionnalités existantes passent les tests de non-régression ;
- aucune donnée fictive du prototype n’a été injectée dans le catalogue ;
- les captures d’écran montrent un résultat proche de cette direction artistique.

## 13. Référence visuelle

Prototype HTML interactif de référence : `louanges_a_dieu_prototype_interactif.html`

Si le fichier est disponible dans le dépôt, l’ouvrir localement dans un navigateur. S’il ne l’est pas, demander au propriétaire de le placer à la racine du projet ou dans `docs/design/`. Ne jamais inventer son chemin ni considérer que Claude Code a accès à un fichier uniquement parce qu’un lien existe dans une conversation.
