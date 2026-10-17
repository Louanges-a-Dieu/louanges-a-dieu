-- Rôles applicatifs (ADR-010).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editeur@test.invalid'),
  ('55555555-5555-4555-8555-555555555555', 'super@test.invalid');
insert into public.user_roles (user_id, role) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor'),
  ('55555555-5555-4555-8555-555555555555', 'super_admin');

select ok(
  exists (select 1 from public.profiles where id = '11111111-1111-4111-8111-111111111111'),
  'un profil est créé automatiquement à l''inscription'
);
select is(
  (select display_name from public.profiles where id = '11111111-1111-4111-8111-111111111111'),
  null,
  'le nom d''affichage inconnu reste NULL'
);

select set_config('test.total_roles', ((select count(*) from public.user_roles) + 1)::text, true);

-- Utilisateur sans rôle
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select ok(not private.has_role('editor'), 'un utilisateur ordinaire n''est pas éditeur');
select is_empty($$ select 1 from public.user_roles $$, 'il ne voit aucun rôle');
select throws_ok(
  $$ insert into public.user_roles (user_id, role, granted_by)
     values ('11111111-1111-4111-8111-111111111111', 'super_admin', '11111111-1111-4111-8111-111111111111') $$,
  '42501', null, 'il ne peut pas s''attribuer un rôle'
);

-- Éditeur
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}', true);
select ok(private.has_role('editor'), 'l''éditeur a le rôle editor');
select ok(not private.has_role('super_admin'), 'l''éditeur n''est pas super_admin');
select results_eq($$ select role::text from public.user_roles $$, array['editor'], 'l''éditeur ne voit que son rôle');
select throws_ok(
  $$ insert into public.user_roles (user_id, role, granted_by)
     values ('11111111-1111-4111-8111-111111111111', 'editor', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') $$,
  '42501', null, 'l''éditeur ne peut pas attribuer de rôle'
);

-- Super admin
select set_config('request.jwt.claims', '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}', true);
select ok(private.has_role('editor'), 'le super_admin détient aussi le rôle editor');
select lives_ok(
  $$ insert into public.user_roles (user_id, role, granted_by)
     values ('11111111-1111-4111-8111-111111111111', 'editor', '55555555-5555-4555-8555-555555555555') $$,
  'le super_admin attribue un rôle'
);
select throws_ok(
  $$ insert into public.user_roles (user_id, role, granted_by)
     values ('11111111-1111-4111-8111-111111111111', 'super_admin', '11111111-1111-4111-8111-111111111111') $$,
  '42501', null, 'granted_by doit être l''auteur réel de l''attribution'
);
select is((select count(*)::int from public.user_roles), current_setting('test.total_roles')::int,
          'le super_admin voit tous les rôles');

-- Anonyme
reset role;
set local role anon;
select throws_ok($$ select private.has_role('editor') $$, '42501', null, 'anon ne peut pas appeler has_role');
select throws_ok($$ select * from public.user_roles $$, '42501', null, 'anon ne peut pas lire user_roles');

reset role;
select * from finish();
rollback;
