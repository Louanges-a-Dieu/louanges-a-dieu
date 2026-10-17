-- Migration 0004 — Rôles applicatifs (ADR-010, §14 du plan)
--
-- « editor »      : importer, corriger, valider, publier le contenu.
-- « super_admin » : tout ce que fait un éditeur + archivage, rôles, configuration.
-- Les rôles ne sont JAMAIS lus depuis user_metadata (modifiable par l'utilisateur).
--
-- Amorçage : le premier super_admin est attribué par le propriétaire en SQL
-- (voir docs/api/rpc.md), aucun compte n'est privilégié par défaut.

create type public.app_role as enum ('editor', 'super_admin');

create table public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

alter table public.user_roles enable row level security;

-- Vrai si l'utilisateur courant détient le rôle demandé (super_admin les
-- détient tous). SECURITY DEFINER pour lire user_roles sans récursion RLS ;
-- placée dans le schéma non exposé « private », exécutable par authenticated
-- uniquement.
create function private.has_role(required public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and (ur.role = required or ur.role = 'super_admin')
  )
$$;

revoke all on function private.has_role(public.app_role) from public, anon;
grant execute on function private.has_role(public.app_role) to authenticated;

-- Un utilisateur voit ses propres rôles ; un super_admin voit et gère tous les rôles.
grant select, insert, delete on public.user_roles to authenticated;

create policy "user_roles : lecture de ses rôles ou super_admin"
  on public.user_roles for select
  to authenticated
  using (user_id = (select auth.uid()) or (select private.has_role('super_admin')));

create policy "user_roles : attribution par super_admin"
  on public.user_roles for insert
  to authenticated
  with check ((select private.has_role('super_admin')) and granted_by = (select auth.uid()));

create policy "user_roles : retrait par super_admin"
  on public.user_roles for delete
  to authenticated
  using ((select private.has_role('super_admin')));
