-- Migration 0008 — Releases de catalogue (ADR-004, ADR-005, ADR-008, ADR-018)
--
-- Le public (applications, anon) ne lit JAMAIS la copie de travail : il lit la
-- dernière release, un instantané immuable produit par publish_release().
-- Une release contient :
--   - les cantiques validés (status = 'published') non restreints, dans leur
--     version courante ;
--   - pour les cantiques en cours de correction (draft/review), la version
--     publiée précédente, inchangée (T-009) ;
--   - et rien d'autre (archivés et restreints sont retirés).
-- Le contenu (payload) suit le contrat PublishedHymn de packages/shared_contracts.

create table public.catalog_releases (
  id integer generated always as identity primary key,
  edition_id uuid not null references public.editions (id) on delete restrict,
  published_at timestamptz not null default now(),
  notes text check (notes is null or not private.is_blank(notes)),
  hymn_count integer not null check (hymn_count > 0),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$')
);

create table public.published_hymns (
  release_id integer not null references public.catalog_releases (id) on delete cascade,
  hymn_id uuid not null references public.hymns (id) on delete restrict,
  payload jsonb not null,
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  primary key (release_id, hymn_id)
);

create index catalog_releases_edition_id_idx on public.catalog_releases (edition_id, id desc);
create index published_hymns_hymn_id_idx on public.published_hymns (hymn_id);

alter table public.catalog_releases enable row level security;
alter table public.published_hymns enable row level security;

-- Contenu public : lecture pour tous, aucune écriture directe (publish_release uniquement).
grant select on public.catalog_releases to anon, authenticated;
grant select on public.published_hymns to anon, authenticated;

create policy "catalog_releases : lecture publique"
  on public.catalog_releases for select
  to anon, authenticated
  using (true);

create policy "published_hymns : lecture publique"
  on public.published_hymns for select
  to anon, authenticated
  using (true);

-- L'auteur d'une publication est tracé dans le journal (non exposé au public).
create trigger audit after insert or update or delete on public.catalog_releases
  for each row execute function private.audit_row();

-- ---------------------------------------------------------------------------
-- Construction du contenu publié
-- ---------------------------------------------------------------------------

-- Répétition d'une ligne : « (bis) » → 2, « (ter) » → 3, « (4x) », « (4 x) »,
-- « (x4) » → 4. Seul un marqueur en FIN de ligne est reconnu ; toute autre
-- parenthèse (réponses chantées, « (2) ») reste du texte (anomalie A-10).
create function private.line_repeat(line text)
returns jsonb
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  m text[];
  v_count integer;
begin
  m := regexp_match(
    line,
    '(\((bis|ter|[0-9]+ ?[x×]|[x×] ?[0-9]+)\))[[:space:][:punct:]  ]*$',
    'i'
  );
  if m is null then
    return null;
  end if;
  v_count := case lower(m[2])
    when 'bis' then 2
    when 'ter' then 3
    else regexp_replace(m[2], '[^0-9]', '', 'g')::integer
  end;
  if v_count not between 2 and 12 then
    return null;
  end if;
  return jsonb_build_object('count', v_count, 'marker', m[1]);
end;
$$;

-- Lignes d'une section : texte verbatim (ADR-008) + répétition dérivée.
create function private.section_lines(value text)
returns jsonb
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('text', t.line, 'repeat', private.line_repeat(t.line))
      order by t.n
    ),
    '[]'::jsonb
  )
  from regexp_split_to_table(value, E'\n') with ordinality as t (line, n)
  where not private.is_blank(t.line)
$$;

create function private.hymn_payload(p_hymn_id uuid)
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
  from public.hymns h
  where h.id = p_hymn_id
$$;

create function private.sha256_hex(value text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select encode(sha256(convert_to(value, 'UTF8')), 'hex')
$$;

-- ---------------------------------------------------------------------------
-- Publication
-- ---------------------------------------------------------------------------

-- Crée une release de l'édition donnée. Renvoie son numéro, ou le numéro de
-- la release courante si rien n'a changé (idempotent).
create function public.publish_release(p_edition_id uuid, p_notes text default null)
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

  -- Une seule publication à la fois.
  perform pg_advisory_xact_lock(hashtextextended('lad.publish_release', 0));

  select r.id, r.content_hash into v_prev, v_prev_hash
    from public.catalog_releases r
   where r.edition_id = p_edition_id
   order by r.id desc
   limit 1;

  drop table if exists pg_temp.release_candidates;
  create temporary table release_candidates on commit drop as
  select c.hymn_id, c.payload, private.sha256_hex(c.payload::text) as payload_hash
    from (
      -- Cantiques validés : version courante.
      select h.id as hymn_id, private.hymn_payload(h.id) as payload
        from public.hymns h
       where h.edition_id = p_edition_id
         and h.status = 'published'
         and private.effective_rights_status(h.id) <> 'restricted'
      union all
      -- Cantiques en cours de correction : version publiée précédente (T-009).
      select ph.hymn_id, ph.payload
        from public.published_hymns ph
        join public.hymns h on h.id = ph.hymn_id
       where ph.release_id = v_prev
         and h.status in ('draft', 'review')
         and private.effective_rights_status(h.id) <> 'restricted'
    ) as c;

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

revoke all on function public.publish_release(uuid, text) from public, anon;
grant execute on function public.publish_release(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Distribution (RPC publiques, SECURITY INVOKER)
-- ---------------------------------------------------------------------------

-- Dernière release disponible (null si aucune).
create function public.get_catalog_manifest()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'releaseId', r.id,
    'editionId', r.edition_id,
    'publishedAt', r.published_at,
    'hymnCount', r.hymn_count,
    'contentHash', r.content_hash
  )
  from public.catalog_releases r
  order by r.id desc
  limit 1
$$;

-- Contenu complet d'une release (la dernière par défaut).
create function public.get_catalog_snapshot(p_release_id integer default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with target as (
    select r.*
      from public.catalog_releases r
     where r.id = coalesce(p_release_id, (select max(id) from public.catalog_releases))
  )
  select jsonb_build_object(
    'releaseId', t.id,
    'editionId', t.edition_id,
    'publishedAt', t.published_at,
    'contentHash', t.content_hash,
    'hymns', coalesce((
      select jsonb_agg(
        ph.payload
        order by (ph.payload ->> 'numberNumeric')::integer, ph.payload ->> 'numberLabel'
      )
      from public.published_hymns ph
      where ph.release_id = t.id
    ), '[]'::jsonb)
  )
  from target t
$$;

-- Changements entre une release connue du client et la dernière release.
-- Si la release du client est inconnue, demande un instantané complet.
create function public.get_catalog_delta(p_from_release integer)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with latest as (
    select max(id) as id from public.catalog_releases
  )
  select case
    when l.id is null then null
    when not exists (select 1 from public.catalog_releases r where r.id = p_from_release)
      or p_from_release > l.id
      then jsonb_build_object('fromRelease', p_from_release, 'toRelease', l.id,
                              'fullSnapshotRequired', true)
    else jsonb_build_object(
      'fromRelease', p_from_release,
      'toRelease', l.id,
      'fullSnapshotRequired', false,
      'upserts', coalesce((
        select jsonb_agg(n.payload order by (n.payload ->> 'numberNumeric')::integer)
          from public.published_hymns n
         where n.release_id = l.id
           and not exists (
             select 1 from public.published_hymns o
              where o.release_id = p_from_release
                and o.hymn_id = n.hymn_id
                and o.payload_hash = n.payload_hash
           )
      ), '[]'::jsonb),
      'removedIds', coalesce((
        select jsonb_agg(o.hymn_id order by o.hymn_id)
          from public.published_hymns o
         where o.release_id = p_from_release
           and not exists (
             select 1 from public.published_hymns n
              where n.release_id = l.id and n.hymn_id = o.hymn_id
           )
      ), '[]'::jsonb)
    )
  end
  from latest l
$$;

grant execute on function public.get_catalog_manifest() to anon, authenticated;
grant execute on function public.get_catalog_snapshot(integer) to anon, authenticated;
grant execute on function public.get_catalog_delta(integer) to anon, authenticated;
