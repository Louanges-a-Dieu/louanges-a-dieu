-- Migration 0018 — Tableau de bord par édition (la base peut en contenir plusieurs).

drop function public.editorial_stats();

create function public.editorial_stats(p_edition_id uuid default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'byStatus', coalesce((select jsonb_object_agg(s.status, s.n)
                            from (select h.status, count(*) as n from public.hymns h
                                   where p_edition_id is null or h.edition_id = p_edition_id
                                   group by h.status) s),
                         '{}'::jsonb),
    'total', (select count(*) from public.hymns h
               where p_edition_id is null or h.edition_id = p_edition_id),
    'openIssues', coalesce((select jsonb_object_agg(i.severity, i.n)
                              from (select ii.severity, count(*) as n
                                      from public.import_issues ii
                                      join public.import_batches b on b.id = ii.batch_id
                                     where ii.status = 'open'
                                       and (p_edition_id is null or b.edition_id = p_edition_id)
                                     group by ii.severity) i),
                           '{}'::jsonb),
    'latestRelease', (select jsonb_build_object('id', r.id, 'publishedAt', r.published_at,
                                                'hymnCount', r.hymn_count, 'notes', r.notes)
                        from public.catalog_releases r
                       where p_edition_id is null or r.edition_id = p_edition_id
                       order by r.id desc limit 1)
  )
  where private.has_role('editor')
$$;

revoke all on function public.editorial_stats(uuid) from public, anon;
grant execute on function public.editorial_stats(uuid) to authenticated;
