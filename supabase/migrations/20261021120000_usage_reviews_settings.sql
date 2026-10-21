-- Planche 8 (2026-10-21), choix du propriétaire : statistiques ANONYMES,
-- avis des fidèles (note et commentaire) modérés dans le back-office,
-- paramètres de l'app réglables par un super administrateur.

-- ------------------------------------------------------------- paramètres
-- Lisibles par tous (l'app en a besoin sans compte) ; modifiables par un
-- super administrateur seulement. Liste fermée de clés.
create table public.app_settings (
  key text primary key check (key in ('comments_enabled', 'stats_enabled')),
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);
alter table public.app_settings enable row level security;
insert into public.app_settings (key, value) values
  ('comments_enabled', 'true'::jsonb),
  ('stats_enabled', 'true'::jsonb);

grant select on public.app_settings to anon, authenticated;
grant update (value, updated_at, updated_by) on public.app_settings to authenticated;
create policy "app_settings : lecture publique" on public.app_settings
  for select to anon, authenticated using (true);
create policy "app_settings : modification par super_admin" on public.app_settings
  for update to authenticated
  using ((select private.has_role('super_admin')))
  with check ((select private.has_role('super_admin')) and updated_by = (select auth.uid()));
create trigger audit after insert or update or delete on public.app_settings
  for each row execute function private.audit_row();

create function private.setting_enabled(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select value = 'true'::jsonb from public.app_settings where key = p_key), false)
$$;
revoke all on function private.setting_enabled(text) from public;
grant execute on function private.setting_enabled(text) to anon, authenticated;

-- ---------------------------------------------------- statistiques anonymes
-- Compteurs agrégés par jour, cantique et type d'usage. Aucune donnée
-- d'identification : ni utilisateur, ni appareil, ni adresse.
create table public.usage_daily (
  day date not null,
  hymn_id uuid not null references public.hymns (id) on delete cascade,
  event text not null check (event in ('view', 'listen', 'project')),
  count integer not null check (count >= 0),
  primary key (day, hymn_id, event)
);
create index usage_daily_hymn_idx on public.usage_daily (hymn_id);
alter table public.usage_daily enable row level security;
grant select on public.usage_daily to authenticated;
create policy "usage_daily : lecture par les éditeurs" on public.usage_daily
  for select to authenticated using ((select private.has_role('editor')));

-- Envoi par l'app : [{ hymnId, event, count }], regroupé côté app. Bornes :
-- 200 éléments par envoi, 50 par élément. Sans effet si les statistiques
-- sont désactivées. Ouvert sans compte (anonyme).
create function public.record_usage(p_events jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.setting_enabled('stats_enabled') then
    return;
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' or jsonb_array_length(p_events) > 200 then
    raise exception 'Envoi de statistiques invalide' using errcode = '22023';
  end if;
  insert into public.usage_daily as u (day, hymn_id, event, count)
  select current_date, h.id, e.event, least(sum(e.count), 50)::integer
    from (
      -- Conversions protégées : une valeur mal formée est ignorée, sans erreur.
      select case when x ->> 'hymnId' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                  then (x ->> 'hymnId')::uuid end as hymn_id,
             x ->> 'event' as event,
             case when coalesce(x ->> 'count', '1') ~ '^[0-9]{1,6}$'
                  then least(greatest(coalesce((x ->> 'count')::integer, 1), 1), 50)
                  else 1 end as count
        from jsonb_array_elements(p_events) as x
       where jsonb_typeof(x) = 'object'
         and x ->> 'event' in ('view', 'listen', 'project')
    ) as e
    join public.hymns h on h.id = e.hymn_id
   group by h.id, e.event
  on conflict (day, hymn_id, event) do update set count = u.count + excluded.count;
end;
$$;
revoke all on function public.record_usage(jsonb) from public;
grant execute on function public.record_usage(jsonb) to anon, authenticated;

-- Tableau de bord et page Statistiques : totaux, courbe quotidienne,
-- cantiques les plus consultés, sur les p_days derniers jours.
create function public.usage_stats(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 366);
  v_from date := current_date - (v_days - 1);
begin
  if not private.has_role('editor') then
    raise exception 'Accès réservé à l''équipe éditoriale' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'days', v_days,
    'totals', (
      select jsonb_build_object(
        'view', coalesce(sum(count) filter (where event = 'view'), 0),
        'listen', coalesce(sum(count) filter (where event = 'listen'), 0),
        'project', coalesce(sum(count) filter (where event = 'project'), 0))
        from public.usage_daily where day >= v_from
    ),
    'daily', (
      select jsonb_agg(jsonb_build_object(
               'day', s.day, 'view', s.view, 'listen', s.listen, 'project', s.project)
             order by s.day)
        from (
          select d.day::date as day,
                 coalesce(sum(u.count) filter (where u.event = 'view'), 0) as view,
                 coalesce(sum(u.count) filter (where u.event = 'listen'), 0) as listen,
                 coalesce(sum(u.count) filter (where u.event = 'project'), 0) as project
            from generate_series(v_from, current_date, interval '1 day') as d(day)
            left join public.usage_daily u on u.day = d.day::date
           group by d.day
        ) as s
    ),
    'top', coalesce((
      select jsonb_agg(t order by t.views desc, t."numberNumeric")
        from (
          select h.id as "hymnId", h.number_label as "numberLabel",
                 h.number_numeric as "numberNumeric", h.title,
                 sum(u.count)::integer as views
            from public.usage_daily u
            join public.hymns h on h.id = u.hymn_id
           where u.day >= v_from and u.event = 'view'
           group by h.id
           order by views desc, h.number_numeric
           limit 10
        ) as t
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.usage_stats(integer) from public, anon;
grant execute on function public.usage_stats(integer) to authenticated;

-- ------------------------------------------------------------------- avis
-- Note de 1 à 5 et commentaire facultatif, un par fidèle et par cantique ;
-- visibles par tous seulement après approbation dans le back-office.
create table public.hymn_comments (
  id uuid primary key default gen_random_uuid(),
  hymn_id uuid not null references public.hymns (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text check (body is null or (not private.is_blank(body) and char_length(body) <= 1000)),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reply text check (reply is null or (not private.is_blank(reply) and char_length(reply) <= 1000)),
  moderated_at timestamptz,
  moderated_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (hymn_id, user_id)
);
create index hymn_comments_status_idx on public.hymn_comments (status, created_at desc);
create index hymn_comments_user_idx on public.hymn_comments (user_id);
create index hymn_comments_moderated_by_idx on public.hymn_comments (moderated_by);
alter table public.hymn_comments enable row level security;
create trigger set_updated_at before update on public.hymn_comments
  for each row execute function private.set_updated_at();
create trigger audit after insert or update or delete on public.hymn_comments
  for each row execute function private.audit_row();

-- L'équipe éditoriale lit tous les avis (modération) ; les fidèles passent
-- par les fonctions ci-dessous.
grant select on public.hymn_comments to authenticated;
create policy "hymn_comments : lecture par les éditeurs" on public.hymn_comments
  for select to authenticated using ((select private.has_role('editor')));

-- Dépôt ou modification de son avis : repasse en attente de modération.
create function public.submit_review(p_hymn_id uuid, p_rating integer, p_body text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_body text := nullif(btrim(p_body), '');
begin
  if not private.setting_enabled('comments_enabled') then
    raise exception 'Les avis sont désactivés' using errcode = '42501';
  end if;
  insert into public.hymn_comments (hymn_id, user_id, rating, body)
  values (p_hymn_id, v_user, p_rating, v_body)
  on conflict (hymn_id, user_id) do update
    set rating = excluded.rating,
        body = excluded.body,
        status = 'pending',
        reply = null,
        moderated_at = null,
        moderated_by = null;
end;
$$;
revoke all on function public.submit_review(uuid, integer, text) from public, anon;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

create function public.delete_my_review(p_hymn_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.hymn_comments
   where hymn_id = p_hymn_id and user_id = private.require_user();
end;
$$;
revoke all on function public.delete_my_review(uuid) from public, anon;
grant execute on function public.delete_my_review(uuid) to authenticated;

-- Avis d'un cantique : nombre et moyenne des avis approuvés, les 50 plus
-- récents (sans aucune donnée sur leur auteur), et le sien s'il y en a un.
create function public.hymn_reviews(p_hymn_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'enabled', private.setting_enabled('comments_enabled'),
    'count', (select count(*) from public.hymn_comments
               where hymn_id = p_hymn_id and status = 'approved'),
    'average', (select round(avg(rating), 1) from public.hymn_comments
                 where hymn_id = p_hymn_id and status = 'approved'),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rating', c.rating, 'body', c.body, 'reply', c.reply,
               'createdAt', c.created_at)
             order by c.created_at desc)
        from (select * from public.hymn_comments
               where hymn_id = p_hymn_id and status = 'approved'
               order by created_at desc limit 50) as c
    ), '[]'::jsonb),
    'mine', (
      select jsonb_build_object('rating', c.rating, 'body', c.body, 'status', c.status,
                                'reply', c.reply)
        from public.hymn_comments c
       where c.hymn_id = p_hymn_id and c.user_id = (select auth.uid())
    )
  )
$$;
revoke all on function public.hymn_reviews(uuid) from public;
grant execute on function public.hymn_reviews(uuid) to anon, authenticated;

-- Modération (équipe éditoriale) : approuver, refuser, répondre.
create function public.moderate_review(p_id uuid, p_status text, p_reply text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_role('editor') then
    raise exception 'Accès réservé à l''équipe éditoriale' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Statut inconnu' using errcode = '22023';
  end if;
  update public.hymn_comments
     set status = p_status,
         reply = nullif(btrim(p_reply), ''),
         moderated_at = now(),
         moderated_by = (select auth.uid())
   where id = p_id;
  if not found then
    raise exception 'Avis introuvable' using errcode = 'P0002';
  end if;
end;
$$;
revoke all on function public.moderate_review(uuid, text, text) from public, anon;
grant execute on function public.moderate_review(uuid, text, text) to authenticated;
