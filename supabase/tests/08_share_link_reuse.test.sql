-- Réutilisation du lien de partage (tâche 7.4).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'b@test.invalid');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal2"}', true);
select public.sync_push_worship_service('{"id":"c1000000-0000-4000-8000-000000000001","title":"Culte","status":"published"}');

select set_config('test.t1', public.ensure_share_link('c1000000-0000-4000-8000-000000000001'), true);
select is(public.ensure_share_link('c1000000-0000-4000-8000-000000000001'), current_setting('test.t1'),
          'partager à nouveau renvoie le même lien');

select public.revoke_share_link('c1000000-0000-4000-8000-000000000001');
select isnt(public.ensure_share_link('c1000000-0000-4000-8000-000000000001'), current_setting('test.t1'),
            'après révocation, un nouveau lien est créé');

select set_config('test.t2', public.ensure_share_link('c1000000-0000-4000-8000-000000000001'), true);
select isnt(public.create_share_link('c1000000-0000-4000-8000-000000000001'), current_setting('test.t2'),
            'régénérer volontairement donne un nouveau lien');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","aal":"aal2"}', true);
select throws_ok(
  $$ select public.ensure_share_link('c1000000-0000-4000-8000-000000000001') $$,
  'P0002', null, 'un autre compte n''obtient pas le lien'
);
reset role;

set local role anon;
select throws_ok($$ select public.ensure_share_link('c1000000-0000-4000-8000-000000000001') $$,
                 '42501', null, 'anon ne peut pas obtenir de lien');
reset role;

select * from finish();
rollback;
