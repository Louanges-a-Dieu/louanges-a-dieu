# Sécurité de la base de données

Référence : §14 du plan, ADR-010, ADR-011, ADR-012, ADR-018.

## Principes appliqués

- **Refus par défaut** : RLS activée sur toutes les tables ; aucun droit implicite ; chaque
  droit (`grant`) est accordé explicitement, rôle par rôle, dans une migration.
- **Aucun droit `PUBLIC`** sur les fonctions de `public` et `private` (migration 0011).
- **Copie de travail invisible du public** : `anon` ne lit que `catalog_releases` et
  `published_hymns`, et n'exécute que les RPC du catalogue et `get_shared_program`.
- **Rôles** dans `user_roles`, vérifiés par `private.has_role()` (schéma non exposé),
  jamais par `user_metadata`.
- **Données utilisateur** : `TO authenticated` toujours combiné à un prédicat de propriété ;
  `UPDATE` avec `USING` et `WITH CHECK` ; pas de suppression physique par l'API.
- **Vues** en `security_invoker`.
- **Journal** (`audit_log`) alimenté par triggers sur toutes les tables éditoriales.

Ces règles sont vérifiées automatiquement par `supabase/tests/01_security_coverage.test.sql`
pour toute table ou fonction ajoutée plus tard.

## Second facteur obligatoire, appliqué par la base (Phase 9)

`private.has_role()` ne reconnaît un rôle éditorial qu'avec une session `aal2` (code TOTP
vérifié par Supabase Auth). Toutes les politiques RLS éditoriales et les fonctions de
publication, d'import et d'administration passent par elle : une session volée sans second
facteur n'a aucun droit éditorial, même en appelant l'API directement. Vérifié par pgTAP
(`09_admin_backoffice`) et contre l'API réelle (`apps/admin/test/integration`).

## Alertes `supabase db advisors` acceptées

| Alerte | Objet | Justification |
|---|---|---|
| `anon_security_definer_function_executable`, `authenticated_security_definer_function_executable` | `get_shared_program` | Seul point d'entrée public d'un programme partagé : `anon` n'a aucun accès aux tables de programmes. Ne renvoie que titre, date et éléments ; jeton ≥ 192 bits ; réponses indistinguables. Testé (06_sharing). |
| `authenticated_security_definer_function_executable` | `publish_release` | Doit lire toute la copie de travail et écrire le catalogue publié, interdit en écriture directe. Contrôle `has_role('editor')` en tête de fonction. Testé (04_catalog_releases). |
| `authenticated_security_definer_function_executable` | `delete_my_account` | Suppression de compte exigée par les stores : seul le propriétaire de la base peut supprimer une ligne de `auth.users`. Aucun paramètre : l'utilisateur ne supprime que son propre compte (`auth.uid()`). Testé (07_account_deletion). |

| `authenticated_security_definer_function_executable` | `preview_release`, `rollback_release`, `preview_hymn` | Lisent toute la copie de travail et, pour le retour arrière, écrivent le catalogue publié (interdit en écriture directe). Contrôle `has_role('editor')` en tête (donc second facteur exigé). Testé (09, 10). |
| `authenticated_security_definer_function_executable` | `admin_list_team`, `admin_grant_role`, `admin_revoke_role`, `admin_audit_log` | Doivent lire `auth.users` (adresses de l'équipe), inaccessible autrement. Contrôle `has_role('super_admin')` (équipe) ou `has_role('editor')` (journal) ; le dernier super_admin ne peut pas être retiré. Testé (09, 10). |
| `auth_leaked_password_protection` | Auth | Les applications n'utilisent **aucun mot de passe** (code par e-mail, Q-13). Vérification HaveIBeenPwned réservée à l'offre Pro : à activer sur le projet de production s'il passe en Pro. |
| `unused_index` (information) | `hymns_number_idx`, `hymns_search_vector_idx`, `hymn_sections_search_vector_idx`, `favorites_hymn_id_idx`, `playlists_user_id_idx` | Base de développement peu sollicitée. Les deux derniers indexent des clés étrangères (suppressions en cascade, alerte 0001) ; les autres servent les tris et la recherche plein texte du back-office. Coût négligeable (≈ 1 150 cantiques). |

Le test `10_privileged_functions` vérifie que **chaque** fonction privilégiée refuse un compte
sans rôle et un éditeur sans second facteur.

Toute autre alerte de sécurité doit être corrigée avant fusion.

## Revue de sécurité du 2026-10-18 (tâche 10.3)

| Contrôle | Résultat |
|---|---|
| `supabase db advisors` (sécurité, performance) | Uniquement les alertes acceptées ci-dessus |
| RLS | Toutes les tables (test 01), refus par défaut ; 232 tests pgTAP |
| Fonctions privilégiées | Refus vérifié pour compte sans rôle et éditeur sans second facteur (test 10) |
| Second facteur | Exigé par la base (`aal2`), vérifié aussi contre l'API réelle |
| Dépendances livrées (`pnpm audit --prod`) | Aucune vulnérabilité connue |
| Dépendances de développement | `braces` ≤ 3.0.3 (déni de service par expression régulière) via `eslint-config-next` : outil de lint uniquement, motifs maîtrisés, aucun correctif publié — accepté |
| Paquets Dart (`flutter pub get`) | Aucun avis de sécurité |
| Secrets dans l'historique Git complet | Aucun (recherche de clés `sb_secret_`, jetons `sbp_`, JWT, chaînes de connexion, clés privées) ; seuls des `.env.example` sont versionnés |
| Liens publics de programme | Jeton aléatoire, réponses indistinguables, `noindex`, `no-referrer`, `no-store` (tests 06, 08, test réel) |
| Back-office | CSP à nonce, en-têtes, Zod, pas de redirection ouverte ; parcours complet sans violation de CSP |
| Site public | CSP ajoutée lors de cette revue (voir `docs/deployment/web.md`) |
