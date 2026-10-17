-- Migration 0009 — Données utilisateur et synchronisation (ADR-006, C-05)
--
-- Favoris, listes et programmes de culte appartiennent à leur auteur (RLS).
-- Synchronisation local-first :
--   - chaque écriture reçoit une révision attribuée par le SERVEUR
--     (séquence, insensible aux horloges des appareils) ;
--   - les suppressions sont des « pierres tombales » (deleted_at) afin d'être
--     propagées aux autres appareils ;
--   - un verrou consultatif par utilisateur sérialise ses écritures et ses
--     lectures de synchronisation : un client ne peut pas manquer une révision
--     validée après sa lecture ;
--   - conflits : la dernière écriture reçue par le serveur l'emporte ; les
--     éléments d'une liste ou d'un programme sont remplacés en bloc.

create sequence private.user_data_revision as bigint;

-- ---------------------------------------------------------------------------
-- Colonnes de synchronisation
-- ---------------------------------------------------------------------------

alter table public.favorites
  add column updated_at timestamptz not null default now(),
  add column deleted_at timestamptz,
  add column server_revision bigint not null default 0;

alter table public.playlists
  add column updated_at timestamptz not null default now(),
  add column deleted_at timestamptz,
  add column server_revision bigint not null default 0,
  add constraint playlists_name_not_blank check (not private.is_blank(name)),
  add constraint playlists_description_not_blank
    check (description is null or not private.is_blank(description));

-- Un programme appartient toujours à un compte ; il disparaît avec lui.
alter table public.worship_services drop constraint worship_services_owner_user_id_fkey;
alter table public.worship_services alter column owner_user_id set not null;
alter table public.worship_services
  add constraint worship_services_owner_user_id_fkey
    foreign key (owner_user_id) references public.profiles (id) on delete cascade,
  add column updated_at timestamptz not null default now(),
  add column deleted_at timestamptz,
  add column server_revision bigint not null default 0,
  add constraint worship_services_title_not_blank check (not private.is_blank(title));

alter table public.worship_service_items
  add constraint worship_service_items_hymn_or_label
    check (hymn_id is not null or not private.is_blank(label)),
  add constraint worship_service_items_label_not_blank
    check (label is null or not private.is_blank(label)),
  add constraint worship_service_items_notes_not_blank
    check (section_notes is null or not private.is_blank(section_notes));

create index favorites_user_revision_idx on public.favorites (user_id, server_revision);
create index playlists_user_revision_idx on public.playlists (user_id, server_revision);
create index worship_services_owner_revision_idx
  on public.worship_services (owner_user_id, server_revision);

-- ---------------------------------------------------------------------------
-- Révisions
-- ---------------------------------------------------------------------------

create function private.sync_lock_key(p_user_id uuid)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select hashtextextended('lad.sync:' || p_user_id::text, 0)
$$;

create function private.bump_user_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_user uuid := coalesce(v_row ->> 'user_id', v_row ->> 'owner_user_id')::uuid;
begin
  if tg_op = 'UPDATE' then
    if coalesce(to_jsonb(old) ->> 'user_id', to_jsonb(old) ->> 'owner_user_id')::uuid
       is distinct from v_user then
      raise exception 'Le propriétaire ne peut pas être modifié'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  perform pg_advisory_xact_lock(private.sync_lock_key(v_user));
  new.server_revision := nextval('private.user_data_revision');
  new.updated_at := now();
  return new;
end;
$$;

create trigger bump_revision before insert or update on public.favorites
  for each row execute function private.bump_user_revision();
create trigger bump_revision before insert or update on public.playlists
  for each row execute function private.bump_user_revision();
create trigger bump_revision before insert or update on public.worship_services
  for each row execute function private.bump_user_revision();

-- Modifier un élément fait avancer la révision de sa liste / de son programme.
create function private.touch_parent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'playlist_items' then
    update public.playlists set updated_at = now()
     where id = coalesce(new.playlist_id, old.playlist_id);
  else
    update public.worship_services set updated_at = now()
     where id = coalesce(new.worship_service_id, old.worship_service_id);
  end if;
  return null;
end;
$$;

create trigger touch_parent after insert or update or delete on public.playlist_items
  for each row execute function private.touch_parent();
create trigger touch_parent after insert or update or delete on public.worship_service_items
  for each row execute function private.touch_parent();

-- ---------------------------------------------------------------------------
-- Accès : chacun ne voit et ne modifie que ses propres données
-- (suppression = pierre tombale ; aucune suppression physique par l'API).
-- ---------------------------------------------------------------------------

grant select, insert, update on public.favorites to authenticated;
grant select, insert, update on public.playlists to authenticated;
grant select, insert, update, delete on public.playlist_items to authenticated;
grant select, insert, update on public.worship_services to authenticated;
grant select, insert, update, delete on public.worship_service_items to authenticated;
grant select, insert, delete on public.downloads to authenticated;

create policy "favorites : lecture des siens" on public.favorites
  for select to authenticated using (user_id = (select auth.uid()));
create policy "favorites : création des siens" on public.favorites
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "favorites : modification des siens" on public.favorites
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "playlists : lecture des siennes" on public.playlists
  for select to authenticated using (user_id = (select auth.uid()));
create policy "playlists : création des siennes" on public.playlists
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "playlists : modification des siennes" on public.playlists
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "playlist_items : éléments de ses listes" on public.playlist_items
  for all to authenticated
  using (exists (
    select 1 from public.playlists p
     where p.id = playlist_id and p.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.playlists p
     where p.id = playlist_id and p.user_id = (select auth.uid())
  ));

create policy "worship_services : lecture des siens" on public.worship_services
  for select to authenticated using (owner_user_id = (select auth.uid()));
create policy "worship_services : création des siens" on public.worship_services
  for insert to authenticated with check (owner_user_id = (select auth.uid()));
create policy "worship_services : modification des siens" on public.worship_services
  for update to authenticated
  using (owner_user_id = (select auth.uid())) with check (owner_user_id = (select auth.uid()));

create policy "worship_service_items : éléments de ses programmes" on public.worship_service_items
  for all to authenticated
  using (exists (
    select 1 from public.worship_services w
     where w.id = worship_service_id and w.owner_user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.worship_services w
     where w.id = worship_service_id and w.owner_user_id = (select auth.uid())
  ));

create policy "downloads : les siens" on public.downloads
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- RPC de synchronisation (SECURITY INVOKER : la RLS s'applique)
-- ---------------------------------------------------------------------------

create function private.require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Connexion requise' using errcode = 'insufficient_privilege';
  end if;
  return v_user;
end;
$$;

grant execute on function private.require_user() to authenticated;
grant execute on function private.sync_lock_key(uuid) to authenticated;

-- Favoris : [{ "hymnId": uuid, "deleted": bool }]
create function public.sync_push_favorites(p_changes jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
begin
  insert into public.favorites (user_id, hymn_id, deleted_at)
  select v_user,
         (c ->> 'hymnId')::uuid,
         case when coalesce((c ->> 'deleted')::boolean, false) then now() end
    from jsonb_array_elements(p_changes) as c
  on conflict (user_id, hymn_id) do update set deleted_at = excluded.deleted_at;
end;
$$;

-- Liste : { id, name, description, deleted, items: [{ hymnId, order }] }
create function public.sync_push_playlist(p_playlist jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_id uuid := (p_playlist ->> 'id')::uuid;
begin
  insert into public.playlists (id, user_id, name, description, deleted_at)
  values (
    v_id, v_user, p_playlist ->> 'name', p_playlist ->> 'description',
    case when coalesce((p_playlist ->> 'deleted')::boolean, false) then now() end
  )
  on conflict (id) do update
    set name = excluded.name,
        description = excluded.description,
        deleted_at = excluded.deleted_at;

  delete from public.playlist_items where playlist_id = v_id;
  insert into public.playlist_items (playlist_id, hymn_id, display_order)
  select v_id, (i ->> 'hymnId')::uuid, (i ->> 'order')::integer
    from jsonb_array_elements(coalesce(p_playlist -> 'items', '[]'::jsonb)) as i;
end;
$$;

-- Programme : { id, title, serviceDate, status, deleted,
--               items: [{ id, hymnId, label, notes, order }] }
create function public.sync_push_worship_service(p_service jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_id uuid := (p_service ->> 'id')::uuid;
begin
  insert into public.worship_services (id, owner_user_id, title, service_date, status, deleted_at)
  values (
    v_id, v_user, p_service ->> 'title', (p_service ->> 'serviceDate')::date,
    coalesce(p_service ->> 'status', 'draft')::public.service_status,
    case when coalesce((p_service ->> 'deleted')::boolean, false) then now() end
  )
  on conflict (id) do update
    set title = excluded.title,
        service_date = excluded.service_date,
        status = excluded.status,
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
create function public.sync_pull(p_since bigint default 0)
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

grant execute on function public.sync_push_favorites(jsonb) to authenticated;
grant execute on function public.sync_push_playlist(jsonb) to authenticated;
grant execute on function public.sync_push_worship_service(jsonb) to authenticated;
grant execute on function public.sync_pull(bigint) to authenticated;
