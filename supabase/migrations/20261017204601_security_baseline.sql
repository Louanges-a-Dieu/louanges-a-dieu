-- Migration 0002 — Base de sécurité (C-06, §14 du plan)
--
-- Principe : refus par défaut. Aucune table n'est accessible par l'API tant
-- qu'une migration ne lui accorde pas explicitement des droits ET des
-- politiques RLS. Les migrations suivantes ouvrent l'accès table par table.

-- Schéma interne, non exposé par l'API (fonctions utilitaires, séquences).
create schema if not exists private;
revoke all on schema private from public;

-- Aucun privilège implicite sur les objets créés ensuite dans public.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- Retrait des privilèges éventuellement accordés aux tables du schéma V1.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- RLS activée sur toutes les tables du schéma V1 (sans politique = aucun accès).
alter table public.editions enable row level security;
alter table public.hymns enable row level security;
alter table public.hymn_sections enable row level security;
alter table public.people enable row level security;
alter table public.hymn_people enable row level security;
alter table public.bible_references enable row level security;
alter table public.hymn_relations enable row level security;
alter table public.themes enable row level security;
alter table public.hymn_themes enable row level security;
alter table public.audio_tracks enable row level security;
alter table public.audio_segments enable row level security;
alter table public.partitions enable row level security;
alter table public.rights_records enable row level security;
alter table public.app_users enable row level security;
alter table public.favorites enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_items enable row level security;
alter table public.worship_services enable row level security;
alter table public.worship_service_items enable row level security;
alter table public.downloads enable row level security;
