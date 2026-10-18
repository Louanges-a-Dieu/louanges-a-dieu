-- Migration 0015 — Back-office éditorial (Phase 9)
--
-- 1. MFA obligatoire pour les rôles éditoriaux, appliquée DANS la base : un
--    rôle n'est reconnu qu'avec une session « aal2 » (second facteur TOTP
--    vérifié). Une session volée sans second facteur n'a aucun droit
--    d'édition, même en appelant l'API directement.
-- 2. Publication : aperçu des changements avant publication, retour arrière
--    vers une release précédente (nouvelle release au contenu identique).
-- 3. Import du catalogue brouillon (logique unique, appelée par le
--    back-office ET par l'outil en ligne de commande), avec simulation.
-- 4. Recherche et statistiques du back-office ; gestion de l'équipe ; journal.

-- ---------------------------------------------------------------------------
-- 1. MFA obligatoire (9.1)
-- ---------------------------------------------------------------------------

create or replace function private.has_role(required public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'aal'), 'aal1') = 'aal2'
     and exists (
       select 1
       from public.user_roles ur
       where ur.user_id = (select auth.uid())
         and (ur.role = required or ur.role = 'super_admin')
     )
$$;

-- ---------------------------------------------------------------------------
-- 2. Publication : candidats communs, aperçu, retour arrière (9.7)
-- ---------------------------------------------------------------------------

-- Contenu de la prochaine release (même règle que publish_release, T-009).
-- Interne : appelée uniquement par les fonctions SECURITY DEFINER ci-dessous.
create function private.release_candidates(p_edition_id uuid, p_prev integer)
returns table (hymn_id uuid, payload jsonb, payload_hash text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.hymn_id, c.payload, private.sha256_hex(c.payload::text)
    from (
      select h.id as hymn_id, private.hymn_payload(h.id) as payload
        from public.hymns h
       where h.edition_id = p_edition_id
         and h.status = 'published'
         and private.effective_rights_status(h.id) <> 'restricted'
      union all
      select ph.hymn_id, ph.payload
        from public.published_hymns ph
        join public.hymns h on h.id = ph.hymn_id
       where ph.release_id = p_prev
         and h.status in ('draft', 'review')
         and private.effective_rights_status(h.id) <> 'restricted'
    ) as c
$$;

revoke all on function private.release_candidates(uuid, integer) from public, anon, authenticated;

create or replace function public.publish_release(p_edition_id uuid, p_notes text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prev integer;
  v_prev_hash text;
  v_hash text;
  v_count integer;
  v_new integer;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('lad.publish_release', 0));

  select r.id, r.content_hash into v_prev, v_prev_hash
    from public.catalog_releases r
   where r.edition_id = p_edition_id
   order by r.id desc
   limit 1;

  drop table if exists pg_temp.release_candidates;
  create temporary table release_candidates on commit drop as
  select * from private.release_candidates(p_edition_id, v_prev);

  select count(*), private.sha256_hex(
           coalesce(string_agg(rc.hymn_id::text || ':' || rc.payload_hash, ',' order by rc.hymn_id), '')
         )
    into v_count, v_hash
    from pg_temp.release_candidates rc;

  if v_count = 0 then
    raise exception 'Aucun cantique validé à publier' using errcode = 'check_violation';
  end if;

  if v_hash = v_prev_hash then
    raise notice 'Aucun changement depuis la release %', v_prev;
    return v_prev;
  end if;

  insert into public.catalog_releases (edition_id, notes, hymn_count, content_hash)
  values (p_edition_id, p_notes, v_count, v_hash)
  returning id into v_new;

  insert into public.published_hymns (release_id, hymn_id, payload, payload_hash)
  select v_new, rc.hymn_id, rc.payload, rc.payload_hash
    from pg_temp.release_candidates rc;

  return v_new;
end;
$$;

-- Ce que changerait une publication maintenant, par rapport à la release
-- courante : cantiques ajoutés, modifiés, retirés.
create function public.preview_release(p_edition_id uuid)
returns table (hymn_id uuid, number_label text, title text, change text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_prev integer;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  select max(r.id) into v_prev from public.catalog_releases r where r.edition_id = p_edition_id;
  return query
    with c as (select * from private.release_candidates(p_edition_id, v_prev)),
         p as (select ph.hymn_id, ph.payload, ph.payload_hash
                 from public.published_hymns ph where ph.release_id = v_prev)
    select coalesce(c.hymn_id, p.hymn_id),
           coalesce(c.payload, p.payload) ->> 'numberLabel',
           coalesce(c.payload, p.payload) ->> 'title',
           case when p.hymn_id is null then 'added'
                when c.hymn_id is null then 'removed'
                else 'changed' end
      from c full join p on p.hymn_id = c.hymn_id
     where c.hymn_id is null or p.hymn_id is null or c.payload_hash <> p.payload_hash
     order by (coalesce(c.payload, p.payload) ->> 'numberNumeric')::integer,
              coalesce(c.payload, p.payload) ->> 'numberLabel';
end;
$$;

revoke all on function public.preview_release(uuid) from public, anon;
grant execute on function public.preview_release(uuid) to authenticated;

-- Retour arrière : publie une NOUVELLE release au contenu identique à une
-- release précédente (les applications la reçoivent comme une mise à jour).
-- La copie de travail n'est pas modifiée.
create function public.rollback_release(
  p_edition_id uuid,
  p_release_id integer,
  p_notes text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prev integer;
  v_prev_hash text;
  v_target public.catalog_releases;
  v_new integer;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('lad.publish_release', 0));

  select r.id, r.content_hash into v_prev, v_prev_hash
    from public.catalog_releases r
   where r.edition_id = p_edition_id
   order by r.id desc
   limit 1;

  select * into v_target
    from public.catalog_releases r
   where r.id = p_release_id and r.edition_id = p_edition_id;
  if v_target.id is null then
    raise exception 'Release % introuvable pour cette édition', p_release_id
      using errcode = 'no_data_found';
  end if;
  if v_target.id = v_prev or v_target.content_hash = v_prev_hash then
    return v_prev;
  end if;

  insert into public.catalog_releases (edition_id, notes, hymn_count, content_hash)
  values (
    p_edition_id,
    coalesce(nullif(btrim(p_notes), ''), format('Retour au contenu de la release %s', p_release_id)),
    v_target.hymn_count,
    v_target.content_hash
  )
  returning id into v_new;

  insert into public.published_hymns (release_id, hymn_id, payload, payload_hash)
  select v_new, ph.hymn_id, ph.payload, ph.payload_hash
    from public.published_hymns ph
   where ph.release_id = p_release_id;

  return v_new;
end;
$$;

revoke all on function public.rollback_release(uuid, integer, text) from public, anon;
grant execute on function public.rollback_release(uuid, integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Import du catalogue brouillon (9.9)
-- ---------------------------------------------------------------------------

-- Charge un catalogue brouillon (contrat CatalogDraft, validé par Zod en
-- amont) dans la copie de travail, EN TANT QU'ÉDITEUR (RLS, brouillon forcé,
-- journal). Un cantique existant n'est jamais écrasé : texte différent →
-- anomalie A-20 ; absent de la source → A-21. Idempotent. Avec p_dry_run,
-- rien n'est écrit : on obtient le diff de réimport.
create function public.import_catalog_draft(p_draft jsonb, p_dry_run boolean default false)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_edition_id uuid;
  v_edition_created boolean := false;
  v_batch_id uuid;
  v_inserted text[];
  v_unchanged text[];
  v_changed text[];
  v_missing text[];
  v_issues integer := 0;
  v_summary jsonb;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  if p_draft ->> 'format' is distinct from 'lad.catalog-draft' then
    raise exception 'Format de catalogue inattendu' using errcode = 'invalid_parameter_value';
  end if;

  select e.id into v_edition_id
    from public.editions e
   where e.name = p_draft #>> '{edition,name}'
     and e.edition_number is not distinct from (p_draft #>> '{edition,editionNumber}')::integer;
  v_edition_created := v_edition_id is null;
  if v_edition_created and not p_dry_run then
    insert into public.editions (name, edition_number, source_filename)
    values (p_draft #>> '{edition,name}',
            (p_draft #>> '{edition,editionNumber}')::integer,
            p_draft #>> '{source,filename}')
    returning id into v_edition_id;
  end if;

  -- Empreinte comparable : titre, premier vers, sections, références triées.
  drop table if exists pg_temp.draft_hymns;
  create temporary table draft_hymns on commit drop as
  select h ->> 'numberLabel' as label,
         h as doc,
         gen_random_uuid() as new_id,
         jsonb_build_array(
           h ->> 'title',
           h -> 'openingLine',
           (select coalesce(jsonb_agg(jsonb_build_array(s ->> 'type', s ->> 'text')
                                      order by (s ->> 'order')::integer), '[]'::jsonb)
              from jsonb_array_elements(h -> 'sections') s),
           (select coalesce(jsonb_agg(x order by x), '[]'::jsonb)
              from (select r ->> 'displayText' as x
                      from jsonb_array_elements(h -> 'bibleReferences') r) q)
         ) as fp
    from jsonb_array_elements(p_draft -> 'hymns') h;

  drop table if exists pg_temp.existing_hymns;
  create temporary table existing_hymns on commit drop as
  select h.id, h.number_label as label,
         jsonb_build_array(
           h.title,
           h.opening_line,
           (select coalesce(jsonb_agg(jsonb_build_array(s.section_type::text, s.text)
                                      order by s.display_order), '[]'::jsonb)
              from public.hymn_sections s where s.hymn_id = h.id),
           (select coalesce(jsonb_agg(x order by x), '[]'::jsonb)
              from (select coalesce(b.display_text, b.book || ' ' || b.chapter_start) as x
                      from public.bible_references b where b.hymn_id = h.id) q)
         ) as fp
    from public.hymns h
   where h.edition_id = v_edition_id;

  select coalesce(array_agg(d.label order by d.label), '{}') into v_inserted
    from pg_temp.draft_hymns d
   where not exists (select 1 from pg_temp.existing_hymns e where e.label = d.label);
  select coalesce(array_agg(d.label order by d.label), '{}') into v_unchanged
    from pg_temp.draft_hymns d join pg_temp.existing_hymns e on e.label = d.label
   where e.fp = d.fp;
  select coalesce(array_agg(d.label order by d.label), '{}') into v_changed
    from pg_temp.draft_hymns d join pg_temp.existing_hymns e on e.label = d.label
   where e.fp <> d.fp;
  select coalesce(array_agg(e.label order by e.label), '{}') into v_missing
    from pg_temp.existing_hymns e
   where not exists (select 1 from pg_temp.draft_hymns d where d.label = e.label);

  v_summary := jsonb_build_object(
    'editionId', v_edition_id,
    'editionCreated', v_edition_created,
    'batchId', null,
    'inserted', to_jsonb(v_inserted),
    'unchanged', to_jsonb(v_unchanged),
    'changed', to_jsonb(v_changed),
    'missingFromSource', to_jsonb(v_missing),
    'issuesCreated', 0,
    'dryRun', p_dry_run
  );

  if p_dry_run
     or (cardinality(v_inserted) = 0 and cardinality(v_changed) = 0 and cardinality(v_missing) = 0) then
    return v_summary;
  end if;

  insert into public.import_batches (edition_id, source_filename, source_sha256, parser_version, stats)
  values (
    v_edition_id,
    p_draft #>> '{source,filename}',
    p_draft #>> '{source,sha256}',
    p_draft #>> '{source,parserVersion}',
    jsonb_build_object(
      'inserted', cardinality(v_inserted),
      'unchanged', cardinality(v_unchanged),
      'changed', cardinality(v_changed),
      'missingFromSource', cardinality(v_missing)
    )
  )
  returning id into v_batch_id;

  -- Nouveaux cantiques, sections, références, relations « bis ».
  insert into public.hymns (id, edition_id, number_label, number_numeric, number_suffix, title,
                            opening_line, source_paragraph_start, source_paragraph_end, import_batch_id)
  select d.new_id, v_edition_id, d.label, (d.doc ->> 'numberNumeric')::integer,
         d.doc ->> 'numberSuffix', d.doc ->> 'title', d.doc ->> 'openingLine',
         (d.doc ->> 'sourceParagraphStart')::integer, (d.doc ->> 'sourceParagraphEnd')::integer,
         v_batch_id
    from pg_temp.draft_hymns d
   where d.label = any (v_inserted);

  insert into public.hymn_sections (hymn_id, section_type, text, display_order)
  select d.new_id, (s ->> 'type')::public.section_type, s ->> 'text', (s ->> 'order')::integer
    from pg_temp.draft_hymns d, jsonb_array_elements(d.doc -> 'sections') s
   where d.label = any (v_inserted);

  insert into public.bible_references (hymn_id, book, chapter_start, verse_start, chapter_end,
                                       verse_end, display_text)
  select d.new_id, r ->> 'book', (r ->> 'chapterStart')::integer, (r ->> 'verseStart')::integer,
         (r ->> 'chapterEnd')::integer, (r ->> 'verseEnd')::integer, r ->> 'displayText'
    from pg_temp.draft_hymns d, jsonb_array_elements(d.doc -> 'bibleReferences') r
   where d.label = any (v_inserted);

  insert into public.hymn_relations (hymn_id, related_hymn_id, relation)
  select d.new_id, coalesce(t.new_id, e.id), 'bis_of'
    from pg_temp.draft_hymns d
    cross join lateral jsonb_array_elements(d.doc -> 'relations') rel
    left join pg_temp.draft_hymns t
      on t.label = rel ->> 'relatedNumberLabel' and t.label = any (v_inserted)
    left join pg_temp.existing_hymns e on e.label = rel ->> 'relatedNumberLabel'
   where d.label = any (v_inserted)
     and coalesce(t.new_id, e.id) is not null
  on conflict do nothing;

  -- Anomalies : du document et des cantiques insérés, puis A-20 / A-21.
  with ids as (
    select d.label, d.new_id as id from pg_temp.draft_hymns d where d.label = any (v_inserted)
    union all
    select e.label, e.id from pg_temp.existing_hymns e
  ),
  issues as (
    select (select ids.id from ids where ids.label = i ->> 'numberLabel') as hymn_id,
           i ->> 'code' as code, i ->> 'severity' as severity, i ->> 'message' as message,
           coalesce(i -> 'details', '{}'::jsonb)
             || jsonb_build_object('numberLabel', i -> 'numberLabel') as details
      from jsonb_array_elements(p_draft -> 'issues') i
     where i ->> 'numberLabel' is null or i ->> 'numberLabel' = any (v_inserted)
    union all
    select e.id, 'A-20', 'warning',
           'Le texte source diffère de la version en base : non écrasé, à arbitrer',
           jsonb_build_object('sourceTitle', d.doc -> 'title', 'sourceSections', d.doc -> 'sections',
                              'numberLabel', d.label)
      from pg_temp.draft_hymns d join pg_temp.existing_hymns e on e.label = d.label
     where d.label = any (v_changed)
    union all
    select e.id, 'A-21', 'warning',
           'Cantique présent en base mais absent de la source importée',
           jsonb_build_object('numberLabel', e.label)
      from pg_temp.existing_hymns e
     where e.label = any (v_missing)
  ),
  created as (
    insert into public.import_issues (batch_id, hymn_id, code, severity, message, details)
    select v_batch_id, issues.hymn_id, issues.code, issues.severity::public.issue_severity,
           issues.message, issues.details
      from issues
    returning 1
  )
  select count(*) into v_issues from created;

  return v_summary
    || jsonb_build_object('batchId', v_batch_id, 'issuesCreated', v_issues);
end;
$$;

revoke all on function public.import_catalog_draft(jsonb, boolean) from public, anon;
grant execute on function public.import_catalog_draft(jsonb, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Recherche, statistiques, équipe, journal
-- ---------------------------------------------------------------------------

-- Liste filtrée du back-office (RLS de l'appelant : éditeurs uniquement).
-- Recherche sans accents dans le numéro, le titre, le premier vers et le texte.
create function public.search_hymns_admin(
  p_query text default null,
  p_status public.publication_status default null,
  p_issues text default null,
  p_rights public.rights_status default null,
  p_limit integer default 50,
  p_offset integer default 0
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

revoke all on function public.search_hymns_admin(text, public.publication_status, text, public.rights_status, integer, integer)
  from public, anon;
grant execute on function public.search_hymns_admin(text, public.publication_status, text, public.rights_status, integer, integer)
  to authenticated;

-- Tableau de bord (9.2).
create function public.editorial_stats()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'byStatus', coalesce((select jsonb_object_agg(s.status, s.n)
                            from (select h.status, count(*) as n from public.hymns h group by h.status) s),
                         '{}'::jsonb),
    'total', (select count(*) from public.hymns),
    'openIssues', coalesce((select jsonb_object_agg(i.severity, i.n)
                              from (select severity, count(*) as n from public.import_issues
                                     where status = 'open' group by severity) i),
                           '{}'::jsonb),
    'latestRelease', (select jsonb_build_object('id', r.id, 'publishedAt', r.published_at,
                                                'hymnCount', r.hymn_count, 'notes', r.notes)
                        from public.catalog_releases r order by r.id desc limit 1)
  )
  where private.has_role('editor')
$$;

revoke all on function public.editorial_stats() from public, anon;
grant execute on function public.editorial_stats() to authenticated;

-- Équipe éditoriale (super_admin) : membres et e-mails, attribution et
-- retrait de rôles par e-mail. Jamais le dernier super_admin.
create function public.admin_list_team()
returns table (user_id uuid, email text, roles public.app_role[], last_sign_in_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.email::text, array_agg(ur.role order by ur.role), u.last_sign_in_at
    from public.user_roles ur
    join auth.users u on u.id = ur.user_id
   where private.has_role('super_admin')
   group by u.id, u.email, u.last_sign_in_at
   order by u.email
$$;

create function public.admin_grant_role(p_email text, p_role public.app_role)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if not private.has_role('super_admin') then
    raise exception 'Rôle super_admin requis' using errcode = 'insufficient_privilege';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(btrim(p_email));
  if v_user is null then
    raise exception 'Aucun compte pour cette adresse : la personne doit d''abord se connecter une fois'
      using errcode = 'no_data_found';
  end if;
  insert into public.user_roles (user_id, role, granted_by)
  values (v_user, p_role, auth.uid())
  on conflict (user_id, role) do nothing;
  return v_user;
end;
$$;

create function public.admin_revoke_role(p_user_id uuid, p_role public.app_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_role('super_admin') then
    raise exception 'Rôle super_admin requis' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('lad.user_roles', 0));
  if p_role = 'super_admin'
     and (select count(*) from public.user_roles where role = 'super_admin') <= 1
     and exists (select 1 from public.user_roles where user_id = p_user_id and role = 'super_admin') then
    raise exception 'Impossible de retirer le dernier super_admin' using errcode = 'check_violation';
  end if;
  delete from public.user_roles where user_id = p_user_id and role = p_role;
end;
$$;

-- Journal consultable (9.10) avec l'adresse de l'auteur (membres de l'équipe).
create function public.admin_audit_log(
  p_record_id text default null,
  p_limit integer default 100,
  p_before bigint default null
)
returns table (
  id bigint,
  occurred_at timestamptz,
  actor_email text,
  table_name text,
  record_id text,
  action text,
  changes jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.occurred_at, u.email::text, a.table_name, a.record_id, a.action, a.changes
    from public.audit_log a
    left join auth.users u on u.id = a.actor_id
   where private.has_role('editor')
     and (p_record_id is null or a.record_id = p_record_id)
     and (p_before is null or a.id < p_before)
   order by a.id desc
   limit greatest(1, least(coalesce(p_limit, 100), 500))
$$;

revoke all on function public.admin_list_team() from public, anon;
revoke all on function public.admin_grant_role(text, public.app_role) from public, anon;
revoke all on function public.admin_revoke_role(uuid, public.app_role) from public, anon;
revoke all on function public.admin_audit_log(text, integer, bigint) from public, anon;
grant execute on function public.admin_list_team() to authenticated;
grant execute on function public.admin_grant_role(text, public.app_role) to authenticated;
grant execute on function public.admin_revoke_role(uuid, public.app_role) to authenticated;
grant execute on function public.admin_audit_log(text, integer, bigint) to authenticated;
