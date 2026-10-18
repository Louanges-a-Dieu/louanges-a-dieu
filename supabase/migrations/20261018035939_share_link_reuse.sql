-- Migration 0014 — Réutilisation du lien de partage (tâche 7.4)
--
-- Partager deux fois le même programme doit donner le MÊME lien : en créer un
-- nouveau à chaque fois invaliderait celui déjà envoyé aux fidèles.
-- ensure_share_link renvoie le lien actif s'il existe (non révoqué, non
-- expiré), sinon en crée un. create_share_link reste disponible pour
-- « régénérer » volontairement le lien (l'ancien cesse alors de fonctionner).

create function public.ensure_share_link(p_service_id uuid)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_token text;
begin
  perform private.require_user();
  select w.share_token into v_token
    from public.worship_services w
   where w.id = p_service_id
     and w.owner_user_id = (select auth.uid())
     and w.deleted_at is null
     and w.share_token is not null
     and w.share_revoked_at is null
     and (w.share_expires_at is null or w.share_expires_at > now());
  if v_token is not null then
    return v_token;
  end if;
  return public.create_share_link(p_service_id);
end;
$$;

revoke all on function public.ensure_share_link(uuid) from public, anon;
grant execute on function public.ensure_share_link(uuid) to authenticated;
