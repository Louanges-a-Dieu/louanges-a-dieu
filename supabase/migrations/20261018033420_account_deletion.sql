-- Migration 0013 — Suppression de compte par l'utilisateur (tâche 6.2)
--
-- Exigée par l'App Store et Google Play. L'utilisateur ne peut supprimer que
-- SON compte (aucun paramètre) ; ses profil, favoris, listes et programmes
-- disparaissent en cascade (migrations 0005 et 0009). Les jetons d'accès déjà
-- émis restent valides jusqu'à leur expiration : l'application se déconnecte
-- immédiatement après l'appel, et aucune donnée ne subsiste à laquelle ils
-- donneraient accès.
--
-- SECURITY DEFINER : seul le propriétaire de la base peut supprimer une ligne
-- de auth.users. Fonction exposée volontairement (acceptée dans
-- docs/architecture/security.md).

create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Connexion requise' using errcode = 'insufficient_privilege';
  end if;
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
