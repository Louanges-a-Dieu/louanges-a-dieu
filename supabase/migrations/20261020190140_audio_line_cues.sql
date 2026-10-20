-- Migration 0021 — Karaoké : passages repérés ligne par ligne
--
-- Un passage peut désormais désigner une LIGNE d'une section (line_index,
-- 0 = premier vers) et non plus seulement la section entière. Une piste
-- synchronisée ligne par ligne permet le karaoké : l'app met en avant le
-- vers chanté. Les passages par section restent valables (line_index null).

alter table public.audio_segments
  add column line_index integer,
  add constraint audio_segments_line_index check (
    line_index is null or (line_index >= 0 and section_id is not null)
  );

-- Pistes publiables : même contenu que la 0019, plus « lineIndex ».
create or replace function private.hymn_audio(p_hymn_id uuid)
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
            'lineIndex', case when hs.id is not null then g.line_index end,
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

-- Même règles que la 0020, plus la ligne : elle doit exister dans la section
-- (vers non vides, comme dans le contenu publié).
create or replace function public.set_audio_segments(p_track_id uuid, p_segments jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_hymn_id uuid;
  v_count integer;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  if jsonb_typeof(p_segments) is distinct from 'array' then
    raise exception 'Liste de passages attendue' using errcode = 'invalid_parameter_value';
  end if;

  select t.hymn_id into v_hymn_id from public.audio_tracks t where t.id = p_track_id;
  if v_hymn_id is null then
    raise exception 'Enregistrement introuvable' using errcode = 'no_data_found';
  end if;

  -- Une section citée doit appartenir au cantique de la piste.
  if exists (
    select 1
      from jsonb_array_elements(p_segments) e
     where e ->> 'section_id' is not null
       and not exists (
         select 1 from public.hymn_sections s
          where s.id = (e ->> 'section_id')::uuid and s.hymn_id = v_hymn_id
       )
  ) then
    raise exception 'Section étrangère à ce cantique' using errcode = 'foreign_key_violation';
  end if;

  -- Une ligne citée doit exister dans sa section.
  if exists (
    select 1
      from jsonb_array_elements(p_segments) e
      join public.hymn_sections s on s.id = (e ->> 'section_id')::uuid
     where e ->> 'line_index' is not null
       and (e ->> 'line_index')::integer >= (
         select count(*)
           from regexp_split_to_table(s.text, E'\n') as l (line)
          where not private.is_blank(l.line)
       )
  ) then
    raise exception 'Ligne inexistante dans la section' using errcode = 'check_violation';
  end if;

  delete from public.audio_segments where audio_track_id = p_track_id;

  insert into public.audio_segments
    (audio_track_id, section_id, line_index, start_ms, end_ms, display_order)
  select p_track_id,
         (e ->> 'section_id')::uuid,
         (e ->> 'line_index')::integer,
         (e ->> 'start_ms')::bigint,
         (e ->> 'end_ms')::bigint,
         (n - 1)::integer
    from jsonb_array_elements(p_segments) with ordinality as x (e, n);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
