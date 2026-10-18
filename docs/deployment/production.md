# Mise en production (tâche 10.9)

Ordre recommandé. Chaque étape renvoie à sa procédure détaillée.

## 1. Comptes et secrets
Créer les comptes de `docs/ownership/accounts.md` (adresse du projet, double authentification,
coffre). Rien ne doit dépendre d'un compte du développeur.

## 2. Base de données
1. Supabase → nouveaux projets **`louanges-staging`** et **`louanges-prod`** (région
   `eu-west-1`, Postgres 17). Offre **Pro** recommandée pour la production : sauvegardes
   quotidiennes, pas de mise en pause automatique.
2. Environnements GitHub `staging` / `production` : secrets et variables (`accounts.md`, n° 13).
3. Actions → **deploiement-base** → `staging` : aperçu, migrations, avertissements, tests pgTAP.
   Puis → `production` (approbation du propriétaire). Aucune migration n'est appliquée
   autrement (ADR-011).
4. Auth (production) : SMTP Resend et modèles avec `{{ .Token }}` (`auth-email.md`), adresses
   de retour `org.louangesadieu.app://login-callback/` et l'URL du back-office, `Site URL` =
   site public, second facteur TOTP activé (par défaut).

## 3. Back-office et site (Vercel)
1. Deux projets Vercel liés au dépôt : `admin` (racine `apps/admin`) et `web` (racine
   `apps/web`). Variables : `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `APP_ENV=production`,
   `SENTRY_DSN` (facultatif). Domaines : `admin.<domaine>`, `<domaine>` (ou `cantiques.<domaine>`).
2. Premier super administrateur : `admin.md` → « Accès ».

## 4. Catalogue (piste éditoriale du propriétaire)
1. Import du `.docx` v8 : `content-tools import` (poste local) puis **Import** dans le
   back-office : simulation, puis import.
2. Arbitrer les anomalies, valider (par lots), décision écrite sur les droits
   (`docs/ownership/rights-decision.md`), puis **Publication** de la release 1.
3. Instantané embarqué dans l'app : `content-tools export-snapshot` depuis la production.

## 5. Applications mobiles
1. `apps/mobile/config/prod.json` : `APP_ENV=prod`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
   `PUBLIC_WEB_URL` (HTTPS), `SENTRY_DSN` (facultatif). Ce fichier ne contient que des
   valeurs publiques.
2. Signature : `mobile-signing.md`. Builds : `LAD_STORE_BUILD=true flutter build appbundle` /
   `flutter build ipa`, avec `--dart-define-from-file=config/prod.json`.
3. Recette sur appareils (`docs/qa/recette.md`) **avant** soumission.
4. Google : test fermé (≥ 12 testeurs, 14 jours) puis production. Apple : TestFlight puis
   soumission. Fiches et déclarations : `docs/stores/README.md`.

## 6. Exploitation
Sauvegarde hebdomadaire (`backup-restore.md`, premier lancement manuel), observabilité
(`observability.md`), incidents (`docs/operations/incident.md`).
