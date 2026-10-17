# Fonctionnement hors connexion et synchronisation

Référence : ADR-005 (catalogue), ADR-006 (données utilisateur), ADR-007 (recherche).
Code : `apps/mobile/lib/core/` (`database/`, `catalog/`, `search/`, `sync/`, `user_data/`).

## Base locale (SQLite / Drift)

| Table | Contenu |
|---|---|
| `catalog_hymns` | cantiques de la release locale ; contenu complet en JSON (contrat `PublishedHymn`), validé avant insertion |
| `hymn_search` | index plein texte FTS5 (numéro, titre + premier vers, paroles), sur des textes normalisés |
| `favorites`, `playlists`, `playlist_items`, `worship_services`, `worship_service_items` | données personnelles |
| `outbox` | modifications locales en attente d'envoi (une entrée par entité, avec version) |
| `sync_state` | release locale, révision utilisateur, dernière vérification |

Le schéma est versionné (`AppDatabase.currentSchemaVersion`) et figé dans
`apps/mobile/drift_schemas/` ; un test échoue si le code s'en écarte sans migration.

## Catalogue (lecture seule, serveur-autoritaire)

1. **Build** : `content-tools export-snapshot` télécharge la dernière release (RPC publique),
   valide chaque cantique avec le contrat Zod et écrit
   `apps/mobile/assets/catalog/catalog_snapshot.json.gz` (≈ 375 Ko, non versionné).
2. **Premier lancement** : l'instantané embarqué est importé en une transaction
   (≈ 0,5 s pour 1 143 cantiques). Le recueil est consultable **sans réseau**.
   Sans instantané embarqué (build de développement), le catalogue est téléchargé au premier
   accès réseau.
3. **Mises à jour** (au plus une fois par heure) : manifeste → delta (cantiques modifiés et
   retirés) ou instantané complet si l'écart est grand ou la release locale inconnue.
4. **Garanties** : chaque mise à jour est atomique et vérifiée (nombre de cantiques du
   manifeste). Contenu invalide ou incohérent : mise à jour rejetée, catalogue intact.
   Réseau absent : aucune erreur, catalogue intact.

## Recherche (hors connexion)

- **Numéro** : `37`, `37bis`, `37 bis` → correspondance exacte, puis numéros commençant pareil.
- **Texte** : normalisation commune (minuscules, sans accents, `œ` → `oe`, apostrophes,
  ponctuation et espaces insécables neutralisés — cas de référence partagés dans
  `packages/shared_contracts/fixtures/search/normalization.json`), recherche par début de mot,
  titres et premiers vers d'abord, puis paroles avec le vers correspondant (texte verbatim).
- Mesuré sur le catalogue réel : ≤ 14 ms par recherche (poste de développement).

## Données utilisateur

- Toute modification (favori, liste, programme) est écrite **d'abord en local** et ajoutée à
  `outbox` : elle fonctionne hors connexion.
- Synchronisation (compte connecté) : **envoi** de l'état courant de chaque entité en attente,
  puis **réception** des changements depuis la dernière révision (`sync_pull`).
- Une entrée d'`outbox` n'est effacée que si l'entité n'a pas changé pendant l'envoi
  (version) ; une modification locale en attente n'est jamais écrasée par la réception.
- Conflits : la dernière écriture reçue par le serveur l'emporte ; l'ordre d'une liste ou
  d'un programme est remplacé en bloc. Suppressions propagées par pierres tombales.
- Visiteur sans compte : seuls les favoris existent (Q-05) ; ils sont envoyés et fusionnés à la
  première connexion.

## Tests

| Fichier | Couvre |
|---|---|
| `test/core/catalog/` | contrat Dart (fixtures partagées avec Zod), dépôt, deltas, atomicité |
| `test/core/search/` | normalisation (cas partagés), numéros, accents, début de mot, paroles |
| `test/core/sync/catalog_sync_test.dart` | premier lancement, **mode avion (T-004)**, deltas, instantané, contenu invalide |
| `test/core/sync/user_sync_test.dart` | **favori hors ligne (T-005)**, deux appareils, conflits, pierres tombales, envoi interrompu |
| `test/drift/` | schéma local conforme à son instantané versionné |
| `test/integration/` | catalogue réel et serveur de développement (sautés s'ils sont absents) |
