-- Suppression de compte par l'utilisateur (tâche 6.2).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'b@test.invalid');
insert into public.editions (id, name) values ('ed000000-0000-4000-8000-000000000006', 'Test');
insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a0000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006', '1', 1, 'Un');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select public.sync_push_favorites('[{"hymnId":"a0000000-0000-4000-8000-000000000001"}]');
select public.sync_push_playlist('{"id":"b1000000-0000-4000-8000-000000000001","name":"Liste A",
  "items":[{"hymnId":"a0000000-0000-4000-8000-000000000001","order":0}]}');
select public.sync_push_worship_service('{"id":"c1000000-0000-4000-8000-000000000001","title":"Culte A"}');

select lives_ok($$ select public.delete_my_account() $$, 'l''utilisateur supprime son compte');
reset role;

select is(
  (select count(*)::int from auth.users where id = '11111111-1111-4111-8111-111111111111'),
  0, 'le compte est supprimé'
);
select is(
  (select count(*)::int from public.profiles where id = '11111111-1111-4111-8111-111111111111')
  + (select count(*)::int from public.favorites where user_id = '11111111-1111-4111-8111-111111111111')
  + (select count(*)::int from public.playlists where user_id = '11111111-1111-4111-8111-111111111111')
  + (select count(*)::int from public.worship_services where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  0, 'profil, favoris, listes et programmes supprimés avec lui'
);
select is(
  (select count(*)::int from auth.users where id = '22222222-2222-4222-8222-222222222222'),
  1, 'les autres comptes ne sont pas touchés'
);

set local role anon;
select throws_ok($$ select public.delete_my_account() $$, '42501', null, 'anon ne peut pas appeler la suppression');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$ select public.delete_my_account() $$, '42501', null, 'sans identité, rien n''est supprimé');
reset role;

select * from finish();
rollback;
