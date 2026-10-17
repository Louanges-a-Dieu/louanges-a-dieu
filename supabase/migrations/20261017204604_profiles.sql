-- Migration 0005 — Profils utilisateurs (C-14)
--
-- app_users (V1) devient profiles, lié à auth.users. L'e-mail n'est plus
-- dupliqué (minimisation des données personnelles) : il reste dans auth.users.
-- La suppression d'un compte supprime son profil et, en cascade, ses favoris,
-- listes et programmes.

alter table public.app_users rename to profiles;
alter table public.profiles drop column email;

alter table public.profiles
  add constraint profiles_id_fkey
    foreign key (id) references auth.users (id) on delete cascade,
  add constraint profiles_display_name_not_blank
    check (display_name is null or not private.is_blank(display_name));

alter table public.profiles add column updated_at timestamptz not null default now();

create trigger set_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- Création automatique du profil à l'inscription (nom d'affichage inconnu = NULL).
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Comptes déjà existants.
insert into public.profiles (id)
select u.id from auth.users u
on conflict (id) do nothing;

grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

create policy "profiles : lecture de son profil"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy "profiles : modification de son profil"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
