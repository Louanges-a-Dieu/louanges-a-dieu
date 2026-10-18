-- Empreinte d'une base, comparée entre la source et la restauration.
-- Une ligne « table=nombre » par table importante, dans un ordre stable.
select 'auth.users=' || count(*) from auth.users
union all select 'public.editions=' || count(*) from public.editions
union all select 'public.hymns=' || count(*) from public.hymns
union all select 'public.hymn_sections=' || count(*) from public.hymn_sections
union all select 'public.bible_references=' || count(*) from public.bible_references
union all select 'public.catalog_releases=' || count(*) from public.catalog_releases
union all select 'public.published_hymns=' || count(*) from public.published_hymns
union all select 'public.import_issues=' || count(*) from public.import_issues
union all select 'public.rights_records=' || count(*) from public.rights_records
union all select 'public.user_roles=' || count(*) from public.user_roles
union all select 'public.favorites=' || count(*) from public.favorites
union all select 'public.playlists=' || count(*) from public.playlists
union all select 'public.worship_services=' || count(*) from public.worship_services
union all select 'public.audit_log=' || count(*) from public.audit_log
union all select 'derniere_release=' || coalesce(max(id)::text, 'aucune') from public.catalog_releases
union all select 'empreinte_catalogue=' || coalesce(
  (select content_hash from public.catalog_releases order by id desc limit 1), 'aucune');
