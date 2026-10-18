-- Migration 0017 — Aperçu d'un cantique et décision sur les anomalies (Phase 9).

-- Aperçu « comme sur mobile » (9.5) : exactement le contenu qu'une
-- publication enverrait aux applications (contrat PublishedHymn).
create function public.preview_hymn(p_hymn_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.hymns h where h.id = p_hymn_id) then
    return null;
  end if;
  return private.hymn_payload(p_hymn_id);
end;
$$;

revoke all on function public.preview_hymn(uuid) from public, anon;
grant execute on function public.preview_hymn(uuid) to authenticated;

-- File d'anomalies (9.8) : résoudre, ignorer (justification obligatoire) ou
-- rouvrir. L'auteur et la date sont fixés par le serveur.
create function public.resolve_issues(
  p_issue_ids uuid[],
  p_status public.issue_status,
  p_note text default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  if p_status = 'ignored' and private.is_blank(p_note) then
    raise exception 'Une justification est obligatoire pour ignorer une anomalie'
      using errcode = 'check_violation';
  end if;
  update public.import_issues i
     set status = p_status,
         resolution_note = case when p_status = 'open' then null else nullif(btrim(p_note), '') end,
         resolved_by = case when p_status = 'open' then null else auth.uid() end,
         resolved_at = case when p_status = 'open' then null else now() end
   where i.id = any (p_issue_ids);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.resolve_issues(uuid[], public.issue_status, text) from public, anon;
grant execute on function public.resolve_issues(uuid[], public.issue_status, text) to authenticated;
