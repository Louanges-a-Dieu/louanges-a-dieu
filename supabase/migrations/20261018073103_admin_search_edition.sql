-- Migration 0016 — Recherche du back-office filtrable par édition.

drop function public.search_hymns_admin(text, public.publication_status, text, public.rights_status, integer, integer);

create function public.search_hymns_admin(
  p_query text default null,
  p_status public.publication_status default null,
  p_issues text default null,
  p_rights public.rights_status default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_edition_id uuid default null
)
returns table (
  id uuid,
  number_label text,
  number_numeric integer,
  title text,
  opening_line text,
  status public.publication_status,
  rights_status public.rights_status,
  open_issues integer,
  blocking_issues integer,
  updated_at timestamptz,
  total_count bigint
)
language sql
stable
set search_path = ''
as $$
  with q as (
    select nullif(btrim(private.f_unaccent(lower(coalesce(p_query, '')))), '') as text,
           lower(replace(coalesce(p_query, ''), ' ', '')) as compact
  ),
  base as (
    select h.id, h.number_label, h.number_numeric, h.title, h.opening_line, h.status,
           private.effective_rights_status(h.id) as rights_status,
           (select count(*)::integer from public.import_issues i
             where i.hymn_id = h.id and i.status = 'open') as open_issues,
           (select count(*)::integer from public.import_issues i
             where i.hymn_id = h.id and i.status = 'open' and i.severity = 'blocking') as blocking_issues,
           h.updated_at
      from public.hymns h, q
     where (p_status is null or h.status = p_status)
       and (p_edition_id is null or h.edition_id = p_edition_id)
       and (
         q.text is null
         or h.number_label = q.compact
         or h.number_label like q.compact || '%'
         or private.f_unaccent(lower(h.title || ' ' || coalesce(h.opening_line, ''))) like '%' || q.text || '%'
         or exists (
           select 1 from public.hymn_sections s
            where s.hymn_id = h.id
              and private.f_unaccent(lower(s.text)) like '%' || q.text || '%'
         )
       )
  )
  select b.*, count(*) over () as total_count
    from base b
   where (p_rights is null or b.rights_status = p_rights)
     and (p_issues is null
          or (p_issues = 'open' and b.open_issues > 0)
          or (p_issues = 'blocking' and b.blocking_issues > 0)
          or (p_issues = 'none' and b.open_issues = 0))
   order by b.number_numeric, b.number_label
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0))
$$;

revoke all on function public.search_hymns_admin(text, public.publication_status, text, public.rights_status, integer, integer, uuid)
  from public, anon;
grant execute on function public.search_hymns_admin(text, public.publication_status, text, public.rights_status, integer, integer, uuid)
  to authenticated;
