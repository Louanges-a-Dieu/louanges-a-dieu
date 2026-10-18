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

Toute autre alerte de sécurité doit être corrigée avant fusion.
