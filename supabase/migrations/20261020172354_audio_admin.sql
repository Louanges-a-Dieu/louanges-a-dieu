-- Migration 0020 — Back-office : enregistrements audio
--
-- 1. Journal : les pistes et leurs passages sont tracés comme le reste de la
--    copie de travail (oubli de la 0005, tables alors inutilisées).
-- 2. set_audio_segments : remplace TOUS les passages d'une piste en une seule
--    transaction (jamais de piste à moitié découpée). Exécutée avec les droits
--    de l'appelant : la RLS éditeur s'applique.

create trigger audit after insert or update or delete on public.audio_tracks
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.audio_segments
  for each row execute function private.audit_row();

create function public.set_audio_segments(p_track_id uuid, p_segments jsonb)
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

  delete from public.audio_segments where audio_track_id = p_track_id;

  insert into public.audio_segments (audio_track_id, section_id, start_ms, end_ms, display_order)
  select p_track_id,
         (e ->> 'section_id')::uuid,
         (e ->> 'start_ms')::bigint,
         (e ->> 'end_ms')::bigint,
         (n - 1)::integer
    from jsonb_array_elements(p_segments) with ordinality as x (e, n);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.set_audio_segments(uuid, jsonb) from public, anon;
grant execute on function public.set_audio_segments(uuid, jsonb) to authenticated;
