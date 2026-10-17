# Louanges à Dieu

Prolongement numérique du recueil de cantiques « Louanges à Dieu » (6ᵉ édition, 2026) :
application mobile iOS/Android/tablettes (hors connexion), écran de projection, back-office
éditorial.

> Projet propriété de **Louanges à Dieu**. Dépôt privé — tous droits réservés.

## Contenu du dépôt

| Dossier                     | Rôle                                                                | Stack                             |
| --------------------------- | ------------------------------------------------------------------- | --------------------------------- |
| `apps/mobile`               | Application mobile et tablette                                      | Flutter, Riverpod, Drift (SQLite) |
| `apps/admin`                | Back-office éditorial                                               | Next.js, TypeScript               |
| `apps/web`                  | Écran projeté, pages publiques de programmes                        | Next.js, TypeScript               |
| `packages/shared_contracts` | Contrats de données (Zod → JSON Schema)                             | TypeScript                        |
| `packages/content_tools`    | Import du recueil source                                            | TypeScript                        |
| `packages/design_tokens`    | Design system : source unique des tokens                            | JSON → Dart + CSS                 |
| `supabase/`                 | Migrations, politiques RLS, tests pgTAP                             | PostgreSQL, Supabase              |
| `docs/`                     | Architecture (ADR), API, déploiement, éditorial, propriété, recette | —                                 |

Le suivi d'avancement est dans [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
Les décisions d'architecture sont dans [`docs/architecture/adr/`](docs/architecture/adr/README.md).

## Prérequis

| Outil               | Version                      | Installation (macOS)                                 |
| ------------------- | ---------------------------- | ---------------------------------------------------- |
| Node.js             | LTS 24 (`.nvmrc`)            | `brew install node@24`                               |
| pnpm                | épinglé par `packageManager` | `corepack enable`                                    |
| Flutter             | épinglé par `.fvmrc`         | `brew install fvm` puis `fvm install`                |
| Supabase CLI        | ≥ 2.x                        | `brew install supabase`                              |
| Docker              | récent                       | Docker Desktop (base locale)                         |
| Xcode / Android SDK | récents                      | uniquement pour lancer l'app sur simulateur/appareil |

## Démarrage

```bash
./tools/bootstrap.sh     # installe les dépendances JS et Flutter
pnpm lint && pnpm test   # vérifications TypeScript
```

La documentation détaillée (installation locale, variables d'environnement, déploiement,
sauvegarde/restauration) est dans `docs/deployment/`.

## Règles du projet

- Aucune donnée éditoriale inventée : une valeur inconnue reste `NULL` et n'est pas affichée.
- Aucun secret dans Git ; aucune clé `service_role` dans une application.
- Toute modification passe par une Pull Request avec CI verte (Conventional Commits).
