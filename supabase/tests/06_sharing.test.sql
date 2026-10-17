-- Partage d'un programme (F-WOR-002, T-007 côté serveur, ADR-012, Q-09).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'b@test.invalid'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editeur@test.invalid');
insert into public.user_roles (user_id, role) values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor');
delete from public.catalog_releases;

-- Catalogue publié : le cantique 1 est publié, le 2 ne l'est pas.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}', true);
insert into public.editions (id, name) values ('ed000000-0000-4000-8000-000000000006', 'Test');
insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a0000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006', '1', 1, 'Titre publié'),
  ('a0000000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000006', '2', 2, 'Brouillon');
insert into public.hymn_sections (hymn_id, section_type, text, display_order) values
  ('a0000000-0000-4000-8000-000000000001', 'verse', 'Ligne.', 0);
select public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001']::uuid[], 'review');
select public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001']::uuid[], 'published');
select public.publish_release('ed000000-0000-4000-8000-000000000006');

-- Programme de A, en brouillon
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select public.sync_push_worship_service('{"id":"c1000000-0000-4000-8000-000000000001",
  "title":"Culte de Pâques","serviceDate":"2027-03-28","status":"draft",
  "items":[{"label":"Accueil","order":0},
           {"hymnId":"a0000000-0000-4000-8000-000000000001","order":1},
           {"hymnId":"a0000000-0000-4000-8000-000000000002","order":2}]}');

select set_config('test.token', public.create_share_link('c1000000-0000-4000-8000-000000000001'), true);
select matches(current_setting('test.token'), '^[A-Za-z0-9_-]{32}$', 'le jeton est opaque (32 caractères base64url, 192 bits)');
select throws_ok(
  $$ select public.create_share_link('c1000000-0000-4000-8000-000000000001', now() - interval '1 hour') $$,
  '23514', null, 'une expiration dans le passé est refusée'
);

reset role;
set local role anon;
select is(public.get_shared_program(current_setting('test.token')), null,
          'un programme non publié n''est pas visible par le lien');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
update public.worship_services set status = 'published' where id = 'c1000000-0000-4000-8000-000000000001';

-- ------------------------------------------------------------ vue publique
reset role;
set local role anon;
select set_config('test.view', public.get_shared_program(current_setting('test.token'))::text, true);
select is(current_setting('test.view')::jsonb ->> 'title', 'Culte de Pâques', 'le lien public affiche le programme publié');
select set_eq(
  $$ select jsonb_object_keys(current_setting('test.view')::jsonb) $$,
  array['title', 'serviceDate', 'items'],
  'seuls titre, date et éléments sont exposés'
);
select ok(
  position('11111111-1111-4111-8111-111111111111' in current_setting('test.view')) = 0
  and position('a@test.invalid' in current_setting('test.view')) = 0,
  'aucune donnée du compte du créateur n''est exposée'
);
select is(
  current_setting('test.view')::jsonb -> 'items' -> 1 -> 'hymn',
  '{"id": "a0000000-0000-4000-8000-000000000001", "numberLabel": "1", "title": "Titre publié"}'::jsonb,
  'un cantique apparaît avec son numéro et son titre publiés, sans les paroles (Q-09)'
);
select is(
  current_setting('test.view')::jsonb -> 'items' -> 2 -> 'hymn',
  '{"unavailable": true}'::jsonb,
  'un cantique non publié n''expose pas son brouillon'
);
select is(public.get_shared_program('ceci-n-est-pas-un-jeton-valide-0123'), null, 'un jeton inconnu ne renvoie rien');
select is(public.get_shared_program('court'), null, 'un jeton mal formé ne renvoie rien');
select throws_ok($$ select * from public.worship_services $$, '42501', null,
                 'anon ne peut pas lire les programmes directement');
reset role;

-- ------------------------------------------------------------- autre compte
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
select throws_ok(
  $$ select public.create_share_link('c1000000-0000-4000-8000-000000000001') $$,
  'P0002', null, 'B ne peut pas créer de lien pour le programme de A'
);
select throws_ok(
  $$ select public.revoke_share_link('c1000000-0000-4000-8000-000000000001') $$,
  'P0002', null, 'B ne peut pas révoquer le lien de A'
);

-- ------------------------------------------------- révocation et régénération
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select public.revoke_share_link('c1000000-0000-4000-8000-000000000001');
reset role;
set local role anon;
select is(public.get_shared_program(current_setting('test.token')), null, 'un lien révoqué ne renvoie plus rien');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select set_config('test.token2', public.create_share_link('c1000000-0000-4000-8000-000000000001'), true);
select isnt(current_setting('test.token2'), current_setting('test.token'), 'un nouveau lien a un nouveau jeton');
reset role;
set local role anon;
select isnt(public.get_shared_program(current_setting('test.token2')), null, 'le nouveau lien fonctionne');
select is(public.get_shared_program(current_setting('test.token')), null, 'l''ancien jeton reste invalide');
reset role;

-- Expiration
update public.worship_services set share_expires_at = now() - interval '1 minute'
 where id = 'c1000000-0000-4000-8000-000000000001';
set local role anon;
select is(public.get_shared_program(current_setting('test.token2')), null, 'un lien expiré ne renvoie plus rien');
reset role;

select * from finish();
rollback;
