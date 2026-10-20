# Plan d'alignement UI — « Le recueil vivant »

Version 0.3 · 2026-10-20 · Phases 1 à 4 faites (audit, fondations, écrans, recette). Reste : enregistrements à déposer (Backblaze), essais sur appareils réels.
Demandes du propriétaire du 2026-10-20 : photos Pexels là où le prototype montre une image ;
créer simplement les fonctions que le prototype montre et que l'app n'a pas (§3 bis).

Sources :

- Référence : [`REFERENCE_UX_UI_LOUANGES_A_DIEU.md`](REFERENCE_UX_UI_LOUANGES_A_DIEU.md)
- Prototype : [`louanges_a_dieu_prototype_interactif.html`](louanges_a_dieu_prototype_interactif.html)
  (copiés depuis `~/Downloads` le 2026-10-20 ; `docs/` est exclu de Prettier et d'aucun import)
- Projet : `README.md`, `IMPLEMENTATION_PLAN.md` (§6 arbitrages, §15 design system),
  `docs/architecture/adr/014-design-tokens.md`

---

## 1. Inventaire technique

### 1.1 Stack (à conserver)

| Application        | Rôle                                                        | Stack                                            | Styles                                                  |
| ------------------ | ----------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------- |
| `apps/mobile`      | App iOS/Android/tablettes (et aperçu web Chrome)            | Flutter 3.47, Riverpod 3, go_router 18, Drift    | `LadTheme` (Material 3) + `tokens.g.dart`               |
| `apps/web`         | Programme partagé, confidentialité, console de projection   | Next.js 16, React 19                             | CSS Modules + `@lad/design-tokens/tokens.css`           |
| `apps/admin`       | Back-office éditorial                                       | Next.js 16, React 19                             | CSS Modules + `tokens.css`                              |
| Écran projeté      | `apps/mobile/assets/projection/screen.{html,css,js}`        | HTML/CSS/JS servi par le téléphone (et copié dans le site) | `tokens.css`, thème `[data-theme='projection']` |
| `packages/design_tokens` | **Source unique** (ADR-014) : `tokens.json` → Dart + CSS, contrôle des contrastes en CI | TypeScript | — |

Conséquence : **toute la refonte passe d'abord par `tokens.json`**, puis par `theme.dart`
(Flutter) et les CSS Modules (web). Aucune couleur en dur dans les écrans.

### 1.2 Routes et écrans

**App mobile** (`apps/mobile/lib/app/router.dart`) — barre inférieure à 5 onglets
(Accueil, Recueil, Favoris, Culte, Plus), chaque onglet conserve son état.

| Route                         | Écran (fichier)                                         | Écran de la référence |
| ----------------------------- | ------------------------------------------------------- | --------------------- |
| `/`                           | `features/home/home_screen.dart`                        | A. Accueil            |
| `/recueil`                    | `features/hymnal/hymnal_screen.dart` (onglets N° / A–Z, « Aller au numéro ») | B. Recueil |
| `/recherche`                  | `features/search/search_screen.dart` (plein écran)      | C. Recherche          |
| `/cantique/:id`               | `features/hymn/hymn_screen.dart` (`HymnContent`)        | D. Fiche cantique     |
| `/lecture/:id`                | `features/reader/reader_screen.dart`                    | E. Mode lecture       |
| `/favoris`                    | `features/favorites/favorites_screen.dart` (onglets Favoris / Listes) | F. Favoris |
| `/listes/:id`                 | `features/lists/lists.dart` (`PlaylistScreen`)          | F (secondaire)        |
| `/culte`, `/culte/:id`, `/choisir-cantique` | `features/worship/worship.dart`           | G. Programme du culte |
| `/projection?cantique=` / `?programme=` | `features/projection/projection_screen.dart` (pilote + aperçu) | H. Projection |
| `/plus`, `/plus/hors-connexion`, `/plus/a-propos` | `features/more/more_screen.dart`  | I. Hors connexion (+ réglages) |
| `/compte`                     | `features/account/account_screen.dart`                  | non couvert           |
| (démarrage)                   | `features/startup/startup_gate.dart`                    | non couvert           |

**Site** (`apps/web/src/app`) : `/` (accueil minimal), `/programme/[token]` (programme
partagé), `/projection` (console « ordinateur seul », PWA hors ligne), `/confidentialite`,
`/suppression-compte`.

**Back-office** (`apps/admin/src/app`) : `/connexion`, `/connexion/mfa`, `/acces-refuse`,
espace `(espace)` : tableau de bord, `/cantiques`, `/cantiques/[id]` (éditeur + aperçu
« comme sur mobile »), `/import`, `/publication`, `/anomalies`, `/equipe`, `/journal`.

### 1.3 Composants existants (mobile : `core/design_system/components.dart`, `dialogs.dart`)

| Composant de la référence | Équivalent existant                                       | Action proposée |
| ------------------------- | --------------------------------------------------------- | --------------- |
| `AppShell`                | `features/shell/app_shell.dart` (`NavigationBar`)         | restyler ; rail latéral tablette en option (D-7) |
| `PageHeader`              | aucun (AppBar + textes ad hoc)                            | **créer** (surtitre + titre serif + sous-titre), utilisé par 6 écrans |
| `HeroCard`                | aucun                                                     | **créer** (Accueil uniquement) |
| `SearchField`             | `_SearchEntry` privé (Accueil) ; `TextField` dans l'AppBar (Recherche) | **extraire** un composant commun |
| `HymnListItem`            | `HymnListTile`                                            | restyler (carte fine, badge, titre serif) — pas de renommage |
| `HymnNumberBadge`         | numéro en texte dans `HymnListTile`, `_ItemRow`, `HymnHeader` | **créer** et réutiliser aux 4 endroits |
| `FavoriteButton`          | `IconButton` étoile dupliqué (fiche, lecture)             | **extraire** (même appel `setFavorite`) |
| `Primary/SecondaryButton` | thèmes `FilledButton` / `OutlinedButton`                  | restyler par le thème, pas de nouveau widget |
| `SectionHeading`          | `ListSectionHeader`, `Overline`                           | restyler |
| `HymnLyrics`              | `SectionBlock` (strophe/refrain, filet doré, « (bis) »)   | restyler ; libellés « Strophe n / Refrain » (D-3) |
| `EmptyState`/`ErrorState` | `MessageState` (épi + titre + message + action)           | restyler ; variante erreur |
| `LoadingState`            | `CircularProgressIndicator` / `SizedBox.shrink()`         | **créer** un état sobre réutilisable |
| `OfflineStatus`           | `OfflineScreen` (`_Row`)                                  | restyler en panneau |
| `ProgramItem`             | `_ItemRow` (worship.dart)                                 | restyler avec `HymnNumberBadge` |
| `ProjectionCanvas`        | `SlidePreview` (aperçu) + `screen.css` (écran réel)       | restyler via le thème `projection` |
| Motif épi                 | `WheatEar` (CustomPaint), `WheatDivider`, `AccentRule`    | conserver ; **pas d'emoji 🌾** comme dans le prototype |

Web/admin : `apps/admin/src/components/ui.module.css` (boutons, champs), `status.tsx`,
`flash.tsx`, `hymn-preview.tsx` ; site : un module CSS par page. Pas de bibliothèque UI :
**aucune dépendance à ajouter**.

### 1.4 Tokens actuels vs cible

État actuel : deux directions coexistent.

- **Base** (site, back-office, écran projeté) : blanc pur `#FFFFFF`, Cormorant Garamond /
  Literata / Inter, rayons 4–12 (décision Q-11).
- **Bloc `app`** (app mobile, depuis le **2026-10-19**) : « clair net », blanc froid, noir
  `#0A0A0B`, Space Grotesk / Manrope / IBM Plex Mono, rayons 2–6, numéros « 037bis ».
- **Projection** : noir pur `#000000`, texte blanc.

| Token cible (référence) | Valeur référence | Token existant      | Remarque contraste (WCAG, mesuré)                          | Valeur proposée |
| ----------------------- | ---------------- | ------------------- | ---------------------------------------------------------- | --------------- |
| `canvas`                | `#F7F0E4`        | `background`        | —                                                          | `#F7F0E4` |
| `surface`               | `#FFFAF1`        | `surface`           | —                                                          | `#FFFAF1` |
| `surface-warm`          | `#F0E5D2`        | *(nouveau)*         | —                                                          | `#F0E5D2` |
| `text`                  | `#392A1B`        | `text`              | 12,2:1 sur canvas → **AAA OK** (règle paroles ≥ 7)         | `#392A1B` |
| `text-muted`            | `#89765D`        | `textSecondary`     | **3,85:1 sur canvas → échoue AA (règle CI ≥ 4,5)**         | `#76634B` (5,07:1 canvas, 4,61 surface-warm) |
| `gold`                  | `#A86D13`        | `gold`              | 3,81:1 : OK pour graphismes (≥ 3), **pas pour du texte**   | `#A86D13` (icônes, filets, état actif) |
| *(texte doré)*          | `#89570E` (prototype) | `goldText`     | 5,40:1 canvas ; blanc sur `#A86D13` = **4,32:1 → échoue** pour les libellés de bouton | `#89570E` pour texte doré **et fond des boutons primaires** (blanc dessus : 6,12:1) |
| `gold-light`            | `#D7A84F`        | *(nouveau)*         | 1,9:1 : filets décoratifs uniquement                       | `#D7A84F` |
| `gold-pale`             | `#E8D1A6`        | *(nouveau)*         | texte `#392A1B` dessus : 9,3:1                             | `#E8D1A6` |
| `border`                | `#E8D9BF`        | `hairline`          | décoratif                                                  | `#E8D9BF` |
| `dark`                  | `#171F1F`        | `projection.background` (+ `dark.background`) | `#FFF5E5` dessus : 15,5:1             | voir D-4 |
| `dark-surface`          | `#222B29`        | `dark.surface`      | `#FFF5E5` dessus : 13,5:1                                  | `#222B29` |
| Rayons                  | cartes 12–18, zones 20–24, boutons 10–14 | `radius` sm/md/lg/pill = 2/4/6 (app) | — | sm 8 · md 12 · lg 16 · xl 22 · pill |
| Ombres                  | « douces, rares » | aucune (`shadow: transparent`) | — | 1 token `shadow.soft` (cartes mises en avant seulement) |
| Espacements             | 4…48             | `space` 2…64        | déjà compatible                                            | inchangé |

Le contrôle automatique des contrastes (`pnpm tokens` / `check`) restera bloquant : les
valeurs ci-dessus le passent ; les valeurs brutes de la référence **ne le passent pas**.

### 1.5 Commandes de contrôle et état de référence (exécutées le 2026-10-20)

| Commande                                                       | Résultat avant refonte |
| -------------------------------------------------------------- | ---------------------- |
| `pnpm lint`                                                    | ❌ échec **préexistant** : `@lad/content-tools` (fichier non commité `src/corrections.ts`, tâche 3.11 mise de côté). Sans lien avec l'UI. |
| `pnpm typecheck`                                               | ❌ même cause (TS2379 `corrections.ts:427`) |
| `pnpm test`                                                    | ✅ 6/6 tâches (dont programme partagé contre le serveur réel) |
| `node packages/design_tokens/src/cli.ts check`                 | ✅ tokens valides, contrastes conformes, fichiers générés à jour |
| `cd apps/mobile && flutter analyze`                            | ✅ aucun problème |
| `flutter test test/app test/core test/features test/drift`     | ✅ 152 tests |
| Non lancés en phase 1 : `flutter test test/integration` (supprime le compte jetable), `pnpm build && pnpm e2e` (Chrome, comptes de test), `node tools/pgtap/run.ts` (sans objet : pas de changement de base) | à lancer en phase 4 |

Captures : `pnpm apercu` (Flutter web dans Chrome, 420×900) ou `flutter build web` + script
CDP `tools/e2e/cdp.ts` (`node --experimental-transform-types`). Captures « avant » à faire au
tout début de la phase 2, sur le même catalogue de développement.

---

## 2. Décisions (validées le 2026-10-20 : « recommandations OK »)

Toutes les recommandations ci-dessous sont retenues. D-8 est modifiée : photos **Pexels**
(licence Pexels) au lieu d'un simple dégradé.

| #   | Question | Constat | Recommandation |
| --- | -------- | ------- | -------------- |
| **D-1** | Remplacer la direction « clair net » (validée le **2026-10-19**, révision de Q-11) par « Le recueil vivant » ? Sur quel périmètre ? | La référence impose ivoire, serif, rayons arrondis, ombres douces : c'est l'inverse de « clair net » (blanc froid, sans-serif, angles nets). Les tests `theme_test.dart` et `tokens.test.ts` vérifient explicitement Q-11 (fond `#FFFFFF`, Space Grotesk, rayon ≤ 2) : ils devront être réécrits, et `IMPLEMENTATION_PLAN.md` (Q-11, §15) et ADR-014 mis à jour. | **Oui, sur tout le périmètre** (app, site, back-office, écran projeté) : les nouvelles valeurs vont dans les tokens **de base**, le bloc `app` est vidé (mécanisme conservé). Une seule identité au lieu de deux. |
| D-2 | Accepter les ajustements de contraste ? | `#89765D` (texte secondaire) et blanc sur `#A86D13` échouent WCAG AA (§1.4). | Oui : `textSecondary #76634B`, `goldText #89570E` (texte doré et boutons primaires) ; `#A86D13` réservé aux graphismes. |
| D-3 | Typographie | Référence : serif pour titres et **paroles**, sans-serif pour l'interface. Le 2026-10-19 vous aviez choisi les paroles en Manrope (sans-serif). Polices déjà embarquées et sous OFL : Cormorant Garamond, Literata, Inter. | Titres d'écran et de cantique : **Cormorant Garamond** ; paroles : **Literata** (italique réelle pour le refrain, comme le livre) ; interface : **Inter**. Aucune nouvelle police. Numéros affichés **tels qu'imprimés** (« 37bis », plus « 037bis »). Space Grotesk / Manrope / IBM Plex Mono retirés de l'app à la fin (gain de poids), après accord. |
| D-4 | Fond de projection | Actuel : noir pur `#000` (contraste maximal, meilleur noir sur vidéoprojecteur). Référence : `#171F1F` avec lumière subtile. | `#171F1F` + halo radial très discret pour les paroles ; **« Écran noir » reste noir pur**. Validation en salle (lisibilité à distance) avant de figer. |
| D-5 | Textes éditoriaux du prototype | « Le recueil vivant », « Que chaque chant devienne une prière. », « La bonne parole, retrouvée. », « Vos chants précieux », citation du Psaume 92. Ce sont des textes d'interface (pas du catalogue), mais la référence les dit « modifiables selon la communication officielle » et la citation « seulement si validée ». | Utiliser ces libellés (fichier `app_fr.arb`) **si vous les validez** ; **pas de citation biblique** tant qu'aucun texte n'est fourni et vérifié (la note liminaire existante cite Colossiens 3.16 : possible alternative, à confirmer). |
| D-6 | Favori : étoile → cœur ? Bouton favori dans chaque ligne de liste ? | L'action existe (fiche, lecture) ; elle n'est pas dans les lignes du recueil. | Cœur : oui (purement visuel). Bouton dans les lignes Recueil/Recherche/Favoris : oui, même appel `setFavorite`, cible 48 px, sans changement de données. À refuser si vous préférez des lignes épurées. |
| D-7 | Navigation latérale sur tablette | L'app n'a qu'une barre inférieure, même sur tablette. | `NavigationRail` (mêmes 5 destinations) à partir de 840 px de large ; barre inférieure en dessous. Aucune route modifiée. |
| D-8 | Visuel du héro de l'accueil (**modifié : photos Pexels**) | La photo « blé crépuscule » de la couverture n'a pas de licence confirmée (`docs/ownership/assets.md`) ; l'épi vectorisé est toujours attendu. | Dégradé brun-or dessiné (aucune image) + `WheatEar` existant en filigrane. Photo seulement si droits confirmés. |
| D-9 | Mode lecture sombre | Le thème clair/sombre/système existe déjà (Plus → Thème). Un réglage « lecture immersive » propre au lecteur demanderait une nouvelle préférence (schéma Drift). | Le lecteur suit le thème de l'app ; le thème sombre prend la palette `#171F1F/#222B29`. Pas de nouvelle préférence dans cette refonte. |

---

## 3. Prototype ↔ fonctions réellement implémentées

| Élément du prototype | Réalité dans le code | Traitement |
| -------------------- | -------------------- | ---------- |
| Cantiques, numéros, paroles, « 239bis exemple », programme « Culte du dimanche 10h00 » | Fictifs | **Jamais repris.** Les écrans affichent le catalogue réel (`assets/catalog`, Supabase). |
| « Écouter » (audio) | **Absent** (aucun lecteur, aucun média) | **Masqué.** |
| « Partager » un cantique | **Absent** : seul le partage d'un *programme* existe (lien public, `share_links`) | Masqué sur la fiche ; conservé sur le programme. |
| « Lire le cantique » | Existe (`/lecture/:id`) | Bouton principal de la fiche. |
| « Projeter » | **Existe et fonctionne** : serveur local du téléphone, écrans connectés par QR/URL, sans Internet (ADR-013) ; console web hors ligne | Conservé tel quel. La mention du prototype « la projection temps réel sera dans la version complète » est **fausse ici** : ne pas l'afficher. |
| Mode lecture « strophe par strophe » (Précédent/Suivant = strophe) | Le lecteur affiche **le cantique entier** et Précédent/Suivant change de **cantique** (glissement + boutons) | Comportement conservé ; libellés et contrôles restylés. Le pas-à-pas par strophe existe déjà… dans la projection. |
| Taille du texte A−/A+ | Existe (curseur 16–34, réglages du lecteur et de Plus) | Conservé ; boutons A−/A+ possibles comme raccourcis du même réglage. |
| « Reprendre votre lecture » | **Aucun historique** de lecture | **Non affiché.** |
| Cantique du jour | Existe (`hymnOfTheDay`, déterministe par date) | Restylé. Extrait = premier vers réel s'il diffère du titre. |
| Filtres Recueil « Par numéro / A–Z » | Existent (onglets) | Restylés en pilules. Pas de filtre « catégories » (thèmes présents dans les données mais aucun filtre implémenté). |
| Filtres « Titres / Paroles / Références » | La recherche **groupe** les résultats (Numéro, Titres, Paroles) ; pas de filtre | Groupes conservés ; aucun filtre ajouté. |
| États recherche | Vide initial ✔, aucun résultat ✔, erreur (texte brut `$e`) ✔ ; **chargement = rien** | Ajouter un état de chargement sobre ; message d'erreur lisible. |
| Compteur de favoris | Calculable exactement | Affiché. |
| Programme : nom, date, statut | Titre, date, statut brouillon/publié/archivé ✔ ; pas d'heure | Pas d'heure (décision du propriétaire, 2026-10-20). |
| Programme : sections « Ouverture, Louange… » | Les « moments » libres existent (`label`) | Affichés comme intercalaires, uniquement ceux saisis. |
| Programme : réordonner / supprimer / note | Existe (glisser, menu ↑ ↓, note, retirer) | Conservé. |
| Programme : ajout par n° dans un champ | Ajout via écran de choix (`/choisir-cantique`, avec recherche) | Conservé (plus sûr que la saisie libre). |
| Hors connexion : barre de progression 100 %, « Disponible en démo » | Le recueil est **embarqué** et mis à jour par synchronisation ; l'écran montre nombre de cantiques, édition, dernière vérification, bouton « Vérifier » | **Aucune barre de progression.** Statut réel uniquement. |
| Entrée « Hors connexion » dans la navigation principale | Dans l'onglet « Plus » | Conservé dans « Plus » (la barre reste à 5 entrées). |
| Bandeau « Prototype interactif » | — | Non repris. |

### 3 bis. Fonctions à créer (demande du propriétaire, 2026-10-20)

**État (2026-10-20) : ☑ toutes réalisées et testées**, sauf l'heure du culte
(abandonnée).

« Pour les fonctions que le prototype montre sans que l'app ne le fasse, crée-les simplement. »
Chaque fonction est réelle (données réelles, aucun contenu fictif) et livrée avec son écran en
phase 3.

| Fonction du prototype | Réalisation simple prévue | Écran | Données / risques |
| --------------------- | ------------------------- | ----- | ----------------- |
| Partager un cantique | Bouton « Partager » : feuille de partage du système avec numéro, titre et paroles **verbatim** (ordre imprimé) + « Louanges à Dieu » | D | Aucune donnée nouvelle. Diffusion des paroles hors de l'app : même portée que la copie déjà possible (`SelectionArea`) ; à confirmer dans la décision sur les droits (`docs/ownership/rights-decision.md`). |
| Reprendre votre lecture | Derniers cantiques ouverts (5), sur l'appareil, affichés sur l'accueil ; rien si l'historique est vide | A | Clé locale `history.recent` (table `sync_state`, comme les préférences) : **pas de changement de schéma**, pas de synchronisation, effaçable. |
| Lecture strophe par strophe | Le mode lecture affiche toujours une seule strophe (couplet ou refrain), le refrain répété après chaque couplet (ordre chanté) ; strophe précédente / suivante (boutons, glissement, flèches du clavier) sans changer de cantique ; « 2 / 4 » ; cantique précédent / suivant à part ; commandes en symboles seuls (nom en infobulle et pour les lecteurs d'écran) ; titre agrandi | E | Demande du propriétaire du 2026-10-20 (remplace l'option `pref.readerByStanza`, retirée) ; structure réelle des sections (refrain inclus, ordre chanté respecté). |
| Raccourci « Projeter les paroles » | Ouvre le choix d'un cantique (`/choisir-cantique`) puis la projection | A | Aucune. |
| Ajout au programme par numéro | Champ « N° (ex. 37bis) » + « Ajouter » dans l'éditeur, à côté du choix existant ; message si le numéro n'existe pas | G | Même enregistrement que l'ajout actuel. |
| ~~Heure du culte~~ | **Abandonnée** (propriétaire, 2026-10-20 : « pas une donnée importante ») : aucune modification de la base | — | — |
| Hors connexion : progression | État réel pendant la vérification (« Vérification… », indicateur sans pourcentage), puis résultat (à jour / mis à jour / hors ligne) avec l'heure | I | La synchronisation ne connaît pas d'avancement en octets : **pas de barre à pourcentage**. |
| Écouter (audio) | **Fait (2026-10-20)** : vue d'écoute `/ecoute/:id` (lecture en flux, ±10 s, versions, paroles qui suivent les passages, lecteur fixé en bas) ; hébergement Backblaze B2 (ADR-016 révisé, `docs/deployment/audio-backblaze.md`) ; payload publié avec clé `audio` (migration 0019). | E | Bouton « Écouter » masqué tant que `AUDIO_BASE_URL` n'est pas configurée ou qu'un cantique n'a pas d'enregistrement publié. Back-office : section « Enregistrements audio » de la fiche (chemin, version, durée, droits, passages, écoute). Lecture en arrière-plan (écran verrouillé, notification, casque) et téléchargement pour l'écoute hors connexion : faits, à vérifier sur appareils (recette A-1 à A-7). Reste : dépôt des fichiers (propriétaire). |

---

## 4. Checklist par écran

Légende : ☐ à faire · ☑ fait et vérifié. Chaque écran se termine par : tests ciblés, captures
mobile (390 px) et tablette/desktop (≥ 1024 px), mise à jour de ce fichier.

### Phase 2 — Fondations — ☑ faite le 2026-10-20

- ☑ `packages/design_tokens/tokens.json` : palette ivoire (§1.4) + `surfaceWarm`, `goldLight`,
  `goldPale` ; sombre/projection `#171F1F` ; rayons 8/12/16/22 ; `shadow` (ombre douce) ;
  polices Cormorant / Literata / Inter ; échelle `title`, `sectionTitle`, `cardTitle`,
  `listTitle`, `overline`, `marker` ; bloc `app` retiré (devenu facultatif).
- ☑ `src/tokens.ts`, `contrast.ts`, `generate.ts` : nouvelles couleurs, `LadShadow` (Dart),
  `--lad-shadow-soft` (CSS), bloc `app` facultatif.
- ☑ Règles de contraste ajoutées : texte sur `surfaceWarm`/`goldPale` (≥ 7), texte secondaire
  sur `surfaceWarm`, or texte sur `surface`/`surfaceWarm`, libellé ivoire sur or (≥ 4,5),
  grands numéros or sur `goldPale` (≥ 3). Toutes conformes.
- ☑ `pnpm tokens` : `tokens.g.dart`, `tokens.css`, `assets/projection/tokens.css` régénérés.
- ☑ `theme.dart` : schéma de couleurs or/ivoire, boutons (principal or foncé), champs, focus
  doré, navigation (indicateur or pâle), rail, puces pilule, cartes, dialogues, feuilles,
  SnackBar, curseurs, interrupteurs, cases, info-bulles, barres de défilement.
- ☑ `components.dart` : `HymnNumberBadge`, `PageHeader`, `SearchField`, `HeroCard` (photo +
  voile brun), `LoadingState` ; `Overline` en or ; refrain en italique Literata, filet or clair ;
  `MessageState` (titre serif, action principale) ; `displayNumber` supprimé (numéros tels
  qu'imprimés).
- ☑ `features/favorites/favorite_button.dart` : cœur commun (fiche, lecture), mêmes appels.
- ☑ `app_shell.dart` : barre inférieure restylée (cœur pour Favoris) ; `NavigationRail` ≥ 840 px,
  étendue avec marque ≥ 1200 px.
- ☑ Polices « clair net » retirées (fichiers, `pubspec.yaml`, licences, registre).
- ☑ Photos Pexels dans `apps/mobile/assets/images/` (registre `docs/ownership/assets.md`).
- ☑ Écran projeté : « Écran noir » en noir pur (`screen.css`, aperçu du pilote).
- ☑ Web : polices chargées (`globals.css`, copie d'Inter par `sync-projection-screen.mts`),
  liens et focus dorés. Admin : boutons rayon 12, libellé ivoire, champs à focus doré, en-têtes
  de tableau `surfaceWarm`, navigation `surfaceWarm` avec page courante (`nav-link.tsx`).
- ☑ Tests de décision mis à jour : `theme_test.dart`, `faithful_journey_test.dart` (numéros
  imprimés), `tokens.test.ts` ; nouveaux : `shell_test.dart` (barre / rail / rail étendu),
  bouton principal, ombre invalide, bloc `app` facultatif.

### Phase 3 — Écrans — ☑ faite le 2026-10-20

| Écran | Fait | Écarts / remarques |
| ----- | ---- | ------------------ |
| A. Accueil (`home_screen.dart`) | ☑ héro photo (blé au couchant) avec message éditorial, recherche juste dessous, cantique du jour (carte or pâle, premier vers réel), 4 raccourcis réels, « Reprendre votre lecture » (5 derniers, effaçable) | Sur téléphone (< 600 px) : pas d'en-tête séparé ni de texte d'accompagnement dans le héro, pour garder la recherche visible (vérifié à 360×640, texte à 130 %, vraies polices). Raccourci « Projeter les paroles » ajouté (demande du 2026-10-20) : choix d'un cantique puis projection. |
| B. Recueil (`hymnal_screen.dart`, `HymnListTile`) | ☑ titre « Le recueil » + nombre exact, onglets en pilules, lignes en cartes fines (badge, titre serif, premier vers, cœur), largeur limitée sur tablette | `ListView.builder` conservé (1 143 lignes) ; cœur reconstruit seul (`select`). |
| C. Recherche (`search_screen.dart`) | ☑ titre « La bonne parole, retrouvée. », champ commun, groupes Numéro/Titres/Paroles, états vide / chargement / aucun résultat / erreur | Pendant le calcul, les résultats précédents restent affichés (pas de clignotement). Pas de filtres (non implémentés). |
| D. Fiche cantique (`hymn_screen.dart`) | ☑ bandeau photo brun-or (numéro, titre, premier vers, cœur), actions Lire / Projeter / Partager / À une liste, paroles sur surface ivoire, refrain en italique avec filet or | Libellés « Refrain », « Couplet n » (mot déjà utilisé par la projection et le back-office, plutôt que « Strophe ») ; un couplet sans numéro imprimé n'est pas étiqueté. Partage : texte verbatim + source. Pas d'« Écouter ». Accessibilité : un nœud par section (régression détectée par les tests, corrigée). |
| E. Mode lecture (`reader_screen.dart`) | ☑ largeur 680, en-tête discret, A− / A+, Précédent / Suivant libellés en bas, option « Couplet par couplet » | Thème sombre de l'app = vert-noir immersif (D-9). |
| F. Favoris (`favorites_screen.dart`) | ☑ « Vos chants précieux » + compteur exact, même liste, cœur, état vide avec « Parcourir le recueil » | Onglet « Listes » conservé. |
| G. Programme (`worship.dart`) | ☑ liste en cartes avec statut écrit, éditeur en conducteur (en-tête date/statut, cantiques en cartes avec badge, moments en intercalaires or), ajout par numéro | Pas d'heure (décision du propriétaire). Déplacement : appui long (téléphone) ou poignée (grand écran), comme avant. |
| H. Projection (`screen.css`, `projection_screen.dart`, console web) | ☑ fond vert-noir + lumière discrète, « Écran noir » noir pur (écran, aperçu du pilote, aperçu de la console), sources de la console en panneau | Lisibilité en salle à confirmer sur vidéoprojecteur (propriétaire). |
| I. Hors connexion (`more_screen.dart`) | ☑ panneau d'état réel (nombre, version, dernière vérification), « Vérification en cours… » sans pourcentage, résultat affiché sur place | — |
| J. Back-office et secondaires | ☑ aperçu « comme sur mobile » (rayon, filet du refrain), programme partagé public (cartes, badges, intercalaires), console de projection | Écrans compte, à propos, connexion : thème appliqué, mise en page inchangée. |

### Phase 4 — Recette — ☑ faite le 2026-10-20

- ☑ `flutter analyze` : aucun problème ; `dart format` : conforme.
- ☑ `flutter test` (hors intégration) : **167 tests** ✅ — nouveaux : accueil (petit écran + grands
  caractères avec vraies polices, reprise de lecture, historique, raccourci projection),
  lecture (A+, couplet par couplet), hors connexion, ajout par numéro, partage, numéro saisi,
  navigation (barre / rail).
- ☑ `flutter test test/integration` : 5 ✅ (catalogue réel, Supabase, synchronisation à deux
  appareils, écran projeté dans Chrome). Compte jetable recréé ensuite. Lors d'un passage, un
  marqueur d'erreur est apparu dans le journal du test navigateur alors que le bilan était
  « tout passe » ; deux passages suivants (seul et groupé) sans aucune erreur.
- ☑ `turbo lint typecheck test --continue` : 19/21 ✅ ; 2 échecs **préexistants** dans
  `content-tools` (fichiers non commités de la tâche 3.11).
- ☑ `pnpm build` + `pnpm e2e` (Chrome réel) : projection « ordinateur seul » hors ligne ✅,
  parcours administrateur complet avec second facteur ✅.
- ☑ Tokens : valides, contrastes conformes.
- ☑ Captures finales 360×640, 390×844, 1280×800 (accueil, recueil, recherche, fiches 37bis,
  239bis, titre le plus long n° 564, lecture, favoris, culte, hors connexion) ; back-office et
  écran projeté (captures e2e).
- ☑ Aucun contenu du prototype dans `content/`, `assets/catalog/` ni le code (recherche des
  titres fictifs).
- ☐ Non vérifiable ici : appareils iOS/Android réels, mode avion réel, vidéoprojecteur en salle,
  lecteur d'écran (VoiceOver/TalkBack) — à faire en recette appareil (`docs/qa/recette.md`).

## 5. Risques transverses

1. **Décision contradictoire (D-1)** : sans arbitrage, deux directions coexisteraient.
2. **Contrastes** : valeurs brutes de la référence non conformes (corrigées en §1.4).
3. **Tests de décision** : certains tests figent « clair net » ; les modifier est attendu,
   mais chaque changement sera listé (aucun test de comportement ne doit changer).
4. **Fidélité du texte** (ADR-008) : la refonte ne touche ni le découpage des sections, ni
   les répétitions, ni l'ordre chanté.
5. **Projection** : modification d'un fichier servi hors ligne à des écrans tiers ; garder
   des polices locales et un noir pur pour l'écran noir.
6. **Performance** : ombres et dégradés limités au héro, aux bannières et à la projection ;
   jamais dans les lignes de liste.
7. **Poids de l'app** : polices « clair net » à retirer seulement après validation (D-3).

## 6. Journal

| Date       | Étape   | Fichiers | Tests | Remarques |
| ---------- | ------- | -------- | ----- | --------- |
| 2026-10-20 | Phase 1 | `docs/design/UI_ALIGNMENT_PLAN.md` (créé), référence et prototype copiés dans `docs/design/` | lint ❌ / typecheck ❌ (préexistant, `content-tools`), `pnpm test` ✅, tokens ✅, `flutter analyze` ✅, `flutter test` (hors intégration) ✅ 152 | En attente des décisions D-1 à D-9 |
| 2026-10-20 | Phase 2 | tokens (`tokens.json`, `tokens.ts`, `contrast.ts`, `generate.ts`, fichiers générés), `theme.dart`, `components.dart`, `app_shell.dart`, `favorite_button.dart`, `hymn_screen.dart`, `reader_screen.dart`, `home_screen.dart` (icône), `worship.dart` (numéro), `projection_screen.dart` + `screen.css` (écran noir), `licenses.dart`, `pubspec.yaml`, `app_fr.arb` (cœur), photos `assets/images/`, polices retirées ; web `globals.css`, `sync-projection-screen.mts` ; admin `ui.module.css`, `layout.module.css`, `layout.tsx`, `nav-link.tsx` ; docs (registre d'assets, plan d'implémentation, ADR-014) | tokens ✅ (19 tests, contrastes) ; `flutter analyze` ✅ ; `flutter test` hors intégration ✅ 156 ; `turbo lint typecheck --continue` ✅ 13/15 (2 échecs préexistants `content-tools`) ; `pnpm test` ✅ ; captures avant/après 390 px et 1280 px (10 écrans) | Écrans encore dans leur mise en page d'origine : la composition (héro photo, cartes, badges, bandeau) vient en phase 3. Champ de recherche de l'écran Recherche : contour doré du thème dans la barre (remplacé par `SearchField` en phase 3). Tests d'intégration et e2e non relancés (phase 4). |
| 2026-10-20 | Phases 3-4 | Écrans A à J (voir tableau phase 3), `reading_history.dart`, `hymn_text.dart`, `parseNumberLabel`, préférence `readerByStanza`, `sectionName` partagé ; web (programme, console), admin (aperçu) | 167 tests Flutter ✅, intégration 5 ✅, e2e 2 ✅, lint/typecheck 19/21 (2 préexistants) | Heure du culte abandonnée (propriétaire). Audio bloqué (aucun enregistrement, hébergement non ouvert). |
| 2026-10-20 | Mode lecture | `reader_screen.dart` (une strophe à la fois, glissement et flèches, boutons Cantique précédent / suivant), `preferences.dart` et `app_fr.arb` (option « couplet par couplet » retirée), tests `reader_test`, `faithful_journey_test` | `flutter analyze` ✅ ; `flutter test --exclude-tags reseau` ✅ 170 ; intégration réseau ✅ (1er passage, compte jetable recréé) ; captures 360, 420 et 1280 px | Demande du propriétaire. Suivant s'arrête à la dernière strophe ; on change de cantique par les boutons dédiés. |
| 2026-10-20 | Mode lecture (2) | `reader_screen.dart` (ordre chanté toujours appliqué, commandes en symboles, titre +6 pt, feuille de réglages retirée : A−/A+ restent), `more_screen.dart` (interrupteur « Répéter le refrain » déplacé dans Plus, pour la fiche), `app_fr.arb` (« Strophe précédente / suivante »), tests (jeu d'essai : cantique 2 à deux couplets) | `flutter analyze` ✅ ; `flutter test --exclude-tags reseau` ✅ 170 ; captures 360, 420 et 1280 px | Demande du propriétaire. L'ordre chanté ne s'applique qu'aux cantiques à un seul refrain et à couplets seuls (ADR-009) ; sinon l'ordre imprimé est gardé. |
| 2026-10-20 | Écoute | migration 0019 + test pgTAP 11, contrat `AudioTrack` (+ 4 fixtures), modèle Dart, `Env.audioBaseUrl`, `features/audio/` (just_audio, audio_session), bouton « Écouter », ADR-016, guide Backblaze | `flutter test --exclude-tags reseau` ✅ 182 ; pgTAP ✅ 241 ; turbo lint/typecheck/test 19/21 (2 préexistants) ; captures 390 et 1280 px (lecteur factice) | Aucun enregistrement réel ni hébergement configuré : le bouton reste masqué dans l'app actuelle. |
| 2026-10-20 | Écoute (back-office) | migration 0020 (journal des pistes, `set_audio_segments`), test pgTAP 11 étendu, `lib/audio.ts` (durées, passages « m:ss Libellé »), actions et section « Enregistrements audio » de la fiche, aperçu mobile (« Écouter : … »), CSP `media-src`, e2e étendu, guide | pgTAP ✅ 248 ; admin : tests ✅ 16, lint ✅, typecheck ✅, e2e Chrome ✅ ; turbo 19/21 (2 préexistants) | Ajouter un enregistrement ne repasse pas le cantique en brouillon ; diffusé à la publication suivante. |
| 2026-10-20 | Écoute : arrière-plan et hors connexion | `just_audio_background` (lecteur unique, `MediaItem`), Android (service, permissions, `AudioServiceActivity`), iOS (`UIBackgroundModes audio`), `audio_downloads.dart` (`http`), panneau « Télécharger », Plus → Hors connexion (place, tout supprimer), recette A-1 à A-7 | `flutter analyze` ✅ ; `flutter test --exclude-tags reseau` ✅ 188 ; build web ✅ | Android et iOS non compilés ici (pas de SDK Android ni de Xcode complet) : à valider au premier build et en recette. |
| 2026-10-20 | Karaoké | migration 0021 (`audio_segments.line_index`, `set_audio_segments` vérifie la ligne), test pgTAP 11 étendu, contrat `lineIndex` (+ fixture), modèle Dart (`hasLineCues`), `karaoke_screen.dart` (`/karaoke/:id`, vers chanté rempli ligne après ligne, compte à rebours, toucher un vers), lecteur à « propriétaire » (bascule écoute ↔ karaoké sans coupure), back-office : outil de synchronisation (Espace / S / ⌫ / Entrée), `lib/karaoke.ts` | pgTAP ✅ 252 ; `flutter test --exclude-tags reseau` ✅ 191 ; admin tests ✅ 18, e2e Chrome ✅ ; turbo 19/21 (2 préexistants) ; captures karaoké 390 px (lecteur factice) | Demande du propriétaire. Karaoké visible seulement sur une piste synchronisée vers par vers. |
| 2026-10-20 | Karaoké : pause instrumentale | back-office : touche P (`replay`, `canPause`, fin de vers explicite), annulation par ⌫ ; app : « Reprise dans N s » pendant la pause, vers suivant annoncé sans être marqué chanté | admin tests ✅ 19, typecheck ✅, lint ✅ ; `flutter test --exclude-tags reseau` ✅ 191 | Demande du propriétaire (dernier vers allumé pendant les interludes). Aucun changement de base : une pause est un écart entre deux passages. |
