-- Planche 4 (2026-10-21) : icône et couleur des listes ; lieu, description,
-- image, modèle et options de projection des programmes de culte.
-- Synchronisation : les fonctions sync_* transportent les nouveaux champs ;
-- un client qui ne les envoie pas (ancienne version) ne les efface pas.

alter table public.playlists
  add column icon text,
  add column color text,
  add constraint playlists_icon_valid check (
    icon is null
    or icon in ('heart', 'prayer', 'church', 'book', 'music', 'star', 'celebration', 'cross')
  ),
  add constraint playlists_color_valid check (
    color is null or color in ('gold', 'red', 'ochre', 'green', 'teal', 'blue', 'violet')
  );

alter table public.worship_services
  add column location text,
  add column description text,
  add column cover text,
  add column is_template boolean not null default false,
  add column options jsonb not null default '{}'::jsonb,
  add constraint worship_services_location_valid check (
    location is null or (not private.is_blank(location) and char_length(location) <= 200)
  ),
  add constraint worship_services_description_valid check (
    description is null or (not private.is_blank(description) and char_length(description) <= 2000)
  ),
  -- Photo embarquée dans l'app (assets/images/<cover>.jpg), jamais une URL.
  add constraint worship_services_cover_valid check (cover is null or cover ~ '^[a-z][a-z0-9_]{0,60}$'),
  add constraint worship_services_options_valid check (
    jsonb_typeof(options) = 'object' and pg_column_size(options) <= 4096
  );

-- Liste : { id, name, description, icon, color, deleted, items: [{ hymnId, order }] }
create or replace function public.sync_push_playlist(p_playlist jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_id uuid := (p_playlist ->> 'id')::uuid;
begin
  insert into public.playlists (id, user_id, name, description, icon, color, deleted_at)
  values (
    v_id, v_user, p_playlist ->> 'name', p_playlist ->> 'description',
    p_playlist ->> 'icon', p_playlist ->> 'color',
    case when coalesce((p_playlist ->> 'deleted')::boolean, false) then now() end
  )
  on conflict (id) do update
    set name = excluded.name,
        description = excluded.description,
        icon = case when p_playlist ? 'icon' then excluded.icon else public.playlists.icon end,
        color = case when p_playlist ? 'color' then excluded.color else public.playlists.color end,
        deleted_at = excluded.deleted_at;

  delete from public.playlist_items where playlist_id = v_id;
  insert into public.playlist_items (playlist_id, hymn_id, display_order)
  select v_id, (i ->> 'hymnId')::uuid, (i ->> 'order')::integer
    from jsonb_array_elements(coalesce(p_playlist -> 'items', '[]'::jsonb)) as i;
end;
$$;

-- Programme : { id, title, serviceDate, status, location, description, cover,
--               isTemplate, options, deleted,
--               items: [{ id, hymnId, label, notes, order }] }
create or replace function public.sync_push_worship_service(p_service jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_id uuid := (p_service ->> 'id')::uuid;
begin
  insert into public.worship_services (
    id, owner_user_id, title, service_date, status,
    location, description, cover, is_template, options, deleted_at
  )
  values (
    v_id, v_user, p_service ->> 'title', (p_service ->> 'serviceDate')::date,
    coalesce(p_service ->> 'status', 'draft')::public.service_status,
    p_service ->> 'location', p_service ->> 'description', p_service ->> 'cover',
    coalesce((p_service ->> 'isTemplate')::boolean, false),
    coalesce(p_service -> 'options', '{}'::jsonb),
    case when coalesce((p_service ->> 'deleted')::boolean, false) then now() end
  )
  on conflict (id) do update
    set title = excluded.title,
        service_date = excluded.service_date,
        status = excluded.status,
        location = case when p_service ? 'location'
                        then excluded.location else public.worship_services.location end,
        description = case when p_service ? 'description'
                           then excluded.description else public.worship_services.description end,
        cover = case when p_service ? 'cover'
                     then excluded.cover else public.worship_services.cover end,
        is_template = case when p_service ? 'isTemplate'
                           then excluded.is_template else public.worship_services.is_template end,
        options = case when p_service ? 'options'
                       then excluded.options else public.worship_services.options end,
        deleted_at = excluded.deleted_at;

  delete from public.worship_service_items where worship_service_id = v_id;
  insert into public.worship_service_items
    (id, worship_service_id, hymn_id, label, section_notes, display_order)
  select coalesce((i ->> 'id')::uuid, gen_random_uuid()), v_id, (i ->> 'hymnId')::uuid,
         i ->> 'label', i ->> 'notes', (i ->> 'order')::integer
    from jsonb_array_elements(coalesce(p_service -> 'items', '[]'::jsonb)) as i;
end;
$$;

-- Tout ce qui a changé pour l'utilisateur depuis la révision p_since
-- (pierres tombales comprises).
create or replace function public.sync_pull(p_since bigint default 0)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_result jsonb;
begin
  -- Attend la fin des écritures en cours de cet utilisateur.
  perform pg_advisory_xact_lock_shared(private.sync_lock_key(v_user));

  select jsonb_build_object(
    'revision', greatest(
      p_since,
      coalesce((select max(server_revision) from public.favorites where user_id = v_user), 0),
      coalesce((select max(server_revision) from public.playlists where user_id = v_user), 0),
      coalesce((select max(server_revision) from public.worship_services where owner_user_id = v_user), 0)
    ),
    'favorites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'hymnId', f.hymn_id, 'deleted', f.deleted_at is not null,
               'revision', f.server_revision)
             order by f.server_revision)
        from public.favorites f
       where f.user_id = v_user and f.server_revision > p_since
    ), '[]'::jsonb),
    'playlists', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.name, 'description', p.description,
               'icon', p.icon, 'color', p.color,
               'deleted', p.deleted_at is not null, 'revision', p.server_revision,
               'items', coalesce((
                 select jsonb_agg(jsonb_build_object('hymnId', i.hymn_id, 'order', i.display_order)
                                  order by i.display_order)
                   from public.playlist_items i where i.playlist_id = p.id
               ), '[]'::jsonb))
             order by p.server_revision)
        from public.playlists p
       where p.user_id = v_user and p.server_revision > p_since
    ), '[]'::jsonb),
    'worshipServices', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', w.id, 'title', w.title, 'serviceDate', w.service_date, 'status', w.status,
               'location', w.location, 'description', w.description, 'cover', w.cover,
               'isTemplate', w.is_template, 'options', w.options,
               'deleted', w.deleted_at is not null, 'revision', w.server_revision,
               'items', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', i.id, 'hymnId', i.hymn_id, 'label', i.label,
                          'notes', i.section_notes, 'order', i.display_order)
                        order by i.display_order)
                   from public.worship_service_items i where i.worship_service_id = w.id
               ), '[]'::jsonb))
             order by w.server_revision)
        from public.worship_services w
       where w.owner_user_id = v_user and w.server_revision > p_since
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

-- Page publique d'un programme partagé : lieu et description en plus.
create or replace function public.get_shared_program(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with service as (
    select w.id, w.title, w.service_date, w.location, w.description
      from public.worship_services w
     where p_token ~ '^[A-Za-z0-9_-]{32,}$'
       and w.share_token = p_token
       and w.share_revoked_at is null
       and (w.share_expires_at is null or w.share_expires_at > now())
       and w.status = 'published'
       and w.deleted_at is null
  ),
  latest as (
    select max(id) as id from public.catalog_releases
  )
  select jsonb_build_object(
    'title', s.title,
    'serviceDate', s.service_date,
    'location', s.location,
    'description', s.description,
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'position', i.display_order,
          'label', i.label,
          'notes', i.section_notes,
          'hymn', case
            when i.hymn_id is null then null
            when ph.payload is null then jsonb_build_object('unavailable', true)
            else jsonb_build_object(
              'id', i.hymn_id,
              'numberLabel', ph.payload ->> 'numberLabel',
              'title', ph.payload ->> 'title'
            )
          end
        )
        order by i.display_order
      )
      from public.worship_service_items i
      left join public.published_hymns ph
        on ph.hymn_id = i.hymn_id and ph.release_id = (select id from latest)
      where i.worship_service_id = s.id
    ), '[]'::jsonb)
  )
  from service s
$$;
