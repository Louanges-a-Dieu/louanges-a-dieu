-- Releases de catalogue : contenu publié, idempotence, T-009, deltas, accès.
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

-- Isoler le test d'éventuelles releases existantes sur la base.
delete from public.catalog_releases;

-- ------------------------------------------------------------- anonyme, vide
set local role anon;
select is(public.get_catalog_manifest(), null, 'sans release, le manifeste est vide');
select is(public.get_catalog_delta(1), null, 'sans release, pas de delta');
reset role;

-- --------------------------------------------------------- contenu éditorial
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated","aal":"aal2"}', true);

insert into public.editions (id, name, edition_number)
values ('ed000000-0000-4000-8000-000000000006', 'Louanges à Dieu (test)', 6);

insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a0000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006', '1', 1, 'Titre un'),
  ('a0000000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000006', '2', 2, 'Jamais validé'),
  ('a0000000-0000-4000-8000-000000000003', 'ed000000-0000-4000-8000-000000000006', '3', 3, 'Titre trois');

insert into public.hymn_sections (id, hymn_id, section_type, section_number, text, display_order) values
  ('5e000000-0000-4000-8000-000000000011', 'a0000000-0000-4000-8000-000000000001', 'verse', 1,
   E'Ligne un,\nLigne deux (bis)\n', 0),
  ('5e000000-0000-4000-8000-000000000012', 'a0000000-0000-4000-8000-000000000001', 'refrain', null,
   E'Refrain chanté (ter)\nRéponse (alléluia !)', 1),
  ('5e000000-0000-4000-8000-000000000021', 'a0000000-0000-4000-8000-000000000002', 'verse', 1, 'Ligne.', 0),
  ('5e000000-0000-4000-8000-000000000031', 'a0000000-0000-4000-8000-000000000003', 'verse', 1, 'Ligne.', 0);

insert into public.bible_references (hymn_id, book, chapter_start, display_text)
values ('a0000000-0000-4000-8000-000000000001', 'Psaumes', 47, 'Psaumes 47');

select results_eq(
  $$ select bool_and(ok) from public.set_hymns_status(
       array['a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003']::uuid[], 'review') $$,
  array[true], 'soumission en relecture'
);
select results_eq(
  $$ select bool_and(ok) from public.set_hymns_status(
       array['a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003']::uuid[], 'published') $$,
  array[true], 'validation'
);

-- ------------------------------------------------------------- release 1
select ok(public.publish_release('ed000000-0000-4000-8000-000000000006', 'Première') > 0,
          'publication de la release 1');
select set_config('test.r1', (select max(id)::text from public.catalog_releases), true);

select is(
  (select hymn_count from public.catalog_releases where id = current_setting('test.r1')::integer),
  2, 'la release contient les 2 cantiques validés (le brouillon est exclu)'
);

select set_eq(
  $$ select jsonb_object_keys(payload) from public.published_hymns
      where hymn_id = 'a0000000-0000-4000-8000-000000000001' $$,
  array['id', 'numberLabel', 'numberNumeric', 'numberSuffix', 'title', 'openingLine', 'languageCode',
        'sections', 'bibleReferences', 'relations', 'people', 'themes'],
  'le contenu publié suit le contrat PublishedHymn'
);

select is(
  (select payload -> 'sections' -> 0 -> 'lines' -> 1 from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  '{"text": "Ligne deux (bis)", "repeat": {"count": 2, "marker": "(bis)"}}'::jsonb,
  '« (bis) » en fin de ligne est annoté (count 2), texte verbatim conservé'
);
select is(
  (select jsonb_array_length(payload -> 'sections' -> 0 -> 'lines') from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  2, 'les lignes vides ne sont pas publiées'
);
select is(
  (select payload -> 'sections' -> 1 -> 'lines' -> 1 -> 'repeat' from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  'null'::jsonb, 'une réponse chantée « (alléluia !) » n''est pas une répétition'
);
select is(
  (select payload -> 'sections' -> 1 ->> 'type' from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  'refrain', 'le refrain est distingué'
);
select is(
  (select payload -> 'openingLine' from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  'null'::jsonb, 'une première ligne inconnue reste null (rien n''est inventé)'
);
select is(
  (select payload -> 'people' from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  '[]'::jsonb, 'aucun auteur inventé'
);
select is(
  (select payload -> 'bibleReferences' -> 0 ->> 'displayText' from public.published_hymns
    where hymn_id = 'a0000000-0000-4000-8000-000000000001'),
  'Psaumes 47', 'la référence biblique est publiée telle qu''imprimée'
);

select is(
  public.publish_release('ed000000-0000-4000-8000-000000000006'),
  current_setting('test.r1')::integer, 'republier sans changement renvoie la même release (idempotent)'
);

-- ------------------------------------------------------------------ T-009
update public.hymns set title = 'Titre un corrigé' where id = 'a0000000-0000-4000-8000-000000000001';
select is(
  public.publish_release('ed000000-0000-4000-8000-000000000006'),
  current_setting('test.r1')::integer, 'T-009 : une correction en brouillon ne crée pas de nouvelle release'
);
reset role;
set local role anon;
select is(
  (select h ->> 'title' from jsonb_array_elements(public.get_catalog_snapshot() -> 'hymns') h
    where h ->> 'numberLabel' = '1'),
  'Titre un', 'T-009 : le public voit toujours la version publiée'
);
reset role;

-- --------------------------------------------------- release 2 : correction
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated","aal":"aal2"}', true);
update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000001';
update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000001';
select isnt(
  public.publish_release('ed000000-0000-4000-8000-000000000006'),
  current_setting('test.r1')::integer, 'après validation, une nouvelle release est créée'
);
reset role;
set local role anon;
select is(
  (select h ->> 'title' from jsonb_array_elements(public.get_catalog_snapshot() -> 'hymns') h
    where h ->> 'numberLabel' = '1'),
  'Titre un corrigé', 'le public voit la correction validée'
);
select is(
  (select jsonb_array_length(public.get_catalog_delta(current_setting('test.r1')::integer) -> 'upserts')),
  1, 'le delta ne contient que le cantique modifié'
);
select is(
  public.get_catalog_delta(current_setting('test.r1')::integer) -> 'removedIds',
  '[]'::jsonb, 'aucun retrait'
);
reset role;

-- ------------------------------------------------- release 3 : archivage
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated","aal":"aal2"}', true);
update public.hymns set status = 'archived' where id = 'a0000000-0000-4000-8000-000000000003';
select set_config('test.r2', (select max(id)::text from public.catalog_releases), true);
select ok(public.publish_release('ed000000-0000-4000-8000-000000000006') > current_setting('test.r2')::integer,
          'publication après archivage');
reset role;
set local role anon;
select is(
  public.get_catalog_delta(current_setting('test.r2')::integer) -> 'removedIds',
  '["a0000000-0000-4000-8000-000000000003"]'::jsonb,
  'un cantique archivé est retiré (removedIds)'
);
select is(
  (select jsonb_array_length(public.get_catalog_snapshot() -> 'hymns')),
  1, 'l''instantané ne contient plus que le cantique 1'
);
select is(
  (public.get_catalog_delta(999999) ->> 'fullSnapshotRequired')::boolean,
  true, 'une release inconnue du serveur impose un instantané complet'
);
select is(
  (public.get_catalog_manifest() ->> 'hymnCount')::integer,
  1, 'le manifeste décrit la dernière release'
);

-- ---------------------------------------------------------------- accès
select throws_ok(
  $$ select public.publish_release('ed000000-0000-4000-8000-000000000006') $$,
  '42501', null, 'anon ne peut pas publier'
);
select throws_ok(
  $$ insert into public.published_hymns (release_id, hymn_id, payload, payload_hash)
     values (1, 'a0000000-0000-4000-8000-000000000001', '{}', repeat('a', 64)) $$,
  '42501', null, 'anon ne peut pas écrire dans le catalogue'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal2"}', true);
select throws_ok(
  $$ select public.publish_release('ed000000-0000-4000-8000-000000000006') $$,
  '42501', null, 'un utilisateur sans rôle ne peut pas publier'
);
select throws_ok(
  $$ delete from public.catalog_releases $$,
  '42501', null, 'un utilisateur ne peut pas supprimer une release'
);
reset role;

select * from finish();
rollback;
