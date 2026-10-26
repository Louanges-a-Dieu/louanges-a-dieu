-- Migration 0026 — Vidéos des cantiques (YouTube)
--
-- Décision du propriétaire (2026-10-26) : les vidéos sont hébergées sur
-- YouTube, en « non répertoriée », et lues dans l'application avec le lecteur
-- YouTube intégré. La base ne garde que l'IDENTIFIANT de la vidéo (11
-- caractères), jamais une adresse : le back-office l'extrait du lien collé.
--
-- Comme pour l'audio (0019) : le payload publié gagne une clé « videos »
-- UNIQUEMENT pour les cantiques qui ont une vidéo diffusable (les autres
-- payloads restent identiques octet pour octet) ; une vidéo aux droits
-- « restricted » n'est jamais publiée ; ajouter, modifier ou retirer une
-- vidéo ne repasse pas le cantique en brouillon (le texte n'a pas changé).

create table public.hymn_videos (
  id uuid primary key default gen_random_uuid(),
  hymn_id uuid not null references public.hymns (id) on delete cascade,
  media_type public.media_type not null,
  youtube_id text not null,
  title text,
  rights_status public.rights_status not null default 'unknown',
  created_at timestamptz not null default now(),
  constraint hymn_videos_youtube_id check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  constraint hymn_videos_title check (title is null or char_length(title) between 1 and 300),
  constraint hymn_videos_unique unique (hymn_id, youtube_id)
);

create index hymn_videos_hymn_id_idx on public.hymn_videos (hymn_id);

-- Copie de travail : réservée aux éditeurs, comme les autres tables (0007).
alter table public.hymn_videos enable row level security;
grant select, insert, update, delete on public.hymn_videos to authenticated;

create policy "hymn_videos : lecture éditeur" on public.hymn_videos
  for select to authenticated using ((select private.has_role('editor')));
create policy "hymn_videos : création éditeur" on public.hymn_videos
  for insert to authenticated with check ((select private.has_role('editor')));
create policy "hymn_videos : modification éditeur" on public.hymn_videos
  for update to authenticated
  using ((select private.has_role('editor')))
  with check ((select private.has_role('editor')));
create policy "hymn_videos : suppression" on public.hymn_videos
  for delete to authenticated using ((select private.has_role('editor')));

create trigger audit after insert or update or delete on public.hymn_videos
  for each row execute function private.audit_row();

-- Vidéos publiables d'un cantique (contrat HymnVideo de packages/shared_contracts).
create function private.hymn_videos(p_hymn_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_agg(
    jsonb_build_object(
      'id', v.id,
      'mediaType', v.media_type,
      'youtubeId', v.youtube_id,
      'title', v.title
    )
    order by v.media_type, v.created_at, v.id
  )
  from public.hymn_videos v
  where v.hymn_id = p_hymn_id
    and private.effective_media_rights_status(v.id, v.rights_status) <> 'restricted'
$$;

-- Même contenu que la 0019, plus la clé « videos » si elle n'est pas vide.
create or replace function private.hymn_payload(p_hymn_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', h.id,
    'numberLabel', h.number_label,
    'numberNumeric', h.number_numeric,
    'numberSuffix', h.number_suffix,
    'title', h.title,
    'openingLine', h.opening_line,
    'languageCode', h.language_code,
    'sections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'type', s.section_type,
          'number', s.section_number,
          'order', s.display_order,
          'lines', private.section_lines(s.text)
        )
        order by s.display_order
      )
      from public.hymn_sections s
      where s.hymn_id = h.id
    ), '[]'::jsonb),
    'bibleReferences', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'displayText', coalesce(
            b.display_text,
            b.book || ' ' || b.chapter_start || coalesce('.' || b.verse_start, '')
          ),
          'book', b.book,
          'chapterStart', b.chapter_start,
          'verseStart', b.verse_start,
          'chapterEnd', b.chapter_end,
          'verseEnd', b.verse_end
        )
        order by b.chapter_start, b.verse_start nulls first, b.id
      )
      from public.bible_references b
      where b.hymn_id = h.id
    ), '[]'::jsonb),
    'relations', coalesce((
      select jsonb_agg(
        jsonb_build_object('type', r.relation, 'relatedHymnId', r.related_hymn_id)
        order by r.relation, r.related_hymn_id
      )
      from public.hymn_relations r
      where r.hymn_id = h.id
    ), '[]'::jsonb),
    'people', coalesce((
      select jsonb_agg(
        jsonb_build_object('role', hp.role, 'fullName', p.full_name)
        order by hp.role, p.full_name
      )
      from public.hymn_people hp
      join public.people p on p.id = hp.person_id
      where hp.hymn_id = h.id
    ), '[]'::jsonb),
    'themes', coalesce((
      select jsonb_agg(t.name order by t.name)
      from public.hymn_themes ht
      join public.themes t on t.id = ht.theme_id
      where ht.hymn_id = h.id
    ), '[]'::jsonb)
  )
  || coalesce(
    (select jsonb_build_object('audio', a.tracks)
       from (select private.hymn_audio(h.id) as tracks) a
      where a.tracks is not null),
    '{}'::jsonb
  )
  || coalesce(
    (select jsonb_build_object('videos', v.videos)
       from (select private.hymn_videos(h.id) as videos) v
      where v.videos is not null),
    '{}'::jsonb
  )
  from public.hymns h
  where h.id = p_hymn_id
$$;
