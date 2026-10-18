# Louanges à Dieu

Prolongement numérique du recueil de cantiques « Louanges à Dieu » (6ᵉ édition, 2026) :
application mobile iOS/Android/tablettes (hors connexion), écran de projection, back-office
éditorial.

> Projet propriété de **Louanges à Dieu**. Dépôt privé — tous droits réservés.

## Contenu du dépôt

| Dossier                     | Rôle                                                                                | Stack                             |
| --------------------------- | ----------------------------------------------------------------------------------- | --------------------------------- |
| `apps/mobile`               | Application mobile et tablette                                                      | Flutter, Riverpod, Drift (SQLite) |
| `apps/admin`                | Back-office éditorial                                                               | Next.js, TypeScript               |
| `apps/web`                  | Pages publiques (programmes, confidentialité), projection « ordinateur seul » (PWA) | Next.js, TypeScript               |
| `packages/shared_contracts` | Contrats de données (Zod → JSON Schema)                                             | TypeScript                        |
| `packages/content_tools`    | Import du recueil source                                                            | TypeScript                        |
| `packages/design_tokens`    | Design system : source unique des tokens                                            | JSON → Dart + CSS                 |
| `packages/observability`    | Journaux d'erreurs sans données personnelles, filtre Sentry                         | TypeScript                        |
| `tools/`                    | Tests de base (pgTAP), comptes de test, navigateur de test, sauvegarde              | TypeScript, shell                 |
| `supabase/`                 | Migrations, politiques RLS, tests pgTAP                                             | PostgreSQL, Supabase              |
| `docs/`                     | Architecture (ADR), API, déploiement, éditorial, propriété, recette                 | —                                 |

Le suivi d'avancement est dans [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
Les décisions d'architecture sont dans [`docs/architecture/adr/`](docs/architecture/adr/README.md).

## Prérequis

| Outil               | Version                      | Installation (macOS)                                            |
| ------------------- | ---------------------------- | --------------------------------------------------------------- |
| Node.js             | LTS 24 (`.nvmrc`)            | `brew install node@24`                                          |
| pnpm                | épinglé par `packageManager` | `corepack enable`                                               |
| Flutter             | épinglé par `.fvmrc`         | `brew install fvm` puis `fvm install`                           |
| Supabase CLI        | 2.121.0                      | `brew install supabase`                                         |
| Docker              | récent                       | facultatif (base locale) ; la CI l'utilise pour les sauvegardes |
| Xcode / Android SDK | récents                      | uniquement pour lancer l'app sur simulateur/appareil            |

## Démarrage

```bash
./tools/bootstrap.sh     # installe les dépendances JS et Flutter
pnpm lint && pnpm typecheck && pnpm test
```

### Variables d'environnement (valeurs publiques uniquement)

| Où                   | Fichier (non versionné)                                       | Variables                                                                             |
| -------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| App mobile           | `apps/mobile/config/<env>.json` (modèle : `dev.example.json`) | `APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `PUBLIC_WEB_URL`, `SENTRY_DSN` |
| Back-office          | `apps/admin/.env.local` (modèle : `.env.example`)             | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SENTRY_DSN`                              |
| Site                 | `apps/web/.env.local` (modèle : `.env.example`)               | idem                                                                                  |
| Outils (base de dev) | `~/.config/louanges-a-dieu/supabase.env`, hors dépôt          | `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`                                       |

Aucune clé secrète ni `service_role` dans une application (ADR-011).

### Lancer

```bash
cd apps/mobile && flutter run --dart-define-from-file=config/dev.json
pnpm --filter @lad/admin dev     # back-office  http://localhost:3000
pnpm --filter @lad/web dev       # site public
```

### Tests

| Commande                         | Contenu                                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| `pnpm test`                      | TypeScript : contrats, import, observabilité, site, back-office (+ API réelle si configurée) |
| `cd apps/mobile && flutter test` | App : unitaires, écrans, projection (serveur et navigateur réels), synchronisation réelle    |
| `node tools/pgtap/run.ts`        | Base : 232 tests de sécurité et de workflow (sur la base de dev, transactions annulées)      |
| `pnpm build && pnpm e2e`         | Navigateur réel : projection hors ligne, parcours administrateur complet                     |

Les tests réels utilisent des comptes de la base de développement :
`node tools/pgtap/create-test-user.ts` et `node tools/pgtap/create-test-editor.ts`
(après `source ~/.config/louanges-a-dieu/supabase.env`).

## Documentation

| Sujet                                                    | Où                         |
| -------------------------------------------------------- | -------------------------- |
| Architecture, sécurité, synchronisation, projection      | `docs/architecture/`       |
| API (fonctions de la base)                               | `docs/api/rpc.md`          |
| Import éditorial                                         | `docs/editorial/import.md` |
| Mise en production, back-office, site, e-mail, signature | `docs/deployment/`         |
| Sauvegarde/restauration, observabilité, incidents        | `docs/operations/`         |
| Recette sur appareils, performance                       | `docs/qa/`                 |
| Stores (fiches, déclarations de données)                 | `docs/stores/`             |
| Comptes, transfert, droits, ressources graphiques        | `docs/ownership/`          |

## Règles du projet

- Aucune donnée éditoriale inventée : une valeur inconnue reste `NULL` et n'est pas affichée.
- Aucun secret dans Git ; aucune clé `service_role` dans une application.
- Toute modification passe par une Pull Request avec CI verte (Conventional Commits).
