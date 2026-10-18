-- Revue de sécurité (10.3) : CHAQUE fonction privilégiée exposée par l'API
-- refuse un compte sans rôle et un éditeur sans second facteur (aal1) ; les
-- fonctions réservées au super_admin refusent un éditeur.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'fidele@test.invalid'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editeur@test.invalid');
insert into public.user_roles (user_id, role) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor');

create function pg_temp.as_user(p_id text, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;
grant execute on function pg_temp.as_user(text, text) to authenticated;

-- Appels qui doivent être refusés (42501) ou ne rien renvoyer.
create function pg_temp.check_denied(p_who text) returns setof text language plpgsql as $$
declare
  calls text[] := array[
    $q$ select public.publish_release(gen_random_uuid()) $q$,
    $q$ select * from public.preview_release(gen_random_uuid()) $q$,
    $q$ select public.rollback_release(gen_random_uuid(), 1) $q$,
    $q$ select public.preview_hymn(gen_random_uuid()) $q$,
    $q$ select public.import_catalog_draft('{"format":"lad.catalog-draft"}'::jsonb) $q$,
    $q$ select public.resolve_issues(array[gen_random_uuid()], 'resolved') $q$,
    $q$ select * from public.set_hymns_status(array[gen_random_uuid()], 'review') $q$,
    $q$ select public.admin_grant_role('fidele@test.invalid', 'editor') $q$,
    $q$ select public.admin_revoke_role(gen_random_uuid(), 'editor') $q$
  ];
  empty text[] := array[
    $q$ select * from public.admin_list_team() $q$,
    $q$ select * from public.admin_audit_log() $q$,
    $q$ select * from public.search_hymns_admin() $q$,
    $q$ select 1 from public.hymns $q$,
    $q$ select 1 from public.import_issues $q$,
    $q$ select 1 from public.audit_log $q$,
    $q$ select 1 from public.rights_records $q$
  ];
  c text;
begin
  foreach c in array calls loop
    return next throws_ok(c, '42501', null, p_who || ' : refusé — ' || btrim(c));
  end loop;
  foreach c in array empty loop
    return next is_empty(c, p_who || ' : rien — ' || btrim(c));
  end loop;
  return next is(public.editorial_stats(), null, p_who || ' : pas de statistiques');
end;
$$;
grant execute on function pg_temp.check_denied(text) to authenticated;

set local role authenticated;
select pg_temp.as_user('11111111-1111-4111-8111-111111111111', 'aal2');
select pg_temp.check_denied('compte sans rôle');
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal1');
select pg_temp.check_denied('éditeur sans second facteur');

-- Éditeur avec second facteur : les fonctions du super_admin restent interdites.
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal2');
select throws_ok($$ select public.admin_grant_role('fidele@test.invalid', 'editor') $$, '42501', null,
                 'éditeur : attribution de rôle refusée');
select throws_ok($$ select public.admin_revoke_role('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor') $$,
                 '42501', null, 'éditeur : retrait de rôle refusé');
select is_empty($$ select * from public.admin_list_team() $$, 'éditeur : équipe invisible');
select throws_ok($$ insert into public.user_roles (user_id, role, granted_by)
                    values ('11111111-1111-4111-8111-111111111111', 'super_admin',
                            'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') $$,
                 '42501', null, 'éditeur : impossible de s''attribuer un rôle par la table');
reset role;

select * from finish();
rollback;
