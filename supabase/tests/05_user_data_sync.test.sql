-- Données utilisateur : isolation, révisions, pierres tombales, listes,
-- programmes, suppression de compte (ADR-006, T-005/T-006 côté serveur).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'b@test.invalid');
insert into public.editions (id, name) values ('ed000000-0000-4000-8000-000000000006', 'Test');
insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a0000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006', '1', 1, 'Un'),
  ('a0000000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000006', '2', 2, 'Deux');

-- --------------------------------------------------------------- utilisateur A
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal2"}', true);

select lives_ok(
  $$ select public.sync_push_favorites('[{"hymnId":"a0000000-0000-4000-8000-000000000001"},
                                         {"hymnId":"a0000000-0000-4000-8000-000000000002"}]') $$,
  'A ajoute deux favoris'
);
select is(jsonb_array_length(public.sync_pull(0) -> 'favorites'), 2, 'A récupère ses deux favoris');
select set_config('test.rev1', public.sync_pull(0) ->> 'revision', true);
select ok(current_setting('test.rev1')::bigint > 0, 'une révision serveur est attribuée');

select public.sync_push_favorites('[{"hymnId":"a0000000-0000-4000-8000-000000000001","deleted":true}]');
select is(
  (select jsonb_agg(f - 'revision')
     from jsonb_array_elements(public.sync_pull(current_setting('test.rev1')::bigint) -> 'favorites') f),
  '[{"hymnId": "a0000000-0000-4000-8000-000000000001", "deleted": true}]'::jsonb,
  'la suppression est transmise comme pierre tombale, seule modification depuis la révision'
);
select ok(
  (public.sync_pull(current_setting('test.rev1')::bigint) ->> 'revision')::bigint
    > current_setting('test.rev1')::bigint,
  'les révisions sont croissantes'
);

-- Listes
select lives_ok(
  $$ select public.sync_push_playlist('{"id":"b1000000-0000-4000-8000-000000000001","name":"Ma liste",
       "items":[{"hymnId":"a0000000-0000-4000-8000-000000000002","order":0},
                {"hymnId":"a0000000-0000-4000-8000-000000000001","order":1}]}') $$,
  'A crée une liste ordonnée'
);
select lives_ok(
  $$ select public.sync_push_playlist('{"id":"b1000000-0000-4000-8000-000000000001","name":"Ma liste",
       "items":[{"hymnId":"a0000000-0000-4000-8000-000000000001","order":0},
                {"hymnId":"a0000000-0000-4000-8000-000000000002","order":1}]}') $$,
  'A réordonne sa liste (ordre permuté en une transaction)'
);
select is(
  public.sync_pull(0) -> 'playlists' -> 0 -> 'items' -> 0 ->> 'hymnId',
  'a0000000-0000-4000-8000-000000000001', 'le nouvel ordre est synchronisé'
);
select throws_ok(
  $$ select public.sync_push_playlist('{"id":"b1000000-0000-4000-8000-000000000002","name":"  "}') $$,
  '23514', null, 'un nom de liste vide est refusé'
);

-- Programme de culte
select lives_ok(
  $$ select public.sync_push_worship_service('{"id":"c1000000-0000-4000-8000-000000000001",
       "title":"Culte de dimanche","serviceDate":"2026-10-25",
       "items":[{"label":"Accueil","order":0},
                {"hymnId":"a0000000-0000-4000-8000-000000000001","notes":"Deux couplets","order":1}]}') $$,
  'A crée un programme avec une section libre et un cantique'
);
select is(
  jsonb_array_length(public.sync_pull(0) -> 'worshipServices' -> 0 -> 'items'),
  2, 'le programme et ses éléments sont synchronisés'
);
select throws_ok(
  $$ select public.sync_push_worship_service('{"id":"c1000000-0000-4000-8000-000000000002",
       "title":"Vide","items":[{"order":0}]}') $$,
  '23514', null, 'un élément sans cantique ni libellé est refusé'
);

-- Interdits
select throws_ok(
  $$ insert into public.favorites (user_id, hymn_id)
     values ('22222222-2222-4222-8222-222222222222', 'a0000000-0000-4000-8000-000000000001') $$,
  '42501', null, 'A ne peut pas créer de favori pour B'
);
select throws_ok(
  $$ delete from public.playlists $$,
  '42501', null, 'aucune suppression physique par l''API (pierres tombales)'
);
select throws_ok(
  $$ update public.playlists set user_id = '22222222-2222-4222-8222-222222222222'
      where id = 'b1000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'A ne peut pas transférer sa liste à un autre compte'
);

-- --------------------------------------------------------------- utilisateur B
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","aal":"aal2"}', true);
select is(
  public.sync_pull(0) - 'revision',
  '{"favorites": [], "playlists": [], "worshipServices": []}'::jsonb,
  'B ne reçoit aucune donnée de A'
);
select is_empty($$ select 1 from public.playlists $$, 'B ne voit pas les listes de A');
select throws_ok(
  $$ select public.sync_push_playlist('{"id":"b1000000-0000-4000-8000-000000000001","name":"Piratage"}') $$,
  '42501', null, 'B ne peut pas écraser la liste de A'
);
select throws_ok(
  $$ insert into public.playlist_items (playlist_id, hymn_id, display_order)
     values ('b1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 9) $$,
  '42501', null, 'B ne peut pas ajouter un élément à la liste de A'
);

-- -------------------------------------------------------------------- anonyme
reset role;
set local role anon;
select throws_ok($$ select public.sync_pull(0) $$, '42501', null, 'anon ne peut pas synchroniser');
select throws_ok($$ select * from public.favorites $$, '42501', null, 'anon ne lit aucun favori');

-- ----------------------------------------------------------- suppression de compte
reset role;
delete from auth.users where id = '11111111-1111-4111-8111-111111111111';
select is(
  (select count(*)::int from public.favorites where user_id = '11111111-1111-4111-8111-111111111111')
  + (select count(*)::int from public.playlists where user_id = '11111111-1111-4111-8111-111111111111')
  + (select count(*)::int from public.worship_services where owner_user_id = '11111111-1111-4111-8111-111111111111'),
  0, 'supprimer un compte supprime ses favoris, listes et programmes'
);

select * from finish();
rollback;
