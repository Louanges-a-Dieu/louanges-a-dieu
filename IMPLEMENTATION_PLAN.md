# IMPLEMENTATION_PLAN — « Louanges à Dieu »

> Application mobile (iOS/Android/tablettes), projection web et back-office éditorial
> du recueil de cantiques « Louanges à Dieu ».
>
> **Statut : plan validé le 2026-10-17. Phase 1 : restent 1.2 (organisation GitHub) et les compléments de 1.6, 1.11, 1.12. Phases 2, 3 et 4 terminées. Phase 5 terminée (sauf 5.10 sur appareil, 5.12 bloquée). Phase 6 terminée côté code (6.2 : configuration Auth à faire par le propriétaire). Phase 7 terminée côté code (restent : durée d'expiration dans l'app, lien « ouvrir dans l'app », déploiement Vercel, E2E en CI). Phase 8 terminée côté code (reste : essais sur appareils réels). Phase 9 terminée (reste : connexion par e-mail à essayer après branchement du service d'e-mail). Prochaine : Phase 10 (tests, sécurité, préparation production).**
> Les arbitrages du propriétaire sont consignés en §6.0 et priment sur les propositions par défaut.
>
> Version du plan : 0.2 — 2026-10-17

**Légende**
- `- [ ]` tâche à faire · `- [x]` tâche terminée **et testée** · `- [~]` en cours · `- [!]` bloquée (voir note)
- Une tâche n'est cochée que si elle est réellement fonctionnelle, testée, documentée.
- Les identifiants `Q-xx` (questions), `R-xx` (risques), `C-xx` (incohérences), `A-xx` (anomalies
  du contenu), `ADR-xxx` (décisions d'architecture) sont référencés dans les phases.

---

## Sommaire

1. [Synthèse de compréhension](#1-synthèse-de-compréhension)
2. [Documents audités](#2-documents-audités)
3. [Audit du recueil source (dataset)](#3-audit-du-recueil-source-dataset)
4. [Cohérence entre documents](#4-cohérence-entre-documents)
5. [Exigences et contraintes](#5-exigences-et-contraintes)
6. [Questions nécessitant un arbitrage](#6-questions-nécessitant-un-arbitrage)
7. [Risques](#7-risques)
8. [Dépendances](#8-dépendances)
9. [Décisions d'architecture proposées](#9-décisions-darchitecture-proposées)
10. [Architecture du repository](#10-architecture-du-repository)
11. [Modèle de branches Git et CI/CD](#11-modèle-de-branches-git-et-cicd)
12. [Stratégie de synchronisation offline-first](#12-stratégie-de-synchronisation-offline-first)
13. [Stratégie d'import du catalogue](#13-stratégie-dimport-du-catalogue)
14. [Plan de sécurité Supabase / RLS](#14-plan-de-sécurité-supabase--rls)
15. [Design System](#15-design-system)
16. [Stratégie de qualité et de tests](#16-stratégie-de-qualité-et-de-tests)
17. [Plan de développement détaillé (phases 0 à 10)](#17-plan-de-développement-détaillé)
18. [Traçabilité de la recette](#18-traçabilité-de-la-recette)
19. [Journal du plan](#19-journal-du-plan)

---

## 1. Synthèse de compréhension

« Louanges à Dieu » est le prolongement numérique d'un recueil papier (6ᵉ édition révisée,
« achevé d'imprimer en septembre 2026 », 2 000 exemplaires). Le MVP doit permettre à :

- **un fidèle** (sans compte) de retrouver un cantique en quelques secondes (numéro, titre,
  première ligne, paroles), de le lire confortablement, **y compris en mode avion** ;
- **un utilisateur connecté** de synchroniser favoris et listes entre appareils ;
- **un responsable de culte** de préparer un programme daté, de le partager par lien public en
  lecture seule et de **projeter** les paroles sur grand écran (contrôleur distinct de l'écran) ;
- **un administrateur éditorial** d'importer, corriger, valider et publier le contenu, avec un
  workflow `draft → review → published → archived` et une **validation humaine obligatoire**.

Principes non négociables : offline-first ; **aucune donnée éditoriale inventée** (inconnu = `NULL`,
champ masqué) ; texte source jamais altéré par les enrichissements ; RLS partout ; aucun secret dans
Git ; aucune clé `service_role` côté client ; propriété intégrale du propriétaire sur le code et les
comptes ; architecture prête pour audio, partitions, chorale/SATB et IA **sans les développer**.

---

## 2. Documents audités

Aucun repository n'existait. Les documents sont répartis dans `~/Downloads` et
`~/Documents/Louanges à Dieu`. Inventaire :

| Document | Emplacement | Rôle | Constat |
|---|---|---|---|
| `01_Cahier_des_charges_fonctionnel_Louanges_a_Dieu.docx` (27/09/2026) | Downloads | Référence fonctionnelle | Lu intégralement. 14 exigences F-xxx, 10 tests T-001..T-010 |
| `02_Specifications_techniques_Louanges_a_Dieu.docx` (27/09/2026) | Downloads | Référence technique | Lu intégralement |
| `louanges_a_dieu_schema_v1.sql` (27/09/2026) | Downloads | Schéma PostgreSQL V1 | Lu intégralement. Écarts listés en §4 |
| `Louanges à Dieu - 6ème édition (révisée v8).docx` (30/09/2026) | Documents + Downloads | **Source la plus récente du recueil** (candidat « catalogue maître ») | 1 143 cantiques. Les deux copies sont textuellement identiques |
| `… (révisée v7).docx` (Documents, 30/09) | Documents | Version précédente | Même numérotation que v8, diffère surtout dans l'index |
| `… (révisée v7).docx` (Downloads, 08/09) | Downloads | Ancienne version | **Numérotation différente** (1 147 cantiques, n° 1 à 1141, présence d'un 7bis) |
| `Louanges à Dieu - 6ème édition (révisée).pdf` (30/09) | Documents | Export PDF probable de v8 | Non comparé ligne à ligne (à confirmer, Q-01) |
| `Louanges_a_Dieu_doublons.xlsx` (20/09) | Downloads | Analyse des doublons (16 paires + 6 homonymes) | **Basée sur une numérotation antérieure** (« v7, n° 1 à 1142 ») |
| `Louanges_a_Dieu_corrections_proposees.xlsx`, `…_corrections_936_fin.xlsx`, `…_corrections_970_et_suivants.xlsx` | Downloads | ~450 corrections linguistiques proposées, colonne « Validation » vide | Mentionnent « aucune correction n'a été appliquée ». Numérotations antérieures (jusqu'à 1235) |
| `Cantiques_absents_analyse_complete.xlsx`, `Louanges_a_Dieu_nouveaux_cantiques_proposes.xlsx` | Downloads | Rapprochement avec 3 autres recueils, candidats à l'ajout | Historique éditorial, hors périmètre de l'import MVP |
| Couverture « blé crépuscule » (SVG/TIFF/PDF/Affinity) | Documents | Identité graphique **imprimée** | Ciel rose-orangé, épi doré, polices **Baskerville** et **Brush Script MT** |
| `LOUANGEADIEUA5-modèle.png` / `modèle2.png` | Documents | Modèle de couverture ivoire/or/brun | **Correspond exactement au brief** (ivoire, or, brun, épi) |
| Couverture 5ᵉ édition (`…edition5_Apl.tif`) | Documents | Historique | Fond blé doré, typographie Helvetica |
| Maquettes / prototype Figma | — | Exigé par la spec technique §16 | **Absent** |
| Catalogue maître validé (JSON/CSV/XLSX) | — | Exigé par la spec technique §16 | **Absent** : à produire en Phase 3 à partir du .docx |
| Registre des droits et règles de publication | — | Exigé par la spec technique §16 | **Absent** |
| Jeux de données de test autorisés | — | Exigé par la spec technique §16 | **Absent** : fixtures synthétiques à créer |

> Les autres fichiers des dossiers personnels (photos, documents sans rapport) ont été écartés et
> ne seront ni copiés ni utilisés.

---

## 3. Audit du recueil source (dataset)

Analyse réalisée sur `… (révisée v8).docx` avec un **prototype jetable** (hors repository) : les
chiffres ci-dessous seront recalculés par le vrai pipeline en Phase 3.

### 3.1 Volumétrie

| Mesure | Valeur |
|---|---|
| Cantiques | **1 143** (1 137 numéros distincts + 6 « bis ») |
| Plage | n° 1 à n° 1138 |
| Numéros « bis » | 37bis, 239bis, 244bis, 338bis, 475bis, 598bis |
| Numéro absent | **666** (aucune trace, déjà signalé « restant absent » dans l'analyse des doublons) |
| Sections détectées | ~3 566 (strophes + refrains) |
| Vers | ~18 000 |
| Cantiques avec refrain | 419 |
| Cantiques commençant par le refrain | 40 |
| Références bibliques | **9 seulement** (Psaumes 47, 138, 24, 42 ; Psaume 139, 23, 121, 68, 36) |
| Auteurs, compositeurs, tonalités, thèmes | **Aucun dans la source** : resteront `NULL` / vides |
| Poids du catalogue (JSON) | ~734 Ko brut, **~206 Ko gzip** → embarquable dans l'app |
| Index alphabétique | 1 142 entrées. **Recoupement titre ↔ numéro : 0 divergence** |

### 3.2 Structure de la source (exploitable de façon déterministe)

Le .docx n'utilise **aucun style de paragraphe**. La structure est portée par la mise en forme
directe, de façon très régulière :

| Élément | Signature |
|---|---|
| Numéro | centré, espacement avant 220, gras |
| Titre | centré, espacement après 90, italique (titre = incipit, souvent tronqué) |
| Début de strophe | régime 1 : retrait 1ʳᵉ ligne 160 · régime 2 (≈ à partir de 598bis) : retrait gauche 142 |
| Fin de strophe | espacement après ≥ 80 |
| Refrain | bordure de paragraphe + retrait gauche 160 + italique |
| Référence biblique | aligné à droite, `— Psaumes 47 —` |
| Séparateur | `✤` |
| Fin du recueil | paragraphe « Index des cantiques » puis index puis achevé d'imprimer |

Conventions éditoriales (note liminaire du recueil) :
- le refrain est imprimé **une fois**, après le 1ᵉʳ couplet, et **se chante après chaque couplet** ;
- `(bis)` / `(ter)` portent sur **la ligne ou le vers qui précède** (niveau ligne, pas section) ;
- « 37bis » = cantique chanté **sur la même mélodie** que le n° 37 ;
- majuscules de révérence (Il, Lui, Son…) : le texte ne doit jamais être « corrigé » automatiquement.

### 3.3 Anomalies relevées (à reprendre dans la file de revue éditoriale)

| ID | Anomalie | Volume |
|---|---|---|
| A-01 | N° 666 absent | 1 |
| A-02 | ~~N° 596 absent de l'index alphabétique~~ — **erreur du prototype d'audit, corrigée en Phase 3** : le 596 figure bien dans l'index (« Jésus est vivant → 596, 697 ») | 0 |
| A-03 | Deux régimes de mise en forme (strophes) dans le même document | ≈ 600 → fin |
| A-04 | Sauts de ligne manuels dans un paragraphe (vers collés si mal extraits) | 239bis, 940, 954 |
| A-05 | Sections très longues (possible absence de séparation de strophes) | 137, 255, 600 |
| A-06 | Sections d'une seule ligne | 17 (dont 239bis, 600, 664, 764) |
| A-07 | Lignes de refrain non italiques (incohérence de forme) | 4 |
| A-08 | Titre ≠ première ligne au-delà de la ponctuation (ex. 37 : « O jour heureux » / « Ô jour heureux ») | à quantifier (201 écarts bruts, majoritairement ponctuation) |
| A-09 | Marqueurs de répétition hétérogènes : `(bis)` 441, `(ter)` 133, `(4x)` 19, `(4 x)` 11, `(6x)` 4, `(x4)` 1, `(3 x)` 1, `(2)` 2 | ~612 |
| A-10 | Parenthèses **qui ne sont pas des répétitions** (réponses chantées) : `(alléluia !)` 13, `(ma sœur)` 4, `(Ô Seigneur)`, `(amen !)`, `(oui)`… | ~25 |
| A-11 | Références : « Psaume » vs « Psaumes » | 9 |
| A-12 | Doublons / variantes signalés par l'analyse du 20/09 (16 paires) sur **l'ancienne numérotation** : à re-vérifier sur v8 | 16 |
| A-13 | ~450 corrections linguistiques proposées, non appliquées, **numérotation obsolète** | ~450 |
| A-14 | Espaces insécables (U+00A0, U+202F) avant la ponctuation : à préserver à l'affichage, à normaliser pour la recherche | généralisé |

---

## 4. Cohérence entre documents

| ID | Sujet | Documents | Constat | Proposition |
|---|---|---|---|---|
| C-01 | **Numérotation instable** | doublons.xlsx / corrections.xlsx vs v8 | Les tableurs référencent des numéros qui ne correspondent plus (ex. 295 était « À Jésus je m'abandonne », c'est aujourd'hui « Mon Sauveur me conduit partout ») | Le numéro **imprimé** est l'identité utilisateur : figer l'édition de référence (Q-01). Identité technique = UUID, jamais le numéro |
| C-02 | Répétitions | Schéma (`repeat_type` au niveau **section**) vs source (`(bis)` au niveau **ligne**) | Le modèle ne sait pas représenter la source | Conserver les marqueurs dans le texte (fidélité) et ajouter une annotation structurée par ligne (migration 0002) |
| C-03 | Refrain chanté après chaque couplet | Recueil vs schéma | Le schéma stocke l'ordre imprimé, pas l'ordre chanté | Stocker l'ordre imprimé ; calculer l'ordre chanté à l'affichage/projection (option) ; surcharge éditoriale possible (Q-07) |
| C-04 | Modification d'un cantique publié | Cahier T-009 vs schéma | `hymns.status` unique : éditer un cantique publié modifierait directement le contenu public | Séparer **copie de travail** et **copie publiée** (releases immuables) — ADR-004 |
| C-05 | Synchronisation incrémentale | Spec §6 vs schéma | Pas de version de catalogue, pas de `updated_at` déclenché, pas de tombstones → suppressions non synchronisables | Tables `catalog_releases` + `published_hymns`, colonnes de sync utilisateur — ADR-005/006 |
| C-06 | Rôles | Cahier §3 vs schéma | Aucune table de rôles, aucune politique RLS, RLS non activée | Migration rôles + RLS (§14) |
| C-07 | Liens publics « expiré/désactivé » | Cahier §8 vs schéma | `public_token` sans révocation ni expiration | Ajouter `share_revoked_at`, `share_expires_at`, rotation du jeton |
| C-08 | Journal des modifications | Spec §9 vs schéma | Absent | Table `audit_log` + triggers |
| C-09 | Anomalies / import | Cahier F-ADM-002 vs schéma | Pas de tables d'import ni d'anomalies | Tables `import_batches`, `import_issues` |
| C-10 | Projection temps réel | Spec §8 vs schéma | Pas d'état de projection persistant | Table `projection_sessions` + Realtime |
| C-11 | Ordre des éléments | Schéma | `unique(playlist_id, display_order)` non différable → réordonnancement impossible en une transaction simple | Contraintes `DEFERRABLE INITIALLY DEFERRED` |
| C-12 | Unicité du numéro | Schéma | `unique(edition_id, number_label)` inopérant si `edition_id` NULL | `edition_id NOT NULL` pour les cantiques |
| C-13 | Recherche sans accents | Spec §7 vs schéma | Index FTS `french` sans `unaccent` | Extension `unaccent` + fonction immuable |
| C-14 | `app_users` | Schéma | Duplique l'e-mail d'`auth.users` (donnée personnelle) | Table `profiles` liée à `auth.users`, sans copie de l'e-mail |
| C-15 | Identité graphique | Brief (« fond ivoire/crème ») vs couverture imprimée (« blé crépuscule », rose-orangé) | Les deux existent ; le modèle ivoire correspond au brief | Suivre le brief (ivoire/or/brun), épi comme signature (Q-11) |
| C-16 | Polices | Couverture (Baskerville, Brush Script MT) | Polices propriétaires non redistribuables dans une app | Équivalents sous licence libre (OFL) ; logo vectorisé (Q-12) |
| C-17 | Arborescence | Spec §12 (`database/…`) vs convention Supabase CLI (`supabase/…`) | Divergence mineure | Utiliser `supabase/` (convention CLI), documenté (ADR-001) |
| C-18 | Listes pour visiteurs | Brief (« favoris nécessaires » en local) vs cahier (« listes pour utilisateurs connectés ») | Les listes anonymes ne sont pas tranchées | Q-05 |
| C-19 | Annonce « index page 245 » | Note liminaire du recueil | Sans objet dans l'app | Ne pas afficher cette ligne de la note liminaire dans l'app (Q-14) |

---

## 5. Exigences et contraintes

### 5.1 Exigences fonctionnelles → phase

| ID | Exigence | Phase |
|---|---|---|
| F-ACC-001 | Accueil : identité, recherche, cantique du jour, raccourcis, sans compte | 5 |
| F-REC-001 | Recueil trié par numéro, accès direct, suffixes bis conservés | 5 |
| F-REC-002 | Navigation alphabétique titre/première ligne, hors connexion | 5 |
| F-SEA-001 | Recherche numéro/titre/première ligne/paroles < 1 s en local | 4–5 |
| F-HYM-001 | Fiche : numéro, titre, strophes, refrain, bis/ter, rien d'inventé | 5 |
| F-HYM-002 | Références bibliques si renseignées, sinon masquées | 5 |
| F-FAV-001 | Favoris hors connexion | 6 |
| F-LST-001 | Listes : créer, ajouter, réordonner, synchroniser | 6 |
| F-OFF-001 | Lecture/recherche en mode avion | 4–5, 10 |
| F-WOR-001 | Programme daté, sections libres, cantiques ordonnés | 7 |
| F-WOR-002 | Lien public en lecture seule, sans accès au compte | 7 |
| F-PRO-001 | Projection plein écran, précédent/suivant, contrôleur distinct | 8 |
| F-ADM-001 | Import et édition, brouillon avant publication | 3, 9 |
| F-ADM-002 | Anomalies, validation humaine obligatoire | 3, 9 |
| §13 cahier | Registre des droits : inconnu / en attente / autorisé / restreint / domaine public | 2, 9 |

### 5.2 Contraintes transverses

- Offline-first : catalogue, index de recherche, favoris disponibles sans réseau.
- Écrans exigés : splash, accueil, recueil, recherche, fiche, lecture, favoris, listes, programme,
  contrôleur de projection, écran projeté, téléchargements/hors connexion, profil/paramètres,
  back-office (tableau de bord, liste, édition, anomalies, publication).
- États UX : chargement, vide, erreur réseau, hors connexion, sync en attente, aucun résultat,
  correspondance partielle, contenu incomplet ou en révision, programme vide/non publié,
  lien expiré/désactivé ; taille de police et contraste accessibles.
- Environnements distincts : développement, recette (staging), production.
- Hors périmètre MVP : IA, SATB, transposition, accords, partitions, audio, paiement, social.
- Livrables : code, historique Git, build reproductible, migrations, scripts d'import,
  documentation (installation, déploiement, sauvegarde/restauration), tests, cahier de recette
  exécuté, builds iOS/Android, staging et production, transfert des comptes et secrets.

---

## 6. Questions nécessitant un arbitrage

### 6.0 Arbitrages rendus par le propriétaire (2026-10-17)

| ID | Décision du propriétaire | Conséquence dans le plan |
|---|---|---|
| Q-01 | La v8 (30/09/2026) fait foi. Le n° 596 doit figurer dans l'index | **Constat corrigé en Phase 3** : le 596 est déjà dans l'index imprimé (ligne « 596, 697 », mal lue par le prototype d'audit). Dans l'app, l'index A-Z est de toute façon généré depuis le catalogue. Le n° 666 reste absent (rien n'est inventé) |
| Q-02 | Les cantiques au statut de droits `unknown` **peuvent être publiés** | Règle de `publishable_hymns` : `unknown`, `pending`, `cleared`, `public_domain` publiables ; `restricted` non publiable. Le registre des droits reste en place |
| Q-03 | **Validation par lots** | Validation groupée dans le back-office (9.6), avec revue individuelle maintenue pour les cantiques porteurs d'une anomalie bloquante |
| Q-05 | **Non** : pas de listes ni de programmes pour les visiteurs | Visiteur = lecture, recherche, favoris locaux. Listes et programmes exigent un compte (ils restent utilisables hors connexion une fois connecté) |
| Q-07 | **Oui** : le refrain est répété automatiquement en projection | Séquenceur de diapositives : refrain inséré après chaque couplet (désactivable par programme) |
| Q-08 | **Non** : Internet n'est pas fiable pendant les cultes | **La projection doit fonctionner sans Internet** : ADR-013 révisé (projection sur réseau local, sans dépendance au cloud) |
| Q-11 | Style **pur et épuré, basé sur le blanc** | Tokens : fond blanc, texte brun-noir, or réservé à l'épi et aux accents (§15 révisé) |
| Q-12 | Proposer une typographie. Photos issues de **Pexels** | Proposition typographique en §15 (polices OFL). Photos Pexels utilisables (licence Pexels), source de chaque photo consignée dans un registre d'assets |
| Q-15 | **Vercel** en premier lieu | `apps/admin` et `apps/web` déployés sur Vercel. Vérifier l'offre : l'offre gratuite « Hobby » est réservée à un usage personnel non commercial |
| Q-17 | Organisation : **« Louanges à Dieu »**. E-mail du projet : **`louangesaDieu04@gmail.com`** (confirmé). Publication sur les stores via un **compte individuel**. Identifiant d'application : **`org.louangesadieu.app`** (validé, définitif après la 1ʳᵉ publication). Projet Supabase **`ssvhoqpvxvfkhwxkewwl`** = base de **développement** du backend | Voir R-06 révisé et R-16. Les projets Supabase `staging` et `prod` seront créés séparément avant la Phase 10 |
| Q-04, Q-06, Q-09, Q-10, Q-13, Q-14, Q-16, Q-18, Q-19, Q-20 | Non tranchées explicitement ; le plan étant validé, **les propositions par défaut s'appliquent** | — |

### 6.1 Questions initiales et propositions par défaut

Les questions **bloquantes** doivent être tranchées avant la phase indiquée. Une proposition par
défaut est donnée pour chacune.

| ID | Question | Bloque | Proposition par défaut |
|---|---|---|---|
| **Q-01** | Quel fichier fait foi pour l'édition **imprimée** (numéros que les fidèles ont en main) ? `… (révisée v8).docx` du 30/09 correspond-il exactement au livre imprimé ? | Phase 3 | v8 = édition de référence « 6ᵉ édition 2026 », à confirmer contre le PDF imprimé |
| **Q-02** | Droits de diffusion des paroles : quelle règle de publication pour les cantiques au statut `unknown` ? Certains textes sont manifestement récents (traductions de chants contemporains) | Phase 2 (règle), Phase 10 (prod) | Règle paramétrable. Le statut `unknown` n'empêche pas la publication en **recette** ; en **production**, décision écrite du propriétaire requise |
| **Q-03** | Validation éditoriale de 1 143 cantiques : revue individuelle obligatoire, ou validation **par lots** des cantiques sans anomalie après échantillonnage ? | Phase 9 | Lots autorisés pour les cantiques sans anomalie, après relecture d'un échantillon ; revue individuelle obligatoire pour ceux qui ont une anomalie |
| **Q-04** | Les corrections linguistiques (~450, colonne « Validation » vide, numérotation obsolète) doivent-elles être intégrées ? | Phase 3 | Non appliquées automatiquement. Importées comme **suggestions** rattachées par correspondance de texte, à valider une par une dans le back-office (optionnel, après le MVP si le temps manque) |
| **Q-05** | Un visiteur sans compte peut-il créer des **listes** et des **programmes** en local ? | Phase 6 | Oui en local (meilleure expérience hors connexion) ; un compte n'est requis que pour synchroniser, partager et projeter à distance |
| **Q-06** | Le « responsable de culte » est-il un **rôle attribué**, ou tout utilisateur connecté peut-il créer et partager un programme ? | Phase 2 | Tout utilisateur connecté (pas de rôle dédié au MVP) |
| **Q-07** | En lecture et en projection, faut-il **répéter automatiquement le refrain** après chaque couplet (ordre chanté) ? | Phase 5/8 | Lecture : ordre imprimé. Projection : refrain inséré après chaque couplet (désactivable par programme) |
| **Q-08** | Internet est-il disponible de façon fiable dans les lieux de culte pendant les cultes ? | Phase 8 | Double mode : temps réel via Supabase si connecté, **et** mode local (contrôleur et écran sur le même ordinateur) qui fonctionne sans réseau une fois le programme chargé |
| **Q-09** | La page publique d'un programme partagé affiche-t-elle **les paroles**, ou seulement numéros et titres ? | Phase 7 | Numéros et titres, plus un lien d'ouverture dans l'app ; paroles seulement pour les cantiques dont les droits l'autorisent |
| **Q-10** | « Cantique du jour » : sélection éditoriale ou automatique ? | Phase 5 | Automatique et déterministe (date → cantique publié), identique pour tous et calculé hors connexion ; surcharge éditoriale possible plus tard |
| **Q-11** | Référence visuelle de l'app : modèle **ivoire/or/brun** (brief) ou couverture imprimée **« blé crépuscule »** ? | Phase 1 (tokens) | Ivoire/or/brun conformément au brief ; la photo « blé crépuscule » peut servir d'illustration du splash si sa licence le permet |
| **Q-12** | Licences : polices (Baskerville, Brush Script MT), photo de couverture (origine ? Pexels ?), modèle ivoire (généré par IA ?) | Phase 5 | Polices OFL de substitution (lecture : *Literata* ou *EB Garamond* ; titres : *Cormorant Garamond*) ; logo vectorisé ; photos utilisées seulement après confirmation de la licence |
| **Q-13** | Méthodes de connexion | Phase 6 | Code à usage unique par e-mail (OTP) uniquement au MVP. Sign in with Apple et Google plus tard (Apple l'exige dès qu'un login social tiers est proposé) |
| **Q-14** | Faut-il afficher la note liminaire du recueil (« Note sur l'utilisation », Colossiens 3.16) dans l'app ? | Phase 5 | Oui, page « À propos du recueil », sans la mention de la page 245 |
| **Q-15** | Hébergement du back-office et du web de projection : **Cloudflare** (déjà retenu pour R2) ou **Vercel** ? | Phase 1 | Cloudflare (Workers via OpenNext), pour limiter le nombre de fournisseurs |
| **Q-16** | Crash reporting : Sentry ou Firebase Crashlytics ? | Phase 10 | Sentry (mobile + web, une seule console) ; Firebase non utilisé au MVP |
| **Q-17** | Identité légale propriétaire des comptes (nom de l'organisation, adresse e-mail **institutionnelle**, numéro D-U-N-S pour Apple) | Phase 1 / 10 | Comptes créés au nom de l'église avec une adresse e-mail dédiée, jamais une adresse personnelle |
| **Q-18** | Doublons et variantes (A-12) : faut-il les traiter avant la publication du MVP ? | Phase 9 | Non bloquant : le contenu reste fidèle au livre imprimé ; les relations `variant` et `related` sont proposées en brouillon |
| **Q-19** | Le .docx source peut-il être versionné dans le dépôt privé (pour rejouer l'import en CI), ou doit-il rester hors Git ? | Phase 3 | Hors Git (stockage du propriétaire) ; la CI utilise des fixtures synthétiques ; l'import réel est rejoué localement par l'opérateur |
| **Q-20** | Langues : français seul, ou d'autres langues prévues (cantiques en langues locales) ? | Phase 1 | Français seul ; `language_code` et l'infrastructure i18n (ARB) sont préparés |

---

## 7. Risques

| ID | Risque | Prob. | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | **Numérotation changeante** entre versions du recueil → favoris, listes et programmes pointant vers le mauvais cantique | Élevée | Critique | Identité = UUID ; numéro = attribut d'édition ; Q-01 avant import ; toute renumérotation passe par une table de correspondance versionnée |
| R-02 | **Droits d'auteur** sur des paroles récentes diffusées publiquement (app, liens publics, projection) | Moyenne | Critique | Registre des droits, règle de publication paramétrable (Q-02), décision écrite du propriétaire avant production |
| R-03 | Mauvaise détection de structure (strophe/refrain) à l'import | Moyenne | Élevé | Parseur déterministe, test de fidélité aller-retour à 100 %, file d'anomalies, revue humaine |
| R-04 | Charge de revue éditoriale (1 143 cantiques) sous-estimée → MVP bloqué | Élevée | Élevé | Validation par lots encadrée (Q-03), tableau de bord de progression, priorisation |
| R-05 | Poste de dev actuel : pas de Flutter/Node/Xcode/Android SDK ; macOS 14.4 trop ancien pour les Xcode récents ; 35 Go libres | Certaine | Moyen | Builds iOS via runners macOS GitHub Actions ; outillage épinglé (FVM, .nvmrc) ; mise à jour macOS ou autre poste |
| R-06 | **Comptes stores individuels** (Q-17) : sur l'App Store, le vendeur affiché sera le **nom légal de la personne titulaire**, pas « Louanges à Dieu » ; le compte est lié à l'identifiant Apple d'une personne | Certaine | Moyen | Titulaire = personne désignée par le propriétaire (jamais le développeur) ; identifiants dans le coffre ; transfert ultérieur possible vers un compte organisation (« App Transfer » côté Apple, transfert d'app côté Google) |
| R-16 | **Google Play, compte personnel récent** : test fermé obligatoire avec un minimum de testeurs (12 à ce jour) pendant 14 jours consécutifs avant l'accès à la production, plus une vérification d'identité | Certaine | Élevé (date de sortie) | Ouvrir le compte et lancer le test fermé dès la fin de la Phase 5 ; recruter les testeurs dans l'assemblée |
| R-17 | Offre Vercel gratuite (« Hobby ») réservée à un usage personnel non commercial ; un projet d'organisation peut nécessiter l'offre payante | Moyenne | Faible | Vérifier les conditions au moment du déploiement de staging ; garder l'app portable (Next.js standard, sans API propriétaire) |
| R-07 | Comptes créés sur une adresse personnelle → non transférables | Moyenne | Élevé | Checklist de propriété (Phase 1), adresse institutionnelle, gestionnaire de secrets d'organisation |
| R-08 | Supabase gratuit : projets mis en pause après inactivité ; sauvegardes limitées | Élevée (staging) | Moyen | Production sur offre payante avec sauvegardes ; dump logique hebdomadaire vers R2 ; restauration testée |
| R-09 | Projection dépendante d'Internet dans les lieux de culte | Moyenne | Élevé | Mode local (Q-08), état persistant, reprise automatique |
| R-10 | Recherche peu pertinente (accents, apostrophes typographiques `’`, `œ`, espaces insécables) | Moyenne | Moyen | Normalisation unique testée (Dart et SQL), jeux de tests de recherche |
| R-11 | Conflits de synchronisation (listes réordonnées sur deux appareils) | Faible | Moyen | Politique LWW documentée au niveau liste ; tests dédiés |
| R-12 | Perte de la clé de signature Android / certificats iOS | Faible | Critique | Play App Signing ; clé d'upload sauvegardée dans le coffre du propriétaire ; procédure documentée |
| R-13 | Dérive de périmètre (audio, IA) | Moyenne | Moyen | Hors périmètre explicite ; tables V2 présentes mais inutilisées |
| R-14 | Fuite de données personnelles (e-mails, programmes) | Faible | Élevé | Minimisation (pas de copie de l'e-mail), RLS testée par pgTAP, logs sans données personnelles |
| R-15 | Exigences des stores (suppression de compte, politique de confidentialité, déclarations de données) | Moyenne | Moyen | Intégrées en Phases 6 et 10 |

---

## 8. Dépendances

| ID | Dépendance | Responsable | Nécessaire pour |
|---|---|---|---|
| D-01 | Organisation GitHub au nom du propriétaire + dépôt **privé** | Propriétaire (dev assiste) | Phase 1 |
| D-02 | Organisation Supabase du propriétaire : projets `staging` et `prod` | Propriétaire | Phase 2 (local d'abord, cloud ensuite) |
| D-03 | Compte Cloudflare (R2 pour la V2 et les sauvegardes, hébergement web si Q-15) | Propriétaire | Phase 7 à 10 |
| D-04 | Apple Developer Program (organisation, D-U-N-S) | Propriétaire | Phase 10 (TestFlight dès Phase 5 si possible) |
| D-05 | Google Play Console (organisation) | Propriétaire | Phase 10 (test interne dès Phase 5) |
| D-06 | Nom de domaine (ex. sous-domaines de `eglisedabidjan.com`, présent sur la couverture) | Propriétaire | Phase 7 (liens publics), Phase 8 |
| D-07 | Gestionnaire de secrets d'organisation (ex. Bitwarden Organisation, 1Password Teams) | Propriétaire | Phase 1 |
| D-08 | Outillage : Flutter (FVM), Node LTS + pnpm, Supabase CLI, Docker, Xcode (macOS récent), Android SDK | Développeur | Phase 1 |
| D-09 | Réponses aux questions Q-01, Q-02, Q-11, Q-15, Q-17 | Propriétaire | Phases 1 à 3 |
| D-10 | Confirmation des licences : polices, photos, logo (Q-12) | Propriétaire | Phase 5 |
| D-11 | Relecteurs éditoriaux disponibles (revue du catalogue) | Propriétaire | Phase 9 |
| D-12 | Appareils de recette : 1 iPhone, 1 Android, 1 tablette | Propriétaire / dev | Phase 10 |

---

## 9. Décisions d'architecture proposées

Chaque décision fera l'objet d'un ADR dans `docs/architecture/adr/` (Phase 1).

| ADR | Décision | Justification |
|---|---|---|
| ADR-001 | **Monorepo** unique : `apps/mobile` (Flutter), `apps/admin` (Next.js), `apps/web` (Next.js : projection + pages publiques), `packages/*`, `supabase/` | Contrats partagés, CI unique, transfert simple. Admin et web public séparés : surfaces d'attaque et déploiements distincts |
| ADR-002 | **Riverpod** (plutôt que Bloc) pour Flutter | Injection de dépendances et état unifiés, vérifiés à la compilation ; surcharge triviale en test (`ProviderContainer`/`overrides`) ; adapté aux flux réactifs Drift (`StreamProvider`) ; moins de code répétitif pour une petite équipe ; le moteur de sync ne dépend pas du `BuildContext`. Bloc reste pertinent pour de grandes équipes qui veulent tracer chaque événement, ce qui n'est pas le besoin ici |
| ADR-003 | Architecture Flutter **feature-first** en couches `data / domain / presentation`, `go_router`, modèles immuables, repositories abstraits | Testabilité, modules isolés, ajout V2 (audio, partitions) par nouvelles features |
| ADR-004 | **Copie de travail ≠ copie publiée** : les éditeurs modifient les tables éditoriales ; la publication crée une **release de catalogue immuable** (`catalog_releases` + `published_hymns` en JSONB) | Satisfait T-009 (un cantique publié modifié reste publié dans sa version précédente jusqu'à la nouvelle publication), publication atomique, sync incrémentale simple, rollback possible |
| ADR-005 | **Catalogue serveur-autoritaire, distribué par releases** : snapshot embarqué dans l'app + deltas au niveau cantique | 206 Ko gzip : embarquer tout le catalogue est peu coûteux et garantit le mode avion dès l'installation |
| ADR-006 | **Données utilisateur local-first** : écriture immédiate dans SQLite + outbox ; push/pull via `server_revision` ; LWW ; tombstones | Simple, robuste, conforme à la spec §6 |
| ADR-007 | Recherche locale **SQLite FTS5** (`unicode61 remove_diacritics 2`) + normalisation applicative partagée ; Postgres FTS + `unaccent` pour le back-office | Spec §7 ; < 1 s garanti sur 1 143 cantiques |
| ADR-008 | Fidélité textuelle : le texte source est stocké **verbatim** (NFC, espaces insécables conservés) ; marqueurs `(bis)`, `(ter)` laissés dans le texte **et** annotés structurellement par ligne | Aucune altération du texte source ; prépare la synchronisation audio V2 |
| ADR-009 | Ordre imprimé stocké ; **ordre chanté calculé** (refrain après chaque couplet) côté client, surcharge éditoriale optionnelle | Fidélité au livre et usage réel en culte (Q-07) |
| ADR-010 | Rôles applicatifs dans `user_roles` ; vérification par fonction `has_role()` (`SECURITY DEFINER`, `search_path` figé) dans les politiques RLS **et** côté serveur Next.js | Défense en profondeur ; aucune confiance dans le client |
| ADR-011 | **Aucune clé `service_role`** dans les apps. L'import passe par le back-office avec la session de l'éditeur (RLS) ; les migrations passent par la CLI Supabase avec un jeton d'accès stocké dans les secrets d'environnement GitHub | Spec §5, brief §8 |
| ADR-012 | Partage de programme via **jeton opaque** (≥ 128 bits, base64url), révocable, expirable, lu uniquement via une RPC `get_shared_program(token)` qui ne renvoie aucune donnée du compte | F-WOR-002 |
| ADR-013 (révisé, Q-08) | Projection **sans Internet** : (1) **téléphone/tablette pilote** — l'app mobile embarque un petit serveur local (HTTP + WebSocket) qui sert l'écran projeté ; l'ordinateur relié au projecteur ouvre l'adresse locale (QR code) dans un navigateur, via le Wi-Fi local ou le point d'accès du téléphone, sans Internet ; (2) **ordinateur seul** — app web installable (PWA) avec catalogue hors ligne, fenêtre de contrôle + fenêtre projetée (`BroadcastChannel`). Le canal Supabase Realtime n'est plus requis au MVP | Spec §8 (« canal temps réel » = WebSocket local) + réalité du terrain (Q-08). Contenu servi en lecture seule, session protégée par un jeton aléatoire dans l'URL |
| ADR-014 | Design tokens **source unique** (`packages/design_tokens/tokens.json`) générant du Dart (Flutter) et des variables CSS (web) | Brief §6 : aucune valeur de style dispersée |
| ADR-019 | Hébergement web sur **Vercel** (Q-15) : un projet Vercel par app (`admin`, `web`), environnements Preview/Production reliés aux environnements Supabase | Décision du propriétaire |
| ADR-015 | Pipeline d'import en **TypeScript** (`packages/content_tools`), contrat de catalogue en **Zod → JSON Schema** (`packages/shared_contracts`) ; fixtures de contrat partagées avec les tests Dart | Une seule implémentation de la validation, partagée par l'import, le back-office et la CI ; pas de 4ᵉ langage |
| ADR-016 | Médias V2 sur **Cloudflare R2** derrière une abstraction `MediaStorage` (URLs signées) ; non provisionné pour le contenu au MVP, seulement pour les sauvegardes | Évolutivité sans coût prématuré |
| ADR-017 | Versions épinglées : FVM (`.fvmrc`), `.nvmrc`, `packageManager` pnpm, version de la CLI Supabase, lockfiles commités ; Renovate pour les mises à jour | Builds reproductibles |
| ADR-018 | Contrôle de la publication par les droits : vue `publishable_hymns` appliquant la règle de Q-02 | Gouvernance des droits du cahier §13 |

---

## 10. Architecture du repository

```text
louanges-a-dieu/
├── IMPLEMENTATION_PLAN.md
├── README.md                     # démarrage rapide, liens vers docs/
├── LICENSE                       # propriétaire, tous droits réservés (à confirmer)
├── .github/
│   ├── workflows/                # ci-mobile, ci-web, ci-db, ci-content, security, deploy-*
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── renovate.json
├── apps/
│   ├── mobile/                   # Flutter (iOS, Android, tablettes)
│   │   ├── lib/
│   │   │   ├── app/              # bootstrap, router, flavors
│   │   │   ├── core/             # design_system, database (Drift), sync, search, network, l10n, logging
│   │   │   └── features/         # home, hymnal, search, hymn, reader, favorites, lists,
│   │   │                         # worship, projection, settings, auth  (+ V2 : audio, scores)
│   │   ├── assets/catalog/       # snapshot de catalogue embarqué (généré, non versionné si Q-19)
│   │   ├── test/                 # unitaires + widget + golden
│   │   └── integration_test/     # parcours, mode avion
│   ├── admin/                    # Next.js + TS : back-office éditorial (domaine dédié)
│   └── web/                      # Next.js + TS : écran projeté, contrôleur web, pages publiques
├── packages/
│   ├── shared_contracts/         # Zod + JSON Schema : catalogue, release, programme partagé, projection
│   ├── content_tools/            # CLI d'import : extraction .docx, structuration, anomalies, rapport
│   ├── design_tokens/            # tokens.json + générateurs Dart et CSS
│   └── ui_web/                   # composants React partagés admin/web (rendu d'un cantique)
├── supabase/
│   ├── config.toml
│   ├── migrations/               # 0001_baseline_v1.sql, 0002_…, versionnées, jamais modifiées après merge
│   ├── tests/                    # pgTAP : RLS, workflow, RPC
│   ├── seed.sql                  # données synthétiques de dev (aucun contenu protégé)
│   └── functions/                # Edge Functions si nécessaire
├── docs/
│   ├── architecture/             # vue d'ensemble, adr/, sync.md, security.md, data-model.md
│   ├── api/                      # RPC et contrats
│   ├── deployment/               # environnements, variables, déploiement, sauvegarde/restauration, runbook
│   ├── editorial/                # guide de revue, règles d'import, anomalies A-xx
│   ├── ownership/                # inventaire des comptes, checklist de transfert
│   └── qa/                       # cahier de recette, protocole mode avion, rapports
├── tools/                        # scripts dev (bootstrap, génération tokens, export snapshot)
├── .fvmrc  .nvmrc  package.json  pnpm-workspace.yaml  turbo.json
└── .editorconfig  .gitignore  .gitattributes  .env.example
```

---

## 11. Modèle de branches Git et CI/CD

**Trunk-based development avec branches courtes** (GitFlow serait surdimensionné ici).

- `main` : protégée, toujours déployable. Merge **uniquement par PR** avec CI verte, au moins
  1 revue (CODEOWNERS), historique linéaire (squash merge). Push direct et force-push interdits.
- Branches de travail : `feat/<phase>-<sujet>`, `fix/<sujet>`, `chore/<sujet>`, `docs/<sujet>`,
  durée de vie de quelques jours au maximum.
- Messages : **Conventional Commits** (`feat(mobile): …`, `fix(db): …`), vérifiés en CI.
- Versionnage : SemVer. Tags `vX.Y.Z` pour une release coordonnée ; numéro de build mobile
  incrémenté par la CI.
- Correctif urgent : branche `hotfix/<sujet>` depuis le tag, PR vers `main`, nouveau tag patch.
- Le contenu éditorial n'est **pas** versionné dans Git : il est versionné en base (releases).

**Pipelines GitHub Actions**

| Workflow | Déclencheur | Contenu |
|---|---|---|
| `ci-mobile` | PR touchant `apps/mobile`, `packages/design_tokens` | format, analyse, tests unitaires/widget/golden, build Android debug |
| `ci-web` | PR touchant `apps/admin`, `apps/web`, `packages/*` | lint, typecheck, tests, build |
| `ci-db` | PR touchant `supabase/` | `supabase start`, `db reset` depuis zéro, pgTAP, lint SQL, advisors de sécurité |
| `ci-content` | PR touchant `packages/content_tools`, `shared_contracts` | tests du parseur (fixtures synthétiques), tests de contrat |
| `security` | PR + hebdomadaire | gitleaks, revue des dépendances, `pnpm audit`, osv-scanner (Dart) |
| `deploy-staging` | merge sur `main` | migrations staging, déploiement admin/web staging, build mobile interne (manuel au début) |
| `deploy-prod` | tag `v*` + approbation de l'environnement `production` | migrations prod, déploiement web, builds signés vers TestFlight / Play (piste interne puis production) |
| `ios-build` | tag ou déclenchement manuel | runner macOS : build iOS signé (clé API App Store Connect en secret) |
| `backup` | hebdomadaire | dump logique de la base prod chiffré vers R2 |

---

## 12. Stratégie de synchronisation offline-first

### 12.1 Catalogue (lecture seule, serveur-autoritaire)

1. **Publication** (back-office) : un éditeur publie → `publish_release()` crée la release `N`
   (numéro croissant), copie les cantiques validés dans `published_hymns(release_id, hymn_id,
   payload jsonb, payload_hash)` et calcule le diff avec `N-1` (ajoutés, modifiés, retirés).
2. **Snapshot embarqué** : à chaque build, la CI exporte la release publiée courante en
   `catalog_snapshot.json.gz` (+ numéro de release + SHA-256) dans les assets de l'app.
   Une installation hors connexion dispose donc **immédiatement** de tout le recueil.
3. **Premier lancement** : import du snapshot dans Drift en **une transaction**, construction de
   l'index FTS5, enregistrement de `catalog_release = N`.
4. **Mise à jour** (au démarrage et au retour au premier plan, au plus une fois par heure, et
   uniquement si connecté) : RPC `get_catalog_manifest()` → si la release distante est plus récente :
   - écart faible → `get_catalog_delta(from_release)` : charges utiles complètes des cantiques
     modifiés et identifiants retirés ;
   - écart important ou release locale inconnue → snapshot complet.
   Application **atomique** (transaction), vérification d'empreinte, rollback en cas d'erreur.
   **Le catalogue local n'est jamais vidé avant qu'un remplacement valide soit prêt.**
5. Un cantique retiré d'une release n'est plus listé ni proposé en recherche, mais une référence
   existante (favori, programme) affiche « cantique retiré du recueil » au lieu de planter.

### 12.2 Données utilisateur (favoris, listes, programmes)

- Identifiants **UUID générés côté client** ; toutes les écritures vont d'abord dans SQLite.
- Chaque mutation ajoute une entrée à une table **outbox** (`entity, entity_id, op, payload,
  created_at, attempts`).
- **Push** : quand le réseau et la session sont disponibles, l'outbox est vidée dans l'ordre
  (upserts protégés par RLS, idempotents). Backoff exponentiel en cas d'échec.
- **Pull** : `sync_pull(since_revision)` renvoie les lignes de l'utilisateur dont
  `server_revision` (séquence attribuée **par le serveur** via trigger, insensible aux horloges
  des appareils) est supérieure au curseur local, **tombstones incluses** (`deleted_at`).
- **Conflits** : last-write-wins par ligne selon l'ordre de réception serveur. Les listes et les
  programmes sont traités **comme un tout** pour l'ordre des éléments (le dernier ordre écrit
  l'emporte), ce qui évite les fusions d'ordre incohérentes. Les favoris sont fusionnés par union.
- **Visiteur → compte** : à la première connexion, les favoris locaux sont rattachés au compte et
  poussés ; union avec les données distantes. Les visiteurs n'ont ni listes ni programmes (Q-05).
- **Déconnexion** : choix explicite de conserver ou d'effacer les données locales.
- Indicateurs UX : « synchronisation en attente (n) », « hors connexion », « dernière synchro ».

### 12.3 Tests associés

Tests unitaires du moteur avec un faux serveur (réordonnancement, suppression concurrente,
outbox rejouée deux fois = idempotent, interruption pendant l'application d'un delta) ; test
d'intégration « mode avion » (couche réseau qui lève systématiquement une erreur) ; protocole
manuel en mode avion réel sur appareils (Phase 10).

---

## 13. Stratégie d'import du catalogue

```text
.docx source ──► [1] Extraction ──► paragraphs.json (texte, sauts w:br, mise en forme, index de paragraphe)
                 [2] Structuration (règles déterministes, 2 régimes) ──► catalog.draft.json (contrat Zod)
                 [3] Détection d'anomalies ──► report.json + report.html (A-xx, sévérité)
                 [4] Contrôles : fidélité aller-retour, index alphabétique, numérotation
                 [5] Upload dans le back-office (session éditeur, RLS) ──► import_batch + cantiques en DRAFT
                 [6] Revue humaine (REVIEW) ──► corrections ──► validation
                 [7] Publication ──► release de catalogue (PUBLISHED)
```

Règles :
- **Aucune ressaisie manuelle** ; **aucune invention** : `people`, `themes`, tonalités restent
  vides ; `opening_line` = premier vers réel ; `title` = titre imprimé tel quel.
- Texte conservé **verbatim** (seule normalisation : Unicode NFC) ; espaces insécables préservés.
- Références : `display_text` verbatim, décomposition `book/chapter` proposée et marquée `draft`.
- `NNbis` → relation `bis_of` (même mélodie) **proposée** en brouillon, conformément à la note
  liminaire.
- Répétitions : `(bis)`, `(ter)`, `(Nx)`, `(x N)`, `(N x)` reconnus et annotés ; toute autre
  parenthèse reste du texte et lève une anomalie A-10 pour contrôle.
- **Provenance** : nom et SHA-256 du fichier source, plage de paragraphes (`source_paragraph_start/end`),
  version du parseur — conservés sur chaque cantique et dans `import_batches`.
- **Réimport idempotent** : correspondance par `(edition, number_label)` ; diff présenté à
  l'éditeur (nouveau / modifié / inchangé / absent) ; un cantique déjà revu n'est **jamais**
  écrasé silencieusement.
- **Test de fidélité aller-retour** : la reconstitution des vers depuis le catalogue structuré
  doit être identique, ligne à ligne, au texte source pour 100 % des cantiques.
- Tests en CI sur des **fixtures .docx synthétiques** reproduisant les deux régimes, les `w:br`,
  les refrains, les `bis` (aucun contenu protégé dans le dépôt).
- Les tableurs de corrections (A-13) ne sont pas appliqués ; import optionnel sous forme de
  suggestions rattachées par texte, et non par numéro (Q-04).

---

## 14. Plan de sécurité Supabase / RLS

**Rôles applicatifs** (`app_role` : `editor`, `super_admin`), en plus de `anon` et `authenticated` :

| Acteur | Catalogue publié (`published_hymns`, RPC catalogue) | Tables éditoriales (`hymns`, `hymn_sections`, …) | Données utilisateur | Rôles / config |
|---|---|---|---|---|
| Visiteur (`anon`) | Lecture via RPC/vues publiées uniquement | Aucun accès | — | — |
| Utilisateur (`authenticated`) | Lecture | Aucun accès | CRUD **sur ses propres lignes** uniquement (`user_id = auth.uid()`) | — |
| Éditeur (`editor`) | Lecture | Lecture/écriture ; import ; transitions draft→review→published ; publication de release | Ses propres lignes | — |
| Super admin (`super_admin`) | Lecture | Tout ce que fait l'éditeur + archivage | Ses propres lignes | Gestion des rôles, configuration, droits |

Mesures :
- [ ] RLS **activée sur toutes les tables** du schéma `public` ; refus par défaut ; `REVOKE` explicite
      des privilèges d'`anon` sur les tables éditoriales.
- [ ] `has_role(role)` : `SECURITY DEFINER`, `search_path` figé, `STABLE`, placée dans un schéma
      **non exposé** (`private`) avec `REVOKE EXECUTE ... FROM PUBLIC` (une fonction
      `SECURITY DEFINER` dans `public` serait appelable par `anon`) ; utilisée dans les politiques
      et revérifiée côté serveur Next.js. Les RPC publiques réellement nécessaires
      (`get_shared_program`, catalogue) sont auditées une par une.
- [ ] Vues créées `WITH (security_invoker = true)` (sinon elles contournent la RLS).
- [ ] Politiques : `TO authenticated` **toujours** combiné à un prédicat de propriété
      (`(select auth.uid()) = user_id`) ; `UPDATE` avec `USING` **et** `WITH CHECK` ; jamais
      `auth.role()` ni `user_metadata` pour une décision d'autorisation.
- [ ] Clés : clé **publishable** côté clients (les clés `anon` historiques ne servent qu'à la
      compatibilité) ; CI et MCP avec des **jetons d'accès personnels restreints** au projet,
      jamais un jeton complet de compte.
- [ ] `supabase db advisors` sans alerte avant chaque migration fusionnée.
- [ ] Transitions de statut via fonctions SQL contrôlant le rôle et la transition autorisée (pas
      d'`UPDATE status` direct).
- [ ] `audit_log` alimentée par triggers (utilisateur, date, table, id, action, diff minimal).
- [ ] Liens publics : jeton ≥ 128 bits, révocable, expirable ; RPC `get_shared_program(token)`
      renvoyant uniquement titre, date, éléments ; aucun identifiant ni e-mail du propriétaire ;
      réponse identique pour « inexistant » et « révoqué » (pas d'énumération).
- [ ] Projection locale (ADR-013 révisé) : serveur local actif uniquement pendant une session,
      jeton aléatoire de session dans l'URL, écran en lecture seule, commandes acceptées seulement
      depuis l'app pilote ; aucune donnée de compte exposée.
- [ ] Back-office : client Supabase **côté serveur** avec la session de l'utilisateur (`@supabase/ssr`),
      **MFA TOTP obligatoire** pour `editor` et `super_admin`, CSP stricte, en-têtes de sécurité,
      validation Zod de toutes les entrées, protections CSRF des Server Actions.
- [ ] Aucune clé `service_role` dans les apps ni dans les variables publiques (`NEXT_PUBLIC_*`) ;
      contrôle automatisé en CI (grep + gitleaks).
- [ ] Secrets : environnements GitHub (`staging`, `production`) avec reviewers obligatoires ;
      `.env.example` documenté ; coffre du propriétaire pour les secrets maîtres.
- [ ] HTTPS uniquement (HSTS sur les domaines web).
- [ ] Données personnelles minimales (pas d'e-mail dupliqué) ; suppression de compte in-app ;
      politique de confidentialité ; conformité à la loi ivoirienne n° 2013-450 sur les données
      personnelles **à vérifier par le propriétaire**.
- [ ] Tests pgTAP : matrice acteurs × tables × opérations (anon, utilisateur A, utilisateur B,
      éditeur, super admin).
- [ ] Advisors de sécurité Supabase sans erreur en CI.

---

## 15. Design System

- Source unique : `packages/design_tokens/tokens.json` → `tokens.g.dart` + `tokens.css`.
- **Direction (Q-11)** : pur et épuré, **basé sur le blanc**. Beaucoup d'espace, filets fins,
  aucune ombre marquée, aucun dégradé ; l'épi doré est la seule touche identitaire.
- **Couleurs** (contrastes vérifiés automatiquement en CI) :

  | Token | Valeur | Usage | Contraste sur blanc |
  |---|---|---|---|
  | `background` | `#FFFFFF` | fond | — |
  | `surface` | `#FAFAF8` | cartes, barres | — |
  | `hairline` | `#ECE8E2` | filets, séparateurs | décoratif |
  | `text` | `#1F1A17` | paroles, titres | ≈ 17:1 (AAA) |
  | `textSecondary` | `#6B625B` | métadonnées, libellés | ≈ 6:1 (AA) |
  | `gold` | `#B08D57` | épi, icônes, état actif | ≈ 3:1 (graphismes uniquement, **jamais du texte**) |
  | `goldText` | `#8A6A35` | liens/accents textuels rares | ≈ 5:1 (AA) |

  Thème sombre (« veillée », fond `#121110`) et thème **projection** (texte blanc sur noir,
  contraste maximal) dérivés des mêmes tokens.
- **Typographie (proposition Q-12, polices sous licence libre SIL OFL)** :
  - **Cormorant Garamond** — numéros de cantiques, titres d'écran, mot-symbole : élégance
    classique, écho de la couverture (Baskerville) sans contrainte de licence ;
  - **Literata** — paroles : dessinée pour la lecture longue sur écran, très lisible de 16 à 34 pt
    et en projection ; italique soignée pour les refrains (fidèle au livre) ;
  - **Inter** — interface (boutons, onglets, champs) : neutre et épurée, s'efface devant le texte.
  - Échelle typographique modulaire ; taille de lecture réglable (16 à 34 pt) ; respect de la
    taille de police système. Polices embarquées dans l'app (pas de téléchargement au runtime :
    fonctionnement hors connexion).
- **Photos** : Pexels (licence Pexels : usage libre, y compris commercial, sans attribution
  obligatoire). Usage parcimonieux (splash, à propos). Chaque photo est consignée dans
  `docs/ownership/assets.md` (URL source, auteur, date).
- **Espacements / rayons / élévations / durées** : échelles nommées uniquement.
- **Composants** : `HymnNumber`, `HymnTitle`, `VerseBlock`, `RefrainBlock` (retrait + italique,
  fidèle au livre), `RepeatMarker`, `BibleReference`, `WheatDivider` (épi en séparateur, écho du `✤`),
  `SearchField`, `ResultTile` (avec extrait), `EmptyState`, `ErrorState`, `OfflineBanner`,
  `SyncStatus`, `AppScaffold`.
- Règle : aucune couleur, taille ou espacement en dur dans le code des features (lint personnalisé
  ou revue de code).
- Accessibilité : contraste AA partout, **AAA pour les paroles** ; cibles tactiles ≥ 48 dp ;
  sémantique pour les lecteurs d'écran.

---

## 16. Stratégie de qualité et de tests

| Niveau | Outils | Périmètre minimal |
|---|---|---|
| Lint / format | `dart format`, `flutter analyze` (règles strictes), ESLint, Prettier, `tsc --strict`, sqlfluff ou squawk | Bloquant en CI |
| Unitaires Dart | `flutter_test` | normalisation de recherche, classement, parsing des répétitions, ordre chanté, moteur de sync, application des deltas |
| Widget / golden | `flutter_test` + golden | composants du design system, fiche cantique (refrain, bis, référence absente) |
| Intégration Flutter | `integration_test` (+ Patrol si besoin de basculer le mode avion sur émulateur) | parcours Fidèle, **mode avion**, favori hors ligne puis sync, programme |
| Migrations Drift | `drift_dev schema dump/steps` + tests de migration | toutes les versions de schéma local |
| Base | pgTAP (`supabase test db`) | RLS, transitions, RPC catalogue, partage, `db reset` depuis zéro |
| Contrats | JSON Schema partagé, fixtures validées en TS **et** en Dart | catalogue, delta, programme partagé, projection |
| Import | Vitest + fixtures .docx synthétiques | deux régimes, `w:br`, refrains, bis, références, fidélité aller-retour |
| Web | Vitest + Testing Library ; Playwright E2E | parcours Admin (T-009), projection 2 contextes (T-008), lien public (T-007) |
| Sécurité | gitleaks, revue des dépendances, audit RLS | à chaque PR |
| Recette | cahier de recette T-001..T-010 exécuté sur iPhone, Android, tablette | Phase 10 |

Règles : on ne désactive ni ne contourne jamais un test pour le faire passer ; tout bug corrigé
est accompagné d'un test de non-régression.

---

## 17. Plan de développement détaillé

### PHASE 0 — Audit des documents et du repository

- [x] Localiser et inventorier les documents (aucun repository existant)
- [x] Lire intégralement le cahier des charges, la spécification technique et le schéma SQL
- [x] Analyser le recueil source v8 (structure, volumétrie, anomalies) avec un prototype jetable
- [x] Comparer les versions v7 et v8 et les tableurs éditoriaux (renumérotation détectée)
- [x] Examiner les assets graphiques (couvertures, polices, palettes)
- [x] Vérifier la cohérence entre documents (C-01..C-19)
- [x] Rédiger `IMPLEMENTATION_PLAN.md`
- [x] **Validation du plan par le propriétaire et réponses aux questions bloquantes** (2026-10-17, voir §6.0)

**Critère d'acceptation** : plan validé explicitement par le propriétaire.

---

### PHASE 1 — Architecture et organisation du repository

- [x] 1.1 Checklist de propriété : `docs/ownership/accounts.md` (comptes, règles, transfert) et `docs/ownership/assets.md` (polices, photos)
- [!] 1.2 Organisation GitHub du propriétaire, dépôt privé, protections de `main` — **bloqué** : nécessite l'adresse e-mail du projet puis la création de l'organisation par le propriétaire. CODEOWNERS et modèle de PR sont prêts
- [x] 1.3 Squelette du monorepo (§10), `README.md`, `.editorconfig`, `.gitignore`, `.gitattributes`, `.env.example` ; `git init` local (aucun commit)
- [x] 1.4 Outillage épinglé : Flutter 3.47.7 (`.fvmrc`), Node 24 LTS (`.nvmrc`), pnpm 10.34.7 (`packageManager` + empreinte), CLI Supabase 2.121.0 (CI) ; `tools/bootstrap.sh` testé
- [x] 1.5 Workspace pnpm + Turborepo
- [~] 1.6 App Flutter (`apps/mobile`, iOS + Android) : Riverpod, go_router, l10n FR (ARB), analyse stricte, thème construit depuis les tokens, configuration d'environnement validée (`--dart-define-from-file`). Identifiant `org.louangesadieu.app` appliqué (Android `applicationId`/`namespace`, iOS `PRODUCT_BUNDLE_IDENTIFIER`) et nom affiché « Louanges à Dieu ». **Restent** : (a) flavors natifs (identifiants distincts par environnement, ex. `org.louangesadieu.app.staging`), qui nécessitent Xcode ; (b) build Android vérifié uniquement en CI (pas de SDK Android sur le poste)
- [x] 1.7 Apps Next.js 16 `admin` et `web` : TS strict, ESLint, Prettier, Vitest, tokens CSS branchés, `noindex` ; lint, types et build verts
- [x] 1.8 `packages/shared_contracts` : contrat `PublishedHymn` (Zod 4 → JSON Schema), règle « inconnu = null, jamais de chaîne vide », 7 fixtures synthétiques partagées
- [x] 1.9 `packages/design_tokens` : `tokens.json` (blanc épuré, 3 thèmes, typographie Q-12), générateurs Dart et CSS, contrôle des contrastes et de fraîcheur des fichiers générés
- [x] 1.10 `supabase init` fait (`supabase/config.toml`). Décision du propriétaire : la base de développement est le projet cloud `ssvhoqpvxvfkhwxkewwl` (Postgres 17.11), **lié** (`supabase link`) et vérifié (connexion, base vide, aucune migration). La stack Docker locale devient facultative ; la CI utilise Docker sur les runners GitHub. Secrets stockés hors dépôt (`~/.config/louanges-a-dieu/supabase.env`, droits 600)
- [~] 1.11 CI `.github/workflows/ci.yml` (un workflow, filtres de chemins, job agrégateur `ci-ok` à exiger dans la protection de branche) : validée par actionlint et rejouée localement étape par étape. **Reste** : première exécution réelle sur GitHub (dépend de 1.2)
- [~] 1.12 Conventional Commits vérifiés sur le titre de PR (fusion en squash, donc sans commitlint) ; configuration Renovate prête. **Reste** : installation de l'app Renovate sur l'organisation (dépend de 1.2)
- [x] 1.13 ADR-001 à ADR-019 rédigés dans `docs/architecture/adr/`

**Rapport Phase 1 (2026-10-17)**

- Tests exécutés : design tokens 12/12 ; contrats 13/13 ; Flutter 11/11 (`flutter test`) ; `flutter analyze` sans problème ; Turborepo lint + types + tests + build 14/14 ; Prettier ; fichiers générés à jour ; actionlint ; gitleaks sur les fichiers stagés : aucune fuite ; `pnpm audit --prod` : aucune vulnérabilité.
- Problèmes rencontrés :
  - Homebrew ne fournit plus de binaires précompilés pour macOS 14 (compilation depuis les sources) : Node, la CLI Supabase et Flutter ont été installés depuis les binaires officiels, dans `~/.local`, avec vérification des sommes de contrôle.
  - TypeScript 7 (compilateur natif) est incompatible avec typescript-eslint : TypeScript épinglé en 6.0.x (règle Renovate).
  - `pnpm audit` complet : une alerte élevée (`braces`, via `eslint-config-next`) sans version corrigée, limitée à l'outillage de lint. Audit des dépendances livrées bloquant en CI ; audit de l'outillage informatif.
  - Les apps web n'ont pas encore de tests (aucune logique) : `vitest --passWithNoTests` jusqu'aux Phases 7 à 9.

**Critères d'acceptation**
- Un clone neuf + `tools/bootstrap` installe tout ; lint et tests passent en local **et** en CI.
- gitleaks vert ; aucun secret dans l'historique.
- Une PR de test démontre que `main` est protégée (merge impossible sans CI verte).
- ADR fusionnés.

---

### PHASE 2 — Base PostgreSQL, migrations et RLS

> Base de développement : projet Supabase `ssvhoqpvxvfkhwxkewwl` (PostgreSQL 17.11).
> Migrations dans `supabase/migrations/` (0001 → 0012), tests dans `supabase/tests/`.

- [x] 2.1 `baseline_v1` : schéma V1 **tel que fourni** (identique au fichier source, hors en-tête)
- [x] 2.2 `structural_fixes` : `edition_id NOT NULL`, triggers `updated_at`, `unaccent` + `private.f_unaccent()` immuable, colonnes `search_vector` + index GIN, contraintes « jamais de chaîne vide » (espaces insécables compris), libellé de numéro cohérent, ordre unique **différable**, index des clés étrangères. **C-02 résolu autrement que prévu** : les marqueurs `(bis)`… restent dans le texte et l'annotation par ligne est **dérivée à la publication** (aucune colonne à maintenir, une seule implémentation)
- [x] 2.3 `roles` : `app_role`, `user_roles`, `private.has_role()` (schéma non exposé, `SECURITY DEFINER`, `search_path` figé)
- [x] 2.4 `profiles` : `app_users` → `profiles` lié à `auth.users`, e-mail non dupliqué, création automatique à l'inscription, suppression en cascade
- [x] 2.5 `editorial_workflow` : `audit_log` + triggers, `import_batches` / `import_issues`, transitions contrôlées, **retour automatique en brouillon** à toute modification d'un cantique validé, refus de validation (sans section, anomalie bloquante, droits restreints), validation par lots `set_hymns_status` (Q-03)
- [x] 2.6 `editorial_policies` + `catalog_releases` : accès éditeur uniquement à la copie de travail ; releases immuables, `publish_release()` idempotente avec report de la version publiée (T-009) ; RPC `get_catalog_manifest`, `get_catalog_snapshot`, `get_catalog_delta`
- [x] 2.7 `user_data_sync` : `server_revision` (séquence serveur) + verrou par utilisateur, pierres tombales, RPC `sync_push_*` / `sync_pull`
- [x] 2.8 `sharing` : jeton 192 bits, révocation, expiration, régénération ; `get_shared_program` (numéros et titres publiés, Q-09)
- [ ] ~~2.9 `0009_projection.sql`~~ — retiré du MVP (ADR-013 révisé : projection locale, sans état serveur)
- [x] 2.10 Droits (Q-02) : statut effectif `private.effective_rights_status()` + vue `hymn_rights` (`security_invoker`) ; un cantique `restricted` ne peut pas être validé et est exclu des releases (contrôle à la validation et à la publication plutôt qu'une vue `publishable_hymns`)
- [x] 2.11 RLS sur toutes les tables, refus par défaut, droits explicites. Correctif `function_privileges` (0011) : retrait du droit `PUBLIC` sur les fonctions, détecté par les tests
- [x] 2.12 Tests pgTAP : **124 tests** (couverture de sécurité globale, rôles, workflow, releases, synchronisation, partage) ; exécuteur `tools/pgtap` sans Docker
- [x] 2.13 `supabase/seed.sql` : catalogue de démonstration **synthétique** passant par le vrai circuit (validation + release)
- [x] 2.14 `docs/architecture/data-model.md` (diagramme), `docs/api/rpc.md`, `docs/architecture/security.md`, `docs/deployment/database-tests.md`

**Critères d'acceptation**
- [x] `supabase db reset` depuis zéro réussit (base de développement : 12 migrations + seed). En CI : à confirmer à la première exécution (dépend de 1.2).
- [x] pgTAP 100 % vert (124/124 après reconstruction depuis zéro), dont : anon ne lit aucun brouillon ; l'utilisateur B ne lit ni ne modifie les données de A ; un non-éditeur ne peut ni importer ni publier ; un jeton révoqué ne renvoie rien ; modifier un cantique publié ne change pas la release courante (T-009).
- [x] Advisors de sécurité Supabase : 0 erreur. 3 avertissements **acceptés et documentés** (`get_shared_program`, `publish_release`, voir `docs/architecture/security.md`).

**Rapport Phase 2 (2026-10-17)**

- Problèmes rencontrés et traités :
  - Deux migrations créées dans la même seconde par la CLI (même version) : renumérotées avant toute application.
  - Nom de politique formaté comme littéral (`%L` au lieu de `%I`) : migration annulée atomiquement, corrigée, réappliquée.
  - **Faille détectée par les tests** : `anon` pouvait exécuter les RPC de synchronisation et de partage (droit `PUBLIC` par défaut de PostgreSQL). Non exploitable (connexion exigée), corrigée par la migration 0011 et verrouillée par un test général.
  - `supabase migration new` lit l'entrée standard hors terminal : une exécution en arrière-plan a enregistré la migration 0012 **vide**. Historique réparé (`migration repair`), migration réappliquée, puis base **reconstruite depuis zéro** pour prouver la cohérence fichiers ↔ base.
  - `supabase test db` exige Docker même en mode distant : exécuteur pgTAP Node ajouté (`tools/pgtap`).
- Certificat CA Supabase versionné (`supabase/ca/prod-ca-2021.crt`, « Supabase Root 2021 CA », expire en 2031) : tests exécutés avec **vérification TLS complète** (124/124).

---

### PHASE 3 — Pipeline d'import des cantiques

> Code : `packages/content_tools` (TypeScript). Guide : `docs/editorial/import.md`.

- [x] 3.1 Contrat `CatalogDraft` (Zod → JSON Schema `catalog-draft.schema.json`) : édition, cantiques, sections, références, relations proposées, anomalies, provenance (fichier, SHA-256, version du parseur)
- [x] 3.2 Extracteur .docx (lecture XML en flux) : texte NFC, sauts manuels `w:br` → vers, alignement, espacements, retraits, bordure, part d'italique/gras (`w:val="0"` respecté), texte supprimé (`w:delText`) ignoré — 22 711 paragraphes en ~0,2 s
- [x] 3.3 Structuration déterministe (numéro, titre, strophes, refrains, références, séparateurs, fin à l'index), deux régimes de mise en forme
- [x] 3.4 Marqueurs de répétition conservés dans le texte ; formes non standard, ambiguës ou en milieu de vers signalées (A-09) ; autres parenthèses signalées (A-10)
- [x] 3.5 Relations `bis_of` proposées (6 sur la v8, toutes vers le bon numéro)
- [x] 3.6 Anomalies A-01 à A-19 (+ A-20/A-21 au réimport), similarité de texte par triplets de mots (A-12) ; rapport `report.html` autonome
- [x] 3.7 Fidélité aller-retour par **relecture indépendante** du XML : 0 écart sur 1 143 cantiques (18 052 vers) ; recoupement avec l'index (0 divergence de numéro) ; continuité de numérotation
- [x] 3.8 Tests : 37 tests unitaires sur .docx **synthétiques** générés à la volée (deux régimes, `w:br`, refrain, bis, référence, index « 1, 4 », italique désactivé, texte supprimé) + 4 tests d'intégration en base (sautés et signalés sans accès base) ; contrôle par mutation (les tests détectent une règle cassée)
- [x] 3.9 CLI `content-tools import` / `load` documentée (`docs/editorial/import.md`)
- [x] 3.10 Exécution sur la v8 réelle et chargement en brouillon dans la base de développement ; rapport d'anomalies remis au propriétaire (`content/out/report.html`, hors Git)
- [ ] 3.11 (Optionnel, Q-04) Import des tableurs de corrections comme suggestions — **non fait** (proposition par défaut : après le MVP)

**Critères d'acceptation**
- [x] Sur v8 : 1 143 cantiques, 6 relations `bis_of`, 9 références, **0** auteur/thème/tonalité, **100 % en `draft`**, 0 release (rien de public sans validation humaine) — vérifié en base.
- [x] Fidélité aller-retour : 100 % des cantiques identiques vers par vers à la source.
- [x] Index alphabétique : 0 divergence de numéro ; anomalies connues présentes (A-01 n° 666, A-04 sauts manuels, A-05 sections longues…).
- [x] Réimport du même fichier : 0 changement, aucun lot créé.

**Rapport Phase 3 (2026-10-17)**

- Résultat de l'import v8 : 0 anomalie bloquante, 87 à vérifier, 43 informations — détail dans `content/out/report.html`.
- Constat d'audit corrigé : le n° 596 n'est pas absent de l'index (erreur du prototype, voir §3.3 et §6.0).
- Doublons (A-12) : la v8 n'en contient plus que 4 paires détectables (dont 788/830, « le même chant noté deux fois » selon l'analyse de septembre) ; les traductions très différentes d'un même chant ne sont pas détectables automatiquement.
- Prettier avait inscrit des espaces insécables **littéraux** (invisibles) dans des expressions régulières : remplacés par des échappements explicites.
- Ajout au contrat : un cantique sans titre détecté (A-19) reçoit son premier vers comme titre, signalé bloquant pour validation humaine.

---

### PHASE 4 — Base SQLite/Drift et synchronisation

> Code : `apps/mobile/lib/core/` ; documentation : `docs/architecture/sync.md`.
> **Décision du propriétaire (option B, 2026-10-17)** : le vrai recueil a été validé et publié
> **techniquement** sur la base de **développement uniquement** (release n° 26, 1 143 cantiques,
> note « Validation TECHNIQUE — NON éditoriale »), pour développer avec le contenu réel. La
> validation éditoriale réelle se fera dans le back-office (Phase 9) ; à ne pas reproduire en
> recette ni en production.

- [x] 4.1 Schéma Drift : catalogue (contenu JSON validé), table FTS5 `hymn_search` (fichier `.drift`), favoris, listes, programmes, `outbox` versionnée, `sync_state` ; clés étrangères actives
- [x] 4.2 Normalisation de recherche `fold()` + **cas de référence partagés** (`packages/shared_contracts/fixtures/search/normalization.json`)
- [x] 4.3 Service de recherche : numéro exact puis préfixe (`37`, `37bis`, `37 BIS`), titre/premier vers puis paroles avec vers verbatim, début de mot, accents et `œ` ignorés, saisie avec guillemets sans risque
- [x] 4.4 `content-tools export-snapshot` (RPC publique, **chaque cantique validé par le contrat Zod**) → `assets/catalog/catalog_snapshot.json.gz` (375 Ko, non versionné) ; import au premier lancement en une transaction. Génération dans les builds de release : Phase 10
- [x] 4.5 Moteur de sync catalogue : manifeste, delta ou instantané, intervalle d'une heure, atomicité, vérification du nombre de cantiques, rejet d'un contenu invalide, aucune exception en cas de panne réseau
- [x] 4.6 Moteur de sync utilisateur : outbox versionnée, envoi puis réception, LWW, pierres tombales, modifications en attente jamais écrasées, favoris de visiteur fusionnés à la connexion — testé avec un serveur simulé (deux appareils) **et avec le vrai serveur et une vraie session** (Phase 6)
- [x] 4.7 Schéma local versionné et figé (`drift_schemas/`) ; test qui échoue si le code s'écarte du schéma sans migration (vérifié par mutation) ; tests de migration générés dès la v2
- [x] 4.8 Tests : contrat Dart sur les fixtures partagées, dépôt, recherche, sync catalogue (**mode avion T-004**), sync utilisateur (**favori hors ligne T-005**), intégration sur le catalogue réel et contre le serveur de développement (sautés et signalés sans données)
- [x] 4.9 Mesures sur le catalogue réel (poste de développement) : décodage + validation 79 ms, import 471 ms, **recherches ≤ 14 ms** (objectif < 100 ms). Mesure sur Android d'entrée de gamme : Phase 10
- [x] 4.10 `docs/architecture/sync.md`

**Critères d'acceptation**
- [x] Installation sans réseau : catalogue complet consultable et recherchable (instantané embarqué, test « mode avion »). Vérification sur appareil réel : Phase 10.
- [x] Release appliquée par delta (ajout, modification, retrait) ; mise à jour incohérente annulée sans altérer le catalogue.
- [x] Envoi rejoué : résultat identique (upsert côté serveur, entrée d'outbox effacée seulement si inchangée).

**Rapport Phase 4 (2026-10-17)** — 89 tests Flutter, 124 tests pgTAP, analyse sans remarque.

- Bout en bout vérifié : un appel HTTPS anonyme avec la clé publishable lit le manifeste ; la lecture directe d'une table de travail est refusée (42501) ; l'app télécharge et installe les 1 143 cantiques.
- Contrat vérifié dans les trois langages sur le même contenu : SQL (payload) → Zod (export) → Dart (import).
- Contrôles par mutation : recherche par début de mot, protection des modifications en attente, garde du schéma local.
- Problèmes rencontrés : identifiants de section non déterministes dans une fixture de test (corrigé) ; premier test de schéma inopérant (il comparait l'instantané à lui-même), détecté par mutation et corrigé ; `anonKey` déprécié au profit de `publishableKey` dans supabase_flutter (aligné sur notre choix de clé).

---

### PHASE 5 — Application Flutter : accueil, recueil, recherche, fiche, lecture

> Décision du propriétaire (option B, 2026-10-18) : sans simulateur sur le poste, une **cible web
> Flutter réservée à la prévisualisation** (non livrée) permet de contrôler les écrans ; captures
> automatisées par Chrome sans interface (CDP), au format téléphone, thèmes clair et sombre.

- [x] 5.1 Design system : polices OFL embarquées (Cormorant Garamond, Literata romain + italique, Inter — 3,8 Mo, polices variables pilotées par `FontVariation`, chiffres alignés pour les numéros), composants (épi, séparateur, en-tête de cantique, strophe, refrain à filet doré, marqueurs de répétition discrets, ligne de liste, états vide/erreur). **Épi provisoire** dessiné par le code, en attendant le tracé de la couverture
- [x] 5.2 Écran de démarrage (installation du recueil, message et nouvel essai sans catalogue ni réseau). Écran de lancement natif (icône, splash) : Phase 10 avec les icônes
- [x] 5.3 Accueil : identité, recherche, **cantique du jour** déterministe (Q-10), raccourcis recueil et favoris (le raccourci « culte » arrive en Phase 7)
- [x] 5.4 Recueil : par numéro (« bis » après leur numéro), A–Z avec intertitres, « aller au numéro » (`37 bis` accepté, numéro absent signalé), défilement rapide
- [x] 5.5 Recherche : résultats groupés (numéro, titres et premiers vers, paroles avec vers trouvé), invite, aucun résultat
- [x] 5.6 Fiche : numéro, titre, strophes, refrain, références si présentes, lien « même mélodie » pour les « bis », auteurs/thèmes **affichés seulement s'ils existent** (T-010), favori
- [x] 5.7 Mode lecture : taille du texte enregistrée, précédent/suivant (glissement et boutons), écran maintenu allumé, option ordre chanté (Q-07, ADR-009)
- [x] 5.8 « À propos du recueil » (note liminaire **extraite verbatim** du .docx v8, sans la puce sur la page 245 — Q-14) ; écran « Hors connexion » (version, nombre de cantiques, dernière vérification, vérification manuelle)
- [x] 5.9 Réglages : apparence (automatique/clair/sombre), taille du texte, licences (dont les polices)
- [~] 5.10 Accessibilité : libellés de lecture d'écran (numéros « 37 bis », refrain, « deux fois » pour `(bis)`), cibles tactiles ≥ 48, taille système respectée, commandes équivalentes au glissement. **Reste** : essai avec VoiceOver/TalkBack sur appareil (Phase 10)
- [x] 5.11 Tests : 9 tests du **parcours fidèle** sur l'application complète (accueil, recherche 37bis → fiche → favori → favoris, refrain et T-010, paroles T-003, aucun résultat, recueil et « aller au numéro », mode lecture, à propos) ; contrôle visuel par captures (aperçu web). Les tests « golden » ont été écartés : leur rendu dépend du système (macOS/Linux) et casserait la CI
- [!] 5.12 Distribution interne (TestFlight / Play) — **bloquée** : comptes stores (Q-17, R-16)

**Critères d'acceptation**
- [x] T-001 (app sans compte), T-002 (numéro, dont `37bis`), T-003 (paroles avec extrait), T-010 (aucun champ inconnu) : tests automatisés verts.
- [x] T-004 (mode avion) : couvert par les tests de synchronisation (Phase 4) et l'instantané embarqué. Vérification en mode avion réel sur appareil : Phase 10.
- [x] Recherche < 1 s (≤ 14 ms mesurés sur le catalogue réel, Phase 4).

**Rapport Phase 5 (2026-10-18)** — 106 tests Flutter, analyse sans remarque.

- Vérifié visuellement sur le **vrai recueil** (téléchargé par l'aperçu web) : accueil, recueil, fiche n° 991, fiche n° 6 (refrain et `(bis)`), thèmes clair et sombre.
- Corrections issues du contrôle visuel : chiffres elzéviriens de Cormorant (« 991 » lu « 99I ») remplacés par des chiffres alignés ; épi redessiné (grains en amande, barbes).
- Problème rencontré : tests d'écran bloqués ou en échec avec Drift. Causes établies : (1) minuteur de fermeture des flux Drift encore actif à la fin du test → démontage dans le test ; (2) mélange temps simulé / temps réel (`runAsync`) qui interbloque Drift → tout reste dans le temps simulé, attente pilotée par `settle()` (`test/support/app_harness.dart`, documenté dans `apps/mobile/README.md`).

---

### PHASE 6 — Favoris et listes

- [x] 6.1 Favoris locaux (visiteur, hors connexion) : bouton sur la fiche **et en mode lecture** (cantique affiché), onglet Favoris ; pour un visiteur, l'onglet « Listes » invite à se connecter (Q-05)
- [~] 6.2 Compte : connexion **sans mot de passe** par e-mail (lien qui rouvre l'app — schéma `org.louangesadieu.app://login-callback/` déclaré sur Android et iOS — ou code), déconnexion (listes et programmes retirés de l'appareil, favoris gardés au choix, avertissement s'il reste des modifications non envoyées), **suppression de compte** (migration 0013, fonction `delete_my_account`). **Reste (propriétaire)** : autoriser les adresses de retour et brancher un service d'envoi d'e-mails (voir `docs/deployment/auth-email.md`) — sans cela, la connexion par e-mail ne peut pas aboutir
- [x] 6.3 Listes : créer, renommer, supprimer, ajouter depuis la fiche (nouvelle liste à la volée, doublon signalé), réordonner par glisser-déposer **et** par « Monter / Descendre » (accessibilité), retirer
- [x] 6.4 Synchronisation branchée : à la connexion, quelques secondes après chaque modification, et à la demande ; fusion des favoris de visiteur à la première connexion
- [x] 6.5 États : modifications en attente, synchronisation en cours, échec (données conservées sur l'appareil), liste vide, aucune liste
- [x] 6.6 Tests : 5 tests d'écran (invitation visiteur, connexion avec e-mail et code invalides, listes de bout en bout, déconnexion, suppression) avec un service de connexion simulé ; **test de bout en bout avec une vraie session Supabase** (deux appareils, favoris, liste ordonnée, programme, retrait propagé, puis suppression réelle du compte) ; pgTAP 07_account_deletion

**Critères d'acceptation**
- [x] T-005 : favori ajouté hors ligne, conservé, puis envoyé (Phase 4) ; fusion à la connexion.
- [x] Deux appareils sur le même compte voient les mêmes listes après synchronisation — **vérifié avec le vrai serveur**.
- [x] Aucune perte de données hors connexion ; conflits selon §12.2 (tests Phase 4).
- [!] Connexion d'un utilisateur réel par e-mail : dépend de la configuration Auth (6.2).

**Rapport Phase 6 (2026-10-18)**

- Contrainte découverte : le projet Supabase (créé après juin 2026, offre gratuite, envoi par défaut) **ne peut pas personnaliser ses e-mails** (lien seulement, pas de code) et n'envoie que **2 e-mails par heure**. L'app gère le lien et le code ; un service SMTP dédié est nécessaire avant la production.
- Test réel sans e-mail : `tools/pgtap/create-test-user.ts` crée un utilisateur de test sur la base de **développement uniquement** (mot de passe aléatoire, fichier non versionné).
- Défauts trouvés par les tests et corrigés : contrôleur de texte détruit avant la fin de l'animation de fermeture du dialogue « Nouvelle liste » ; message « Ajouté à… » envoyé avec un contexte déjà démonté ; relecture inutile de la base après création d'une liste.

---

### PHASE 7 — Programme de culte et partage

- [x] 7.1 Modèle : programme (titre, date, statut brouillon / publié / archivé), éléments ordonnés (cantique **ou** moment libre avec intitulé, notes) — tables et synchronisation de la Phase 2/4
- [x] 7.2 UI : nouvel onglet **Culte** (et raccourci sur l'accueil) ; créer, renommer, dater, publier, ajouter un cantique **via la recherche**, ajouter un moment libre, annoter, réordonner (glisser-déposer **et** « Monter / Descendre »), dupliquer, **archiver / désarchiver** (section « Archivés »), supprimer. Réservé aux comptes (Q-05)
- [x] 7.3 Création et édition hors connexion, envoi automatique quelques secondes après chaque modification. Correctif découvert par les tests : la demande de synchronisation partait **dans** la transaction d'écriture (« transaction used after being closed ») ; elle part désormais après
- [~] 7.4 Partage : le bouton « Partager » publie le programme, l'envoie au serveur, puis obtient son lien (migration 0014 `ensure_share_link` : **même lien** à chaque partage, pour ne pas casser les liens déjà envoyés) ; feuille de partage native (`share_plus`), copie, désactivation, création d'un nouveau lien ; hors connexion, message clair. **Reste** : l'expiration est prise en charge et testée côté serveur, mais l'app ne propose pas encore de durée (liens sans expiration, désactivables) — à décider si utile
- [~] 7.5 Page publique `apps/web` `/programme/<jeton>` : rendu serveur à chaque requête, `noindex` (balise + en-tête), `no-referrer`, `no-store`, lecture seule, contenu Q-09 (numéros, titres, moments, notes — ni paroles ni créateur). Les états « expiré / désactivé / non publié » sont **volontairement fusionnés** en un seul message « Programme indisponible » (exigence 7.6 : réponses indistinguables). Voir `docs/deployment/web.md`. **Reste** : lien « ouvrir dans l'app » (Q-09) — nécessite le domaine définitif et les liens universels (Phase 9) ; déploiement Vercel (compte propriétaire)
- [~] 7.6 Tests : 5 tests d'écran (invitation visiteur, **T-006**, **T-007**, partage hors connexion, archivage) ; pgTAP 08 (réutilisation du lien, isolation entre comptes) ; 13 tests web (jeton, appel avec la seule clé publique, rendu) ; **test avec le vrai serveur** : lien réutilisé, désactivé, dépublié, expiré et jeton au hasard → même réponse, aucune donnée du créateur ; contrôle HTTP et visuel de la page compilée. **Reste** : E2E Playwright en CI (Phase 10)

**Critères d'acceptation** : T-006 et T-007 verts ; la page publique n'expose ni l'identité ni l'e-mail du créateur ; un lien révoqué est inopérant immédiatement.

- [x] T-006 et T-007 : tests automatisés verts.
- [x] Aucune donnée du créateur dans la réponse publique — **vérifié avec le vrai serveur**.
- [x] Lien désactivé inopérant immédiatement (lecture sans cache) — **vérifié avec le vrai serveur**.

---

### PHASE 8 — Projection

> Q-08 : Internet n'est pas fiable pendant les cultes → **aucune dépendance au cloud pendant la projection** (ADR-013 révisé).

- [~] 8.0 Preuve de faisabilité — **sur ordinateur, vérifiée automatiquement** : le serveur local de l'app (même code `dart:io`) sert l'écran à un vrai Chrome ; T-008 sans rechargement (6–7 ms), coupure puis reprise, aucune requête externe (résultats et décisions dans ADR-013 : code de session court de 8 caractères, port stable 47100, arrêt/relance sur iOS en arrière-plan). Correctif : autorisation `INTERNET` absente du manifeste Android principal (la version publiée n'aurait eu aucun accès réseau). **Reste** : essais sur appareils réels (point d'accès, autorisation « réseau local » iOS, arrière-plan) — liste de contrôle dans `docs/architecture/projection.md` ; ce poste n'a ni SDK Android ni Xcode complet
- [x] 8.1 Contrat de diapositives en Dart **et** TypeScript, mêmes 7 fixtures : titre, une section par diapositive (découpe équilibrée au-delà de 6 vers), refrain répété après chaque couplet (Q-07, désactivable), notes non projetées, moments libres d'un programme ; écran noir dans l'état de projection
- [x] 8.2 Écran projeté (`apps/mobile/assets/projection`, servi par l'app) : plein écran au clic, texte ajusté automatiquement, thème projection (tokens générés), polices locales, reconnexion automatique, dernière diapositive conservée (même après rechargement), fin de session. Wake Lock quand le navigateur le permet (pas en `http://` local : la page invite à désactiver la mise en veille)
- [~] 8.3 Pilote : depuis une fiche ou un programme (« Projeter ») ; aperçu fidèle, diapositive suivante, précédente/suivante, liste complète avec saut direct, écran noir, connexion par adresse et **code QR**, compteur d'écrans, écran maintenu allumé, confirmation avant d'arrêter, option « répéter le refrain ». **Reste** : essai sur appareil (avec 8.0)
- [x] 8.4 Mode « ordinateur seul » : `/projection` installable (PWA : manifeste, service worker), recueil complet gardé dans le navigateur (mis à jour quand Internet revient ; une réponse invalide ne remplace jamais la copie), recherche (numéro, titre, premier vers ; normalisation TS vérifiée sur la fixture partagée avec Dart), **programmes préparés depuis leur lien de partage** (aucun compte requis sur l'ordinateur), fenêtre de contrôle + fenêtre projetée (`BroadcastChannel`, **même écran** que celui du téléphone), clavier et télécommandes de présentation. Icône **provisoire** (monogramme) en attendant l'épi
- [~] 8.5 Tests : séquencement (Dart et TS, mêmes fixtures) ; serveur réel ; **navigateur réel** côté téléphone (T-008, coupure et reprise, aucune requête externe) ; 6 tests du pilote ; **ordinateur seul de bout en bout dans Chrome avec serveur web arrêté et réseau coupé** (rechargement, écran projeté, recherche, T-008 en 5–7 ms, écran noir, programme préparé) ; 9 tests de la console. Défauts corrigés grâce à ces tests : erreur serveur brute si la configuration manque sur la page de programme, console restée sur l'ancien cantique au changement de programme, écran projeté non signalé. **Reste** : essais sur appareils réels (8.0) ; exécution de `pnpm e2e` en CI (Phase 10)

**Critères d'acceptation** : T-008 vert (changement sans rechargement complet) ; tout le scénario fonctionne **sans Internet** ; l'écran reprend la diapositive courante après une coupure ; contrôleur et écran sont des interfaces distinctes ; latence < 300 ms en réseau local.

- [x] T-008 : vert (téléphone → navigateur et ordinateur seul).
- [x] Sans Internet : vérifié automatiquement (aucune requête externe ; ordinateur seul avec serveur arrêté et réseau coupé). Sur appareils réels : liste de contrôle à passer.
- [x] Reprise de la diapositive courante après coupure : vérifiée dans un vrai navigateur.
- [x] Contrôleur et écran distincts ; latence mesurée 5–7 ms (boucle locale), à confirmer sur Wi-Fi réel.

---

### PHASE 9 — Back-office éditorial

- [~] 9.1 Connexion sans mot de passe (code par e-mail) + **second facteur TOTP obligatoire, appliqué par la base** (`has_role()` exige `aal2`, migration 0015) ; enrôlement guidé ; page Équipe (super administrateur : attribution par e-mail, retrait, jamais le dernier). **Reste** : l'étape « code par e-mail » ne peut être essayée qu'une fois le service d'e-mail branché (6.2) — le reste du parcours est testé de bout en bout
- [x] 9.2 Tableau de bord par édition : validés, en relecture, brouillons, anomalies (bloquantes, ouvertes), progression de la revue, dernière release
- [x] 9.3 Liste : recherche sans accents (numéro, titre, premier vers, texte des sections), filtres statut / anomalies / droits / édition, pagination
- [x] 9.4 Édition : titre, premier vers, notes internes (vide = inconnu, jamais de valeur fictive), sections (type, numéro, texte, ordre, ajout, suppression ; répétitions par « (bis) », « (ter) », « (4x) » reconnues à l'aperçu), références, cantiques liés, **auteurs et thèmes**, registre des droits
- [x] 9.5 Aperçu « comme sur mobile » : contenu exact d'une publication (`preview_hymn`), mêmes polices et règles d'affichage (rien d'inconnu affiché, T-010)
- [x] 9.6 Workflow appliqué par la base (déclencheurs + RLS) ; transitions proposées selon le statut et le rôle (archivage : super administrateur) ; **validation par lots** (Q-03) avec le motif de chaque refus
- [x] 9.7 Publication : diff de la prochaine release (`preview_release`), publication, historique, **retour arrière** (`rollback_release` : nouvelle release reçue par les apps comme une mise à jour)
- [x] 9.8 File d'anomalies : filtres, résoudre / ignorer (justification obligatoire) / rouvrir, par lot ; auteur de la décision fixé par le serveur
- [x] 9.9 Import : fichier validé par le contrat Zod, **simulation = diff de réimport**, puis import ; logique unique en SQL (`import_catalog_draft`), aussi utilisée par `content-tools load` (ses tests d'intégration passent sur le portage)
- [x] 9.10 Journal : toutes les modifications avec l'auteur, filtrable par objet, historique sur chaque cantique
- [x] 9.11 Registre des droits : statut, détenteur, licence, validité, notes ; le plus récent fait foi ; « restreint » bloque validation et publication
- [x] 9.12 Sécurité : CSP stricte à nonce, en-têtes (DENY, nosniff, no-referrer, noindex, no-store, HSTS), Zod sur toutes les actions, pas de redirection ouverte, aucune clé secrète ; limitation de débit par Supabase Auth (limite commune à l'équipe, documentée dans `docs/deployment/admin.md`)
- [x] 9.13 Tests : pgTAP 09 (194 au total), 11 tests unitaires, **accès par l'API réelle** (anonyme, sans rôle, éditeur sans second facteur : aucun accès), **parcours administrateur de bout en bout dans Chrome** (second facteur, import, lots, publication, T-009, retour arrière, auteurs et thèmes, anomalie, journal, équipe, aucune violation de CSP)

**Critères d'acceptation** : T-009 vert ; un utilisateur sans rôle ne peut ni lire les brouillons ni publier, y compris en appelant l'API directement ; chaque modification apparaît dans le journal.

- [x] T-009 : vert (pgTAP et parcours de bout en bout).
- [x] Sans rôle (et même avec un rôle mais sans second facteur) : ni lecture des brouillons ni publication, **vérifié contre l'API réelle**.
- [x] Chaque modification apparaît dans le journal, avec son auteur.

---

### PHASE 10 — Tests, sécurité, optimisation, préparation production

- [ ] 10.1 Exécution du cahier de recette T-001..T-010 sur iPhone, Android et tablette ; rapport dans `docs/qa/`
- [ ] 10.2 Protocole mode avion manuel (installation, première ouverture, recherche, lecture, favoris, programme) + automatisé
- [ ] 10.3 Revue de sécurité : audit RLS, advisors, dépendances, secrets, test des liens publics et du back-office
- [ ] 10.4 Performance : démarrage à froid, latence de recherche, taille de l'app, latence de projection
- [ ] 10.5 Observabilité : crash reporting (Q-16) mobile et web, logs structurés sans données personnelles
- [ ] 10.6 Sauvegardes : sauvegardes Supabase + dump hebdomadaire chiffré vers R2 ; **restauration testée et documentée**
- [ ] 10.7 Stores : icônes, splash, captures, fiche, politique de confidentialité, « App Privacy » / « Data safety », suppression de compte, classification
- [ ] 10.8 Signature : Play App Signing + clé d'upload dans le coffre ; App Store Connect API key ; procédure documentée
- [ ] 10.9 Déploiement production (migrations via environnement approuvé, web, mobile)
- [ ] 10.10 Documentation finale : README, installation locale, variables, déploiement, sauvegarde/restauration, runbook d'incident
- [ ] 10.11 Transfert : checklist de propriété signée (comptes, secrets, domaines, certificats, CI)
- [ ] 10.12 Décision écrite du propriétaire sur les droits (Q-02) avant publication publique

**Critères d'acceptation** : tous les tests T verts sur appareils réels ; restauration vérifiée ; tous les comptes au nom du propriétaire ; aucun secret détenu exclusivement par le développeur.

---

### Piste parallèle — Revue éditoriale (propriétaire)

- [ ] E.1 Confirmer l'édition de référence (Q-01)
- [ ] E.2 Arbitrer les anomalies du rapport d'import (A-01..A-14)
- [ ] E.3 Revoir et valider les cantiques (selon Q-03)
- [ ] E.4 Renseigner le registre des droits (Q-02)
- [ ] E.5 Publier la release 1 du catalogue

---

## 18. Traçabilité de la recette

| Test | Description | Phase | Type de test prévu |
|---|---|---|---|
| T-001 | App ouverte sans compte → recueil accessible | 5 | intégration Flutter + manuel |
| T-002 | Recherche d'un numéro existant (dont `37bis`) | 4–5 | unitaire recherche + widget |
| T-003 | Recherche d'un mot des paroles avec extrait | 4–5 | unitaire FTS + widget |
| T-004 | Mode avion : recherche et lecture | 4–5, 10 | intégration réseau coupé + manuel sur appareils |
| T-005 | Favori hors ligne puis sync | 6 | unitaire sync + intégration |
| T-006 | Créer, ordonner, sauvegarder un programme | 7 | widget + intégration |
| T-007 | Lien public en lecture seule | 7 | pgTAP + E2E Playwright |
| T-008 | Projection précédent/suivant sans rechargement | 8 | E2E Playwright deux contextes |
| T-009 | Modification admin reste en brouillon | 2, 9 | pgTAP + E2E |
| T-010 | Auteur absent → champ masqué | 5 | widget + golden |

---

## 19. Journal du plan

| Date | Version | Changement |
|---|---|---|
| 2026-10-17 | 0.1 | Audit initial et plan (Phase 0). En attente de validation. |
| 2026-10-18 | 0.8 | Phase 6 : compte sans mot de passe, suppression de compte, listes, synchronisation branchée ; test réel à deux appareils. |
| 2026-10-18 | 0.9 | Phase 7 : programmes de culte (onglet Culte, archivage), partage par lien réutilisé (0014), page publique `apps/web` ; tests avec le vrai serveur. |
| 2026-10-18 | 1.0 | Phase 8 : projection sans Internet — diapositives Dart/TS, serveur local et pilote dans l'app, écran projeté partagé, mode ordinateur seul (PWA) ; tests en navigateur réel hors ligne. |
| 2026-10-18 | 1.1 | Phase 9 : back-office éditorial — MFA appliquée par la base, import SQL partagé, diff et retour arrière de release, éditeur avec aperçu mobile, anomalies, journal, équipe ; parcours de bout en bout. |
| 2026-10-18 | 0.7 | Phase 5 : écrans Flutter (accueil, recueil, recherche, fiche, lecture, favoris, réglages, à propos), aperçu web de développement (option B), polices OFL. |
| 2026-10-17 | 0.6 | Phase 4 : base locale Drift + FTS5, recherche, synchronisation catalogue et données utilisateur ; option B (publication technique sur la base de développement). |
| 2026-10-17 | 0.5 | Phase 3 terminée : import v8 (1 143 cantiques, fidélité 100 %) chargé en brouillon ; correction du constat A-02 (n° 596). |
| 2026-10-17 | 0.4 | Phase 2 terminée (12 migrations, 124 tests pgTAP, base reconstruite depuis zéro). En attente : certificat CA, première exécution CI. |
| 2026-10-17 | 0.3 | Phase 1 : tâches 1.1, 1.3–1.5, 1.7–1.9, 1.13 terminées ; 1.6, 1.10–1.12 partielles ; 1.2 bloquée (comptes). |
| 2026-10-17 | 0.2 | Plan validé. Arbitrages §6.0 intégrés : design blanc épuré + typographie, Vercel, projection sans Internet (ADR-013 révisé), pas de listes visiteur, validation par lots, droits `unknown` publiables, comptes stores individuels (R-06, R-16, R-17). Début de la Phase 1. |
