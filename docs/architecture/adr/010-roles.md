# ADR-010 — Rôles et autorisation

**Décision.** Rôles applicatifs `editor` et `super_admin` dans `user_roles`. Fonction
`has_role()` (`SECURITY DEFINER`, `search_path` figé, `STABLE`) utilisée par les politiques RLS
et revérifiée côté serveur Next.js. RLS activée sur toutes les tables, refus par défaut.
Tout utilisateur connecté peut créer des programmes (pas de rôle « responsable de culte », Q-06).

**Précisions (2026-10-17, consignes Supabase).** `has_role()` est placée dans le schéma non exposé
`private`, avec `REVOKE EXECUTE ... FROM PUBLIC` puis un `GRANT` explicite aux seuls rôles
nécessaires : une fonction `SECURITY DEFINER` laissée dans `public` serait appelable par `anon`
via l'API. Les politiques combinent toujours `TO authenticated` avec un prédicat de propriété,
et les `UPDATE` déclarent `USING` et `WITH CHECK`.
