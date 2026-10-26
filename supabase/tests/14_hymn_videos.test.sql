-- Vidéos YouTube des cantiques (migration 0026).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.editions (id, name, edition_number)
values ('ed000000-0000-4000-8000-000000000014', 'Louanges à Dieu (test vidéo)', 14);

insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('a1400000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000014', '1', 1, 'Avec vidéo'),
  ('a1400000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000014', '2', 2, 'Sans vidéo');

insert into public.hymn_sections (hymn_id, section_type, section_number, text, display_order) values
  ('a1400000-0000-4000-8000-000000000001', 'verse', 1, 'Ligne un.', 0),
  ('a1400000-0000-4000-8000-000000000002', 'verse', 1, 'Autre.', 0);

select ok(
  not (private.hymn_payload('a1400000-0000-4000-8000-000000000001') ? 'videos'),
  'sans vidéo, le payload n''a pas de clé videos (inchangé)'
);

-- ------------------------------------------------------- identifiants refusés
select throws_ok(
  $$ insert into public.hymn_videos (hymn_id, media_type, youtube_id)
     values ('a1400000-0000-4000-8000-000000000001', 'choir', 'https://youtu.be/dQw4w9WgXcQ') $$,
  '23514', null, 'une adresse complète est refusée (identifiant attendu)'
);
select throws_ok(
  $$ insert into public.hymn_videos (hymn_id, media_type, youtube_id)
     values ('a1400000-0000-4000-8000-000000000001', 'choir', 'court') $$,
  '23514', null, 'un identifiant qui n''a pas 11 caractères est refusé'
);

-- Le cantique validé ne repasse pas en brouillon quand on ajoute une vidéo.
update public.hymns set status = 'review' where id = 'a1400000-0000-4000-8000-000000000001';
update public.hymns set status = 'published' where id = 'a1400000-0000-4000-8000-000000000001';

insert into public.hymn_videos (id, hymn_id, media_type, youtube_id, title, rights_status) values
  ('7d140000-0000-4000-8000-000000000001', 'a1400000-0000-4000-8000-000000000001', 'choir',
   'dQw4w9WgXcQ', 'Chorale du dimanche', 'cleared'),
  ('7d140000-0000-4000-8000-000000000002', 'a1400000-0000-4000-8000-000000000001', 'instrumental',
   'aaaaaaaaaaa', null, 'restricted'),
  ('7d140000-0000-4000-8000-000000000003', 'a1400000-0000-4000-8000-000000000001', 'melody',
   'bbbbbbbbbb-', null, 'unknown');

-- Droits restreints posés par le registre des droits.
insert into public.rights_records (media_id, rights_status)
values ('7d140000-0000-4000-8000-000000000003', 'restricted');

select is(
  (select status::text from public.hymns where id = 'a1400000-0000-4000-8000-000000000001'),
  'published',
  'ajouter une vidéo ne repasse pas le cantique en brouillon'
);

select throws_ok(
  $$ insert into public.hymn_videos (hymn_id, media_type, youtube_id)
     values ('a1400000-0000-4000-8000-000000000001', 'melody', 'dQw4w9WgXcQ') $$,
  '23505', null, 'la même vidéo ne peut pas être rattachée deux fois au cantique'
);

select is(
  private.hymn_payload('a1400000-0000-4000-8000-000000000001') -> 'videos',
  jsonb_build_array(jsonb_build_object(
    'id', '7d140000-0000-4000-8000-000000000001',
    'mediaType', 'choir',
    'youtubeId', 'dQw4w9WgXcQ',
    'title', 'Chorale du dimanche'
  )),
  'seules les vidéos non restreintes (vidéo ou registre des droits) sont publiées'
);

select ok(
  not (private.hymn_payload('a1400000-0000-4000-8000-000000000002') ? 'videos'),
  'un cantique sans vidéo garde un payload sans clé videos'
);

select isnt_empty(
  $$ select 1 from public.audit_log
      where table_name = 'hymn_videos' and record_id = '7d140000-0000-4000-8000-000000000001' $$,
  'l''ajout d''une vidéo est journalisé'
);

-- --------------------------------------------------------------- accès
set local role anon;
select throws_ok(
  $$ select count(*) from public.hymn_videos $$,
  '42501', null, 'anon ne lit pas la table des vidéos (seulement le contenu publié)'
);
reset role;

insert into auth.users (id, email) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee14', 'lecteur-video@test.invalid');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeee14","role":"authenticated","aal":"aal2"}', true);
select is_empty(
  $$ select 1 from public.hymn_videos $$,
  'un utilisateur sans rôle éditorial ne voit aucune vidéo de la copie de travail'
);
select throws_ok(
  $$ insert into public.hymn_videos (hymn_id, media_type, youtube_id)
     values ('a1400000-0000-4000-8000-000000000002', 'choir', 'ccccccccccc') $$,
  '42501', null, 'un utilisateur sans rôle éditorial ne peut pas ajouter de vidéo'
);
reset role;

select * from finish();
rollback;
