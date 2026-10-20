-- Enregistrements audio dans le contenu publié (migration 0019).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.editions (id, name, edition_number)
values ('ed000000-0000-4000-8000-000000000011', 'Louanges à Dieu (test audio)', 11);

insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a1100000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000011', '1', 1, 'Avec audio'),
  ('a1100000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000011', '2', 2, 'Sans audio');

insert into public.hymn_sections (id, hymn_id, section_type, section_number, text, display_order) values
  ('5e110000-0000-4000-8000-000000000011', 'a1100000-0000-4000-8000-000000000001', 'verse', 1, 'Ligne un.', 0),
  ('5e110000-0000-4000-8000-000000000012', 'a1100000-0000-4000-8000-000000000001', 'refrain', null, 'Refrain.', 1),
  ('5e110000-0000-4000-8000-000000000021', 'a1100000-0000-4000-8000-000000000002', 'verse', 1, 'Autre.', 0);

-- --------------------------------------------------------------- sans piste
select ok(
  not (private.hymn_payload('a1100000-0000-4000-8000-000000000001') ? 'audio'),
  'sans enregistrement, le payload n''a pas de clé audio (inchangé)'
);

-- ------------------------------------------------------------- clés refusées
select throws_ok(
  $$ insert into public.audio_tracks (hymn_id, media_type, storage_key)
     values ('a1100000-0000-4000-8000-000000000001', 'melody', 'https://exemple.test/a.mp3') $$,
  '23514', null, 'une URL complète est refusée (clé relative attendue)'
);
select throws_ok(
  $$ insert into public.audio_tracks (hymn_id, media_type, storage_key)
     values ('a1100000-0000-4000-8000-000000000001', 'melody', 'cantiques/../secret.mp3') $$,
  '23514', null, '« .. » est refusé'
);
select throws_ok(
  $$ insert into public.audio_tracks (hymn_id, media_type, storage_key)
     values ('a1100000-0000-4000-8000-000000000001', 'melody', 'cantiques/1/melodie.wav') $$,
  '23514', null, 'un format non lisible partout est refusé'
);
select throws_ok(
  $$ insert into public.audio_tracks (hymn_id, media_type, storage_key, duration_seconds)
     values ('a1100000-0000-4000-8000-000000000001', 'melody', 'cantiques/1/a.mp3', 0) $$,
  '23514', null, 'une durée nulle est refusée'
);

-- ------------------------------------------------------------- pistes valides
insert into public.audio_tracks (id, hymn_id, media_type, storage_key, duration_seconds, rights_status) values
  ('ad110000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000001', 'melody',
   'cantiques/0001/melodie.mp3', 125.5, 'cleared'),
  ('ad110000-0000-4000-8000-000000000002', 'a1100000-0000-4000-8000-000000000001', 'choir',
   'cantiques/0001/chorale.m4a', null, 'restricted'),
  ('ad110000-0000-4000-8000-000000000003', 'a1100000-0000-4000-8000-000000000001', 'instrumental',
   'cantiques/0001/instrumental.mp3', null, 'unknown');

insert into public.audio_segments (audio_track_id, section_id, start_ms, end_ms, display_order) values
  ('ad110000-0000-4000-8000-000000000001', '5e110000-0000-4000-8000-000000000011', 0, 30000, 0),
  ('ad110000-0000-4000-8000-000000000001', '5e110000-0000-4000-8000-000000000012', 30000, 52000, 1),
  -- Section d'un autre cantique : jamais exposée.
  ('ad110000-0000-4000-8000-000000000001', '5e110000-0000-4000-8000-000000000021', 52000, 60000, 2);

-- Droits restreints posés par un rights_records rattaché à la piste.
insert into public.rights_records (media_id, rights_status)
values ('ad110000-0000-4000-8000-000000000003', 'restricted');

select is(
  jsonb_array_length(private.hymn_payload('a1100000-0000-4000-8000-000000000001') -> 'audio'),
  1,
  'les pistes aux droits restreints (piste ou registre des droits) ne sont pas publiées'
);

select is(
  private.hymn_payload('a1100000-0000-4000-8000-000000000001') -> 'audio' -> 0,
  jsonb_build_object(
    'id', 'ad110000-0000-4000-8000-000000000001',
    'mediaType', 'melody',
    'storageKey', 'cantiques/0001/melodie.mp3',
    'durationSeconds', 125.5,
    'segments', jsonb_build_array(
      jsonb_build_object('sectionId', '5e110000-0000-4000-8000-000000000011',
                         'startMs', 0, 'endMs', 30000, 'order', 0),
      jsonb_build_object('sectionId', '5e110000-0000-4000-8000-000000000012',
                         'startMs', 30000, 'endMs', 52000, 'order', 1),
      jsonb_build_object('sectionId', null, 'startMs', 52000, 'endMs', 60000, 'order', 2)
    )
  ),
  'piste publiée : clé relative, durée, segments rattachés aux sections du cantique'
);

select ok(
  not (private.hymn_payload('a1100000-0000-4000-8000-000000000002') ? 'audio'),
  'un cantique sans piste garde un payload sans clé audio'
);

-- --------------------------------------------------------------- accès public
set local role anon;
select throws_ok(
  $$ select count(*) from public.audio_tracks $$,
  '42501', null, 'anon ne lit pas la table des pistes (seulement le contenu publié)'
);
reset role;

select * from finish();
rollback;
