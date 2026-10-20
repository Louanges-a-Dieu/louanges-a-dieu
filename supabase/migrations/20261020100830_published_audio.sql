-- Migration 0019 — Enregistrements audio dans le contenu publié (ADR-016 révisé)
--
-- Les fichiers audio sont hébergés sur Backblaze B2 (décision du propriétaire,
-- 2026-10-20). La base ne garde que leur clé RELATIVE dans le compartiment
-- (« cantiques/0037bis/melodie.mp3 ») : l'adresse publique est composée par
-- les clients avec l'adresse de base de leur configuration, si bien qu'un
-- changement d'hébergeur ou l'ajout d'un CDN ne touche pas aux données.
--
-- Le payload publié gagne une clé « audio » UNIQUEMENT pour les cantiques qui
-- ont au moins un enregistrement diffusable : les autres payloads restent
-- identiques octet pour octet (pas de nouvelle version de tout le catalogue).
-- Un enregistrement aux droits « restricted » (sur la piste ou par un
-- rights_records rattaché à la piste) n'est jamais publié.

-- Clé relative, sans schéma ni « .. », d'un format lisible partout
-- (iOS, Android, navigateurs) : MP3 ou AAC.
alter table public.audio_tracks
  add constraint audio_tracks_storage_key_relative check (
    storage_key ~ '^[A-Za-z0-9][A-Za-z0-9._/-]*\.(mp3|m4a|aac)$'
    and storage_key !~ '\.\.'
    and storage_key !~ '//'
  ),
  add constraint audio_tracks_duration_positive check (
    duration_seconds is null or duration_seconds > 0
  );

-- Droits effectifs d'une piste : dernier rights_records valide rattaché à la
-- piste, sinon le statut porté par la piste.
create function private.effective_media_rights_status(
  p_media_id uuid,
  p_fallback public.rights_status
)
returns public.rights_status
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select rr.rights_status
      from public.rights_records rr
      where rr.media_id = p_media_id
        and (rr.valid_until is null or rr.valid_until >= current_date)
      order by rr.created_at desc, rr.id
      limit 1
    ),
    p_fallback
  )
$$;

revoke all on function private.effective_media_rights_status(uuid, public.rights_status)
  from public, anon;
grant execute on function private.effective_media_rights_status(uuid, public.rights_status)
  to authenticated;

-- Pistes publiables d'un cantique (contrat AudioTrack de packages/shared_contracts).
create function private.hymn_audio(p_hymn_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'mediaType', t.media_type,
      'storageKey', t.storage_key,
      'durationSeconds', t.duration_seconds,
      'segments', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            -- Une section d'un autre cantique n'est jamais exposée.
            'sectionId', hs.id,
            'startMs', g.start_ms,
            'endMs', g.end_ms,
            'order', g.display_order
          )
          order by g.display_order
        )
        from public.audio_segments g
        left join public.hymn_sections hs
          on hs.id = g.section_id and hs.hymn_id = t.hymn_id
        where g.audio_track_id = t.id
      ), '[]'::jsonb)
    )
    order by t.media_type, t.created_at, t.id
  )
  from public.audio_tracks t
  where t.hymn_id = p_hymn_id
    and private.effective_media_rights_status(t.id, t.rights_status) <> 'restricted'
$$;

-- Même contenu que la version 0008, plus la clé « audio » si elle n'est pas vide.
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
  from public.hymns h
  where h.id = p_hymn_id
$$;
