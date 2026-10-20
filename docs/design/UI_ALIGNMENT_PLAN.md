# Plan d'alignement UI — « Le recueil vivant »

Version 0.2 · 2026-10-20 · Phase 1 validée (« recommandations OK »), **phase 2 (fondations) faite**.
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
| Programme : nom, date, statut | Titre, date, statut brouillon/publié/archivé ✔ ; **pas d'heure** | Pas d'heure affichée. |
| Programme : sections « Ouverture, Louange… » | Les « moments » libres existent (`label`) | Affichés comme intercalaires, uniquement ceux saisis. |
| Programme : réordonner / supprimer / note | Existe (glisser, menu ↑ ↓, note, retirer) | Conservé. |
| Programme : ajout par n° dans un champ | Ajout via écran de choix (`/choisir-cantique`, avec recherche) | Conservé (plus sûr que la saisie libre). |
| Hors connexion : barre de progression 100 %, « Disponible en démo » | Le recueil est **embarqué** et mis à jour par synchronisation ; l'écran montre nombre de cantiques, édition, dernière vérification, bouton « Vérifier » | **Aucune barre de progression.** Statut réel uniquement. |
| Entrée « Hors connexion » dans la navigation principale | Dans l'onglet « Plus » | Conservé dans « Plus » (la barre reste à 5 entrées). |
| Bandeau « Prototype interactif » | — | Non repris. |

### 3 bis. Fonctions à créer (demande du propriétaire, 2026-10-20)

« Pour les fonctions que le prototype montre sans que l'app ne le fasse, crée-les simplement. »
Chaque fonction est réelle (données réelles, aucun contenu fictif) et livrée avec son écran en
phase 3.

| Fonction du prototype | Réalisation simple prévue | Écran | Données / risques |
| --------------------- | ------------------------- | ----- | ----------------- |
| Partager un cantique | Bouton « Partager » : feuille de partage du système avec numéro, titre et paroles **verbatim** (ordre imprimé) + « Louanges à Dieu » | D | Aucune donnée nouvelle. Diffusion des paroles hors de l'app : même portée que la copie déjà possible (`SelectionArea`) ; à confirmer dans la décision sur les droits (`docs/ownership/rights-decision.md`). |
| Reprendre votre lecture | Derniers cantiques ouverts (5), sur l'appareil, affichés sur l'accueil ; rien si l'historique est vide | A | Clé locale `history.recent` (table `sync_state`, comme les préférences) : **pas de changement de schéma**, pas de synchronisation, effaçable. |
| Lecture strophe par strophe | Option du mode lecture : une section à la fois, Précédent / Suivant passent de section en section puis au cantique voisin ; « Strophe 2 / 4 » | E | Préférence locale (clé `pref.readerByStanza`) ; structure réelle des sections (refrain inclus, ordre chanté respecté). |
| Raccourci « Projeter les paroles » | Ouvre le choix d'un cantique (`/choisir-cantique`) puis la projection | A | Aucune. |
| Ajout au programme par numéro | Champ « N° (ex. 37bis) » + « Ajouter » dans l'éditeur, à côté du choix existant ; message si le numéro n'existe pas | G | Même enregistrement que l'ajout actuel. |
| Heure du culte | Champ heure facultatif à côté de la date ; affiché dans la liste, l'éditeur et la page publique | G | **Changement de données** : colonne `service_time` facultative (migration Supabase versionnée + RLS inchangée), contrat partagé, synchronisation, schéma Drift v2 avec migration testée. Aucune valeur inventée pour les programmes existants. |
| Hors connexion : progression | État réel pendant la vérification (« Vérification… », indicateur sans pourcentage), puis résultat (à jour / mis à jour / hors ligne) avec l'heure | I | La synchronisation ne connaît pas d'avancement en octets : **pas de barre à pourcentage**. |
| Écouter (audio) | **Bloqué** : aucun enregistrement n'existe ; l'hébergement des médias (R2, ADR-016) n'est pas ouvert (D-03). Tables `audio_tracks` présentes mais vides. | D | Décision du propriétaire nécessaire (enregistrements, hébergement). Bouton masqué tant qu'un cantique n'a pas d'audio. |

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

### A. Accueil — `features/home/home_screen.dart`

- ☐ `PageHeader` (surtitre « Le recueil vivant » si D-5 validé, titre serif).
- ☐ `HeroCard` : dégradé brun-or, message éditorial (D-5), épi en filigrane ; hauteur ≤ 40 %
  de l'écran sur mobile.
- ☐ `SearchField` **juste sous le héro** (ouvre `/recherche`, comportement inchangé).
- ☐ Carte « Cantique du jour » `goldPale` : numéro serif, titre, premier vers réel, bouton rond.
- ☐ Raccourcis (3 réels) : Recueil, Favoris, Préparer un culte. Pas de raccourci
  « Projection » : la projection se lance depuis une fiche ou un programme (pas de route sans
  contenu). Grille 2 colonnes mobile, 3 desktop.
- ☐ Pas de « Reprendre votre lecture ».
- **Risques** : recherche repoussée sous la ligne de flottaison sur petit écran / grands caractères.
- **Validation** : sur 360×640 avec texte système à 130 %, le champ de recherche est visible
  sans défiler ; `app_test.dart`, `faithful_journey_test.dart` verts.

### B. Recueil — `features/hymnal/hymnal_screen.dart`, `HymnListTile`

- ☐ `PageHeader` « Le recueil » ; onglets N° / A–Z en pilules ; « Aller au numéro » et
  recherche conservés.
- ☐ `HymnListTile` : carte fine `surface`, bordure `border`, `HymnNumberBadge`, titre serif,
  premier vers en secondaire, favori (si D-6), survol/focus doré.
- ☐ En-têtes de lettres (A–Z) restylés ; barre de défilement interactive conservée.
- **Risques** : performance de la liste (≈ 1 000 lignes, `ListView.builder` conservé, pas
  d'ombre par ligne) ; numéros « 37bis »/« 1138 » dans le badge (largeur min. fixe).
- **Validation** : défilement fluide (profil `docs/qa/performance.md`), ordre éditorial
  inchangé, `faithful_journey_test.dart` (ordre des numéros).

### C. Recherche — `features/search/search_screen.dart`

- ☐ Titre éditorial (D-5), `SearchField` proéminent avec exemple (« 37, 37bis, un mot… »).
- ☐ Groupes Numéro / Titres / Paroles conservés, en `ListSectionHeader` restylés.
- ☐ Extraits de paroles dans le même `HymnListTile`.
- ☐ États : vide initial, **chargement (nouveau, sobre)**, aucun résultat, erreur lisible.
  Hors ligne : la recherche est locale, aucun état particulier à inventer.
- **Risques** : debounce et `autofocus` inchangés ; ne pas toucher `search_service.dart`.
- **Validation** : `search_service_test.dart`, `normalize_test.dart` inchangés et verts.

### D. Fiche cantique — `features/hymn/hymn_screen.dart`, `HymnHeader`, `SectionBlock`

- ☐ Bandeau brun-or (hauteur raisonnable sur mobile) : numéro, titre, premier vers ; favori
  en haut à droite.
- ☐ Actions réelles : **Lire** (principal), **Projeter**, **Ajouter à une liste**. Pas
  d'Écouter, pas de Partager (§3).
- ☐ Paroles sur surface ivoire distincte ; libellés sobres « Strophe n » / « Refrain »
  dérivés du type réel ; refrain : filet `goldLight`, retrait, italique Literata.
- ☐ Références bibliques, auteurs, thèmes, « même mélodie » : uniquement si présents (déjà le cas).
- ☐ `SelectionArea` et taille de lecture conservées.
- **Risques** : sémantique d'accessibilité (`Semantics` « Refrain », « deux fois ») ;
  ordre chanté (`sungOrder`) ; ne jamais numéroter une section absente.
- **Validation** : `faithful_journey_test.dart`, `sung_order_test.dart` ; cantique long,
  cantique sans refrain, « (bis) », « 37bis » ; taille 34 pt sans débordement horizontal.

### E. Mode lecture — `features/reader/reader_screen.dart`

- ☐ Largeur de lecture limitée (≈ 680 px) et centrée sur tablette ; numéro discret, titre serif.
- ☐ Précédent / Suivant (cantique) en boutons espacés et libellés, en bas, zone de sécurité.
- ☐ Raccourcis A− / A+ branchés sur le réglage existant (même préférence) ; feuille de
  réglages conservée.
- ☐ Thème sombre `#171F1F` quand l'app est en sombre (D-9).
- **Risques** : `PageView` + `wakelock` inchangés ; contrôles masquant la dernière ligne.
- **Validation** : glissement + boutons ; taille max ; paysage tablette.

### F. Favoris — `features/favorites/favorites_screen.dart`, `features/lists/lists.dart`

- ☐ `PageHeader` (« Vos chants précieux » si D-5), compteur exact.
- ☐ Même `HymnListTile` que le recueil ; onglet Listes conservé et restylé.
- ☐ État vide chaleureux + bouton « Parcourir le recueil » (va sur `/recueil`).
- ☐ Retrait immédiat d'un favori (si D-6) avec SnackBar courte.
- **Validation** : `account_and_lists_test.dart` ; ajout/retrait sans compte et hors connexion.

### G. Programme du culte — `features/worship/worship.dart`

- ☐ Liste des programmes : cartes (titre serif, date, statut en pastille texte + couleur, pas
  couleur seule).
- ☐ Éditeur en « conducteur » : en-tête (titre, date, statut), items numérotés avec
  `HymnNumberBadge`, moments libres en intercalaires, notes en secondaire, poignée de
  réordonnancement visible.
- ☐ Actions réelles conservées : Projeter, Partager (lien), renommer, dupliquer, archiver,
  supprimer, ajouter cantique / moment.
- ☐ États : sans compte (invitation à se connecter), vide, archivé ; erreurs de partage hors
  réseau déjà gérées (SnackBar).
- **Risques** : `ReorderableListView` (clés, glisser) ; FAB et barre d'actions sur petit écran.
- **Validation** : `worship_test.dart`, `user_sync_test.dart`.

### H. Projection — `projection_screen.dart` (pilote), `assets/projection/screen.css` (écran), `apps/web/src/app/projection/*` (console)

- ☐ Thème `projection` (D-4) : fond `#171F1F`, halo discret, paroles grandes centrées,
  numéro/titre en `goldText` discret ; « Écran noir » = noir pur.
- ☐ `SlidePreview` : même rendu que l'écran (polices/couleurs du thème projection).
- ☐ Pilote : statut des écrans connectés, aperçu, « à suivre », liste des diapositives,
  Précédent / Écran noir / Suivant — restylés, comportement identique.
- ☐ Console web : mêmes tokens (sidebar `surfaceWarm`, cartes, pilules).
- **Risques** : contraste et lisibilité à distance ; l'écran projeté est servi hors ligne
  (pas de police web distante) ; fidélité aperçu ↔ écran.
- **Validation** : `projection_test.dart`, `projection_browser_test.dart`, `projection_server_test.dart` ;
  `pnpm e2e` (projection hors ligne, capture `PROJECTION_SHOT`) ; essai en salle (propriétaire).

### I. Hors connexion — `features/more/more_screen.dart` (`OfflineScreen`)

- ☐ Panneau « Recueil sur cet appareil » : nombre de cantiques, édition, dernière
  vérification (valeurs réelles) ; bouton « Vérifier maintenant » ; résultats existants en SnackBar.
- ☐ Aucune barre de progression, aucun « Disponible » non mesuré.
- ☐ Écran « Plus » restylé (réglages, compte, à propos, licences).
- **Validation** : `catalog_sync_test.dart` ; mode avion (recette appareil).

### J. Back-office et écrans secondaires

- ☐ `apps/admin` : tokens via `globals.css` / `ui.module.css` ; nav latérale `surfaceWarm`,
  actif `goldPale` ; tableaux denses (pas d'agrandissement décoratif), champs et boutons harmonisés.
- ☐ Aperçu « comme sur mobile » (`hymn-preview.module.css`) aligné sur la nouvelle fiche
  (suite notée le 2026-10-19).
- ☐ `apps/web` : accueil, programme partagé, confidentialité, suppression de compte.
- ☐ App : compte, à propos, démarrage.
- **Risques** : lisibilité des statuts éditoriaux ; flux MFA ; densité des tableaux.
- **Validation** : `pnpm test`, `pnpm build && pnpm e2e` (parcours administrateur complet).

### Phase 4 — Recette

- ☐ `pnpm lint && pnpm typecheck && pnpm test` (hors échec préexistant de `content-tools`, à signaler s'il persiste)
- ☐ `flutter analyze`, `flutter test` (puis tests d'intégration, après recréation du compte jetable)
- ☐ `pnpm build && pnpm e2e`
- ☐ Parcours : rechercher → ouvrir → lire (taille, précédent/suivant) → favori ajouter/retirer
  → programme (créer, ajouter, réordonner, partager) → projeter (cantique, programme, écran noir)
- ☐ États vide / chargement / erreur / hors ligne
- ☐ 360 px, grands caractères (130–200 %), titres longs, « 37bis », 4 chiffres
- ☐ Captures avant/après comparées au prototype (mobile et ≥ 1024 px)
- ☐ Contrôle : aucun contenu du prototype dans `content/`, `assets/catalog/`, la base
  (`grep` des titres fictifs « Grand est ton nom », « Cantique associé — exemple »)

---

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
