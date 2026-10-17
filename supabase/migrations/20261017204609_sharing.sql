-- Migration 0010 — Partage d'un programme de culte (ADR-012, F-WOR-002, Q-09, C-07)
--
-- Un lien public porte un jeton opaque de 192 bits (base64url), révocable,
-- éventuellement expirant, régénérable. Le lien n'ouvre qu'une vue en lecture
-- seule : titre, date, éléments (numéro et titre des cantiques, tels que publiés
-- dans la dernière release ; Q-09 : pas les paroles). Aucune donnée du compte
-- du créateur n'est exposée. Lien inconnu, révoqué, expiré ou programme non
-- publié : réponse identique (null), pour ne rien révéler.

alter table public.worship_services rename column public_token to share_token;
alter table public.worship_services rename constraint worship_services_public_token_key
  to worship_services_share_token_key;

alter table public.worship_services
  add column share_created_at timestamptz,
  add column share_expires_at timestamptz,
  add column share_revoked_at timestamptz,
  add constraint worship_services_share_token_format
    check (share_token is null or share_token ~ '^[A-Za-z0-9_-]{32,}$');

-- Jeton aléatoire de 24 octets (192 bits), encodé en base64url (32 caractères).
create function private.new_share_token()
returns text
language sql
volatile
set search_path = ''
as $$
  select translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/', '-_')
$$;

grant execute on function private.new_share_token() to authenticated;

-- Crée (ou remplace) le lien de partage d'un programme de l'utilisateur.
create function public.create_share_link(p_service_id uuid, p_expires_at timestamptz default null)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_token text;
begin
  perform private.require_user();
  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'La date d''expiration doit être dans le futur' using errcode = 'check_violation';
  end if;

  update public.worship_services
     set share_token = private.new_share_token(),
         share_created_at = now(),
         share_expires_at = p_expires_at,
         share_revoked_at = null
   where id = p_service_id
     and owner_user_id = (select auth.uid())
     and deleted_at is null
  returning share_token into v_token;

  if v_token is null then
    raise exception 'Programme introuvable' using errcode = 'no_data_found';
  end if;
  return v_token;
end;
$$;

-- Révoque immédiatement le lien de partage.
create function public.revoke_share_link(p_service_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform private.require_user();
  update public.worship_services
     set share_revoked_at = now()
   where id = p_service_id
     and owner_user_id = (select auth.uid())
     and share_token is not null;
  if not found then
    raise exception 'Programme introuvable' using errcode = 'no_data_found';
  end if;
end;
$$;

grant execute on function public.create_share_link(uuid, timestamptz) to authenticated;
grant execute on function public.revoke_share_link(uuid) to authenticated;

-- Vue publique d'un programme partagé. SECURITY DEFINER car anon n'a aucun
-- accès aux tables de programmes : la fonction est le SEUL point d'entrée et
-- ne renvoie que des champs explicitement choisis.
create function public.get_shared_program(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with service as (
    select w.id, w.title, w.service_date
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

revoke all on function public.get_shared_program(text) from public;
grant execute on function public.get_shared_program(text) to anon, authenticated;
