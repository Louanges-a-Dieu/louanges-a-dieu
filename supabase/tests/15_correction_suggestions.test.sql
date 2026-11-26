-- Propositions de correction des tableurs (migration 0027, Q-04, A-13).
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

insert into public.editions (id, name, edition_number)
values ('ed000000-0000-4000-8000-000000000015', 'Louanges à Dieu (test corrections)', 15);
insert into public.hymns (id, edition_id, number_label, number_numeric, title, opening_line) values
  ('a1500000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000015', '1', 1,
   'O jour heureux', 'O jour heureux, jour de bonheur,'),
  ('a1500000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000015', '2', 2,
   'Mon âme', 'Mon âme, bénis l’Eternel');
insert into public.hymn_sections (id, hymn_id, section_type, section_number, text, display_order) values
  ('5e150000-0000-4000-8000-000000000001', 'a1500000-0000-4000-8000-000000000001', 'verse', 1,
   E'O jour heureux, jour de bonheur,\nSépares-toi des œuvres des ténèbres', 0),
  ('5e150000-0000-4000-8000-000000000002', 'a1500000-0000-4000-8000-000000000002', 'verse', 1,
   E'Le Lion de la tribu de Judas,\nÔ Jésus !', 0);

-- Cantique 1 validé : une correction appliquée doit le repasser en brouillon.
update public.hymns set status = 'review' where id = 'a1500000-0000-4000-8000-000000000001';
update public.hymns set status = 'published' where id = 'a1500000-0000-4000-8000-000000000001';

create function pg_temp.payload() returns jsonb language sql as $$
  select jsonb_build_object(
    'format', 'lad.corrections', 'version', 1,
    'source', jsonb_build_object('filename', 'corrections.xlsx',
                                 'sha256', repeat('ab', 32), 'parserVersion', 'corrections-1'),
    'editionId', 'ed000000-0000-4000-8000-000000000015',
    'stats', jsonb_build_object('applied', 4, 'pending', 2, 'conflict', 1, 'not_found', 1, 'declined', 0),
    'suggestions', jsonb_build_array(
      -- Titre, premier vers et section du cantique 1 : une seule proposition.
      jsonb_build_object('key', 'corrections.xlsx|F|22|a1', 'status', 'pending',
        'hymnId', 'a1500000-0000-4000-8000-000000000001',
        'source', jsonb_build_object('row', 22, 'original', 'O jour heureux', 'proposed', 'Ô jour heureux'),
        'passages', jsonb_build_array(
          jsonb_build_object('unit', 'title', 'sectionId', null, 'offset', 0,
                             'current', 'O jour', 'replacement', 'Ô jour', 'context', 'O jour heureux'),
          jsonb_build_object('unit', 'opening_line', 'sectionId', null, 'offset', 0,
                             'current', 'O jour', 'replacement', 'Ô jour', 'context', 'O jour heureux, jour de bonheur,'),
          jsonb_build_object('unit', 'section', 'sectionId', '5e150000-0000-4000-8000-000000000001', 'offset', 0,
                             'current', 'O jour', 'replacement', 'Ô jour', 'context', 'O jour heureux, jour de bonheur,'))),
      jsonb_build_object('key', 'corrections.xlsx|F|80|a1', 'status', 'pending',
        'hymnId', 'a1500000-0000-4000-8000-000000000001',
        'source', jsonb_build_object('row', 80, 'original', 'Sépares-toi', 'proposed', 'Sépare-toi'),
        'passages', jsonb_build_array(
          jsonb_build_object('unit', 'section', 'sectionId', '5e150000-0000-4000-8000-000000000001', 'offset', 33,
                             'current', 'Sépares-toi', 'replacement', 'Sépare-toi',
                             'context', 'Sépares-toi des œuvres des ténèbres'))),
      jsonb_build_object('key', 'corrections.xlsx|F|167|a2', 'status', 'conflict',
        'hymnId', 'a1500000-0000-4000-8000-000000000002',
        'source', jsonb_build_object('row', 167, 'original', 'tribu de Judah', 'proposed', 'tribu de Juda'),
        'passages', jsonb_build_array(
          jsonb_build_object('unit', 'section', 'sectionId', '5e150000-0000-4000-8000-000000000002', 'offset', 14,
                             'current', 'tribu de Judas', 'replacement', null,
                             'context', 'Le Lion de la tribu de Judas,'))),
      jsonb_build_object('key', 'corrections.xlsx|F|155', 'status', 'not_found', 'hymnId', null,
        'source', jsonb_build_object('row', 155, 'original', 'les pêcheurs se relèvent', 'proposed', 'les pécheurs se relèvent'),
        'passages', '[]'::jsonb)
    ))
$$;
grant execute on function pg_temp.payload() to authenticated;

-- ------------------------------------------------------------------ droits
set local role authenticated;
select pg_temp.as_user('11111111-1111-4111-8111-111111111111', 'aal2');
select throws_ok($$ select public.import_corrections(pg_temp.payload()) $$, '42501', null,
                 'compte sans rôle : chargement refusé');
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal1');
select throws_ok($$ select public.import_corrections(pg_temp.payload()) $$, '42501', null,
                 'éditeur sans second facteur : chargement refusé');

-- -------------------------------------------------------------- chargement
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal2');

select throws_ok(
  $$ select public.import_corrections(jsonb_set(pg_temp.payload(), '{suggestions,1,passages,0,offset}', '5')) $$,
  '22023', null, 'passage absent à la position indiquée : chargement refusé');
select throws_ok(
  $$ select public.import_corrections(jsonb_set(pg_temp.payload(), '{format}', '"autre"')) $$,
  '22023', null, 'format inattendu : refusé');

select is(public.import_corrections(pg_temp.payload(), true) ->> 'new', '4',
          'simulation : 4 propositions nouvelles');
select is_empty($$ select 1 from public.import_issues where code = 'A-13' $$,
                'simulation : rien n''est enregistré');

select is(public.import_corrections(pg_temp.payload()) ->> 'created', '4', 'chargement : 4 propositions');
select results_eq(
  $$ select severity::text, count(*)::int from public.import_issues
      where code = 'A-13' group by 1 order by 1 $$,
  $$ values ('info', 1), ('warning', 3) $$,
  'à appliquer et à arbitrer : « à vérifier » ; introuvable : information (aucune n''est bloquante)');
select is(
  (select message from public.import_issues where details ->> 'key' = 'corrections.xlsx|F|80|a1'),
  'Correction proposée : « Sépares-toi » → « Sépare-toi »', 'message lisible');
select is(
  (select stats ->> 'suggestionsCreated' from public.import_batches
    where parser_version = 'corrections-1'),
  '4', 'lot d''import avec le décompte');

select is(public.import_corrections(pg_temp.payload()) ->> 'created', '0',
          'rechargement : aucune proposition recréée (idempotent)');
select is(public.import_corrections(pg_temp.payload()) ->> 'alreadyKnown', '4',
          'rechargement : propositions reconnues');

-- ------------------------------------------------------------- application
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'corrections.xlsx|F|155')) $$,
  '23514', null, 'introuvable : rien à appliquer');
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'corrections.xlsx|F|167|a2')) $$,
  '23514', null, 'à arbitrer : le texte corrigé doit être saisi');

-- Une retouche avant le passage décale sa position : il est retrouvé quand même.
update public.hymn_sections set text = E'O jour heureux, jour de bonheur,\nVa, Sépares-toi des œuvres des ténèbres'
 where id = '5e150000-0000-4000-8000-000000000001';
update public.hymns set status = 'review' where id = 'a1500000-0000-4000-8000-000000000001';
update public.hymns set status = 'published' where id = 'a1500000-0000-4000-8000-000000000001';

select is(
  public.apply_correction((select id from public.import_issues
                            where details ->> 'key' = 'corrections.xlsx|F|80|a1')) -> 'applied' -> 0 ->> 'after',
  'Sépare-toi', 'correction appliquée malgré le décalage');
select is((select text from public.hymn_sections where id = '5e150000-0000-4000-8000-000000000001'),
          E'O jour heureux, jour de bonheur,\nVa, Sépare-toi des œuvres des ténèbres',
          'seul le passage est remplacé');
select is((select status::text from public.hymns where id = 'a1500000-0000-4000-8000-000000000001'),
          'draft', 'cantique validé repassé en brouillon (T-009)');
select is(
  (select row(status::text, resolution_note, resolved_by)::text from public.import_issues
    where details ->> 'key' = 'corrections.xlsx|F|80|a1'),
  row('resolved', 'Correction appliquée', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid)::text,
  'proposition résolue, auteur fixé par le serveur');
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'corrections.xlsx|F|80|a1')) $$,
  '23514', null, 'une proposition traitée ne s''applique pas deux fois');

-- Titre, premier vers et section en une fois.
select is(
  jsonb_array_length(public.apply_correction((select id from public.import_issues
                                               where details ->> 'key' = 'corrections.xlsx|F|22|a1')) -> 'applied'),
  3, 'trois passages corrigés');
select is(
  (select row(title, opening_line)::text from public.hymns where id = 'a1500000-0000-4000-8000-000000000001'),
  row('Ô jour heureux', 'Ô jour heureux, jour de bonheur,')::text, 'titre et premier vers corrigés');
select is((select text from public.hymn_sections where id = '5e150000-0000-4000-8000-000000000001'),
          E'Ô jour heureux, jour de bonheur,\nVa, Sépare-toi des œuvres des ténèbres',
          'section corrigée');

-- À arbitrer : l'éditeur saisit le texte.
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'corrections.xlsx|F|167|a2'),
                                    array['tribu de Judas', 'en trop']) $$,
  '22023', null, 'plus de textes que de passages : refusé');
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'corrections.xlsx|F|167|a2'),
                                    array['tribu de Judas']) $$,
  '23514', null, 'texte identique : refusé (refuser la proposition à la place)');
select is(
  public.apply_correction((select id from public.import_issues
                            where details ->> 'key' = 'corrections.xlsx|F|167|a2'),
                          array['tribu de Juda']) ->> 'edited',
  'true', 'texte saisi par l''éditeur appliqué');
select is((select text from public.hymn_sections where id = '5e150000-0000-4000-8000-000000000002'),
          E'Le Lion de la tribu de Juda,\nÔ Jésus !', 'section corrigée par l''éditeur');
select is((select resolution_note from public.import_issues
            where details ->> 'key' = 'corrections.xlsx|F|167|a2'),
          'Correction appliquée (texte ajusté par l’éditeur)', 'ajustement signalé dans la décision');

select isnt_empty(
  $$ select 1 from public.audit_log where table_name = 'hymn_sections'
      and record_id = '5e150000-0000-4000-8000-000000000002' and actor_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' $$,
  'modification journalisée au nom de l''éditeur');

-- Passage disparu : refus explicite. Les propositions déjà chargées (dont le
-- texte a été corrigé depuis) ne sont pas recontrôlées.
select is(public.import_corrections(jsonb_set(pg_temp.payload(), '{suggestions}',
            pg_temp.payload() -> 'suggestions' || jsonb_build_array(jsonb_build_object(
              'key', 'autre|clé', 'status', 'pending', 'hymnId', 'a1500000-0000-4000-8000-000000000002',
              'source', jsonb_build_object('row', 3),
              'passages', jsonb_build_array(jsonb_build_object('unit', 'section',
                'sectionId', '5e150000-0000-4000-8000-000000000002', 'offset', 0,
                'current', 'Le Lion', 'replacement', 'Le lion', 'context', 'Le Lion de la tribu de Juda,'))))))
          ->> 'created',
          '1', 'nouvelle proposition chargée, les anciennes ignorées');
update public.hymn_sections set text = E'Le Roi de la tribu de Juda,\nÔ Jésus !'
 where id = '5e150000-0000-4000-8000-000000000002';
select throws_ok(
  $$ select public.apply_correction((select id from public.import_issues
                                      where details ->> 'key' = 'autre|clé')) $$,
  '23514', null, 'passage modifié entre-temps : refusé, rien n''est écrasé');

-- Une proposition refusée ne revient pas au chargement suivant.
select is(public.resolve_issues(array(select id from public.import_issues where details ->> 'key' = 'autre|clé'),
                                'ignored', 'Majuscule voulue'), 1, 'proposition refusée');
select is(public.import_corrections(jsonb_set(pg_temp.payload(), '{suggestions}',
            pg_temp.payload() -> 'suggestions' || jsonb_build_array(jsonb_build_object(
              'key', 'autre|clé', 'status', 'pending', 'hymnId', 'a1500000-0000-4000-8000-000000000002',
              'source', jsonb_build_object('row', 3),
              'passages', jsonb_build_array(jsonb_build_object('unit', 'section',
                'sectionId', '5e150000-0000-4000-8000-000000000002', 'offset', 0,
                'current', 'Le Roi', 'replacement', 'Le roi', 'context', ''))))))
          ->> 'created',
          '0', 'proposition refusée : pas recréée au chargement suivant');
reset role;

select * from finish();
rollback;
