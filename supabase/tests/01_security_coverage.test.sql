-- Couverture de sécurité globale : s'applique à TOUTES les tables et fonctions,
-- y compris celles ajoutées plus tard (filet contre les oublis).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is_empty(
  $$ select c.relname
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity $$,
  'RLS activée sur toutes les tables de public'
);

select is_empty(
  $$ select c.relname
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'v'
        and not coalesce('security_invoker=true' = any (c.reloptions), false) $$,
  'toutes les vues de public sont security_invoker'
);

select set_eq(
  $$ select distinct table_name::text from information_schema.role_table_grants
      where grantee = 'anon' and table_schema = 'public' $$,
  array['catalog_releases', 'published_hymns']::text[],
  'anon ne peut lire que les tables du catalogue publié'
);

select is_empty(
  $$ select table_name || ':' || privilege_type from information_schema.role_table_grants
      where grantee = 'anon' and table_schema = 'public' and privilege_type <> 'SELECT' $$,
  'anon n''a aucun droit d''écriture'
);

select set_eq(
  $$ select p.proname::text
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef $$,
  array['publish_release', 'get_shared_program', 'delete_my_account']::text[],
  'seules les fonctions SECURITY DEFINER attendues existent dans public'
);

select set_eq(
  $$ select p.proname::text
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute') $$,
  array['get_catalog_manifest', 'get_catalog_snapshot', 'get_catalog_delta', 'get_shared_program']::text[],
  'anon n''exécute que les RPC publiques prévues'
);

select is_empty(
  $$ select p.proname
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private') and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%'
        ) $$,
  'toute fonction SECURITY DEFINER fixe son search_path'
);

select is_empty(
  $$ select n.nspname || '.' || p.proname
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and exists (
          select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
           where a.grantee = 0 and a.privilege_type = 'EXECUTE'
        ) $$,
  'aucune fonction de public/private n''est exécutable par PUBLIC'
);

select ok(
  not has_schema_privilege('anon', 'private', 'usage'),
  'anon n''a pas accès au schéma private'
);

select * from finish();
rollback;
