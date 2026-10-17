-- Migration 0003 — Corrections structurelles du schéma V1
-- (C-11, C-12, C-13 et règle « aucune donnée inventée » du plan)
--
-- Note C-02 : les marqueurs de répétition (bis), (ter), (4x)… restent dans le
-- texte verbatim des sections. L'annotation structurée par ligne est DÉRIVÉE
-- à la publication (migration catalog_releases) : aucune colonne à maintenir.

-- ---------------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------------

create extension if not exists unaccent with schema extensions;

-- Les fonctions de « private » ne sont exécutables que sur autorisation explicite.
alter default privileges in schema private revoke execute on functions from public;

-- unaccent() n'est pas IMMUTABLE ; cette enveloppe l'est (dictionnaire fixé),
-- ce qui permet de l'utiliser dans des colonnes générées et des index.
create function private.f_unaccent(value text)
returns text
language sql
immutable
parallel safe
strict
set search_path = ''
as $$
  select extensions.unaccent('extensions.unaccent'::regdictionary, value)
$$;

-- Chaîne non vide après suppression des espaces, y compris insécables.
create function private.is_blank(value text)
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
  select value is null or btrim(value, E' \t\n\r  ') = ''
$$;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- C-12 : un cantique appartient toujours à une édition
-- ---------------------------------------------------------------------------

alter table public.hymns drop constraint hymns_edition_id_fkey;
alter table public.hymns alter column edition_id set not null;
alter table public.hymns
  add constraint hymns_edition_id_fkey
  foreign key (edition_id) references public.editions (id) on delete restrict;

-- ---------------------------------------------------------------------------
-- Contraintes de cohérence (aucune valeur vide à la place d'un NULL)
-- ---------------------------------------------------------------------------

alter table public.editions
  add constraint editions_name_not_blank check (not private.is_blank(name)),
  add constraint editions_edition_number_positive check (edition_number > 0);

alter table public.hymns
  add constraint hymns_number_numeric_positive check (number_numeric > 0),
  add constraint hymns_number_suffix_valid check (number_suffix in ('bis', 'ter')),
  add constraint hymns_number_label_consistent
    check (number_label = number_numeric::text || coalesce(number_suffix, '')),
  add constraint hymns_title_not_blank check (not private.is_blank(title)),
  add constraint hymns_opening_line_not_blank
    check (opening_line is null or not private.is_blank(opening_line)),
  add constraint hymns_language_code_valid check (language_code ~ '^[a-z]{2,3}$');

alter table public.hymn_sections
  add constraint hymn_sections_text_not_blank check (not private.is_blank(text)),
  add constraint hymn_sections_display_order_valid check (display_order >= 0),
  add constraint hymn_sections_section_number_positive check (section_number > 0),
  add constraint hymn_sections_repeat_consistent check (
    (repeat_type = 'custom' and repeat_count between 2 and 12)
    or (repeat_type <> 'custom' and repeat_count is null)
  ),
  add constraint hymn_sections_hymn_order_key
    unique (hymn_id, display_order) deferrable initially deferred;

-- Index V1 désormais couvert par la contrainte d'unicité ci-dessus.
drop index public.hymn_sections_hymn_order_idx;

alter table public.people
  add constraint people_full_name_not_blank check (not private.is_blank(full_name));

alter table public.bible_references
  add constraint bible_references_chapters_positive
    check (chapter_start > 0 and (chapter_end is null or chapter_end >= chapter_start)),
  add constraint bible_references_verses_positive
    check ((verse_start is null or verse_start > 0) and (verse_end is null or verse_end > 0)),
  add constraint bible_references_book_not_blank check (not private.is_blank(book)),
  add constraint bible_references_display_text_not_blank
    check (display_text is null or not private.is_blank(display_text));

alter table public.hymn_relations
  add constraint hymn_relations_not_self check (hymn_id <> related_hymn_id);

alter table public.themes
  add constraint themes_name_not_blank check (not private.is_blank(name)),
  add constraint themes_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

alter table public.hymn_themes
  add constraint hymn_themes_confidence_range check (confidence between 0 and 1);

alter table public.audio_segments
  add constraint audio_segments_time_range check (start_ms >= 0 and end_ms > start_ms);

alter table public.rights_records
  add constraint rights_records_validity_range
    check (valid_until is null or valid_from is null or valid_until >= valid_from);

-- ---------------------------------------------------------------------------
-- C-11 : réordonnancement en une transaction (contraintes différables)
-- ---------------------------------------------------------------------------

alter table public.playlist_items
  drop constraint playlist_items_playlist_id_display_order_key,
  add constraint playlist_items_playlist_id_display_order_key
    unique (playlist_id, display_order) deferrable initially deferred,
  add constraint playlist_items_display_order_valid check (display_order >= 0);

alter table public.worship_service_items
  drop constraint worship_service_items_worship_service_id_display_order_key,
  add constraint worship_service_items_worship_service_id_display_order_key
    unique (worship_service_id, display_order) deferrable initially deferred,
  add constraint worship_service_items_display_order_valid check (display_order >= 0);

-- ---------------------------------------------------------------------------
-- Horodatage des modifications éditoriales
-- ---------------------------------------------------------------------------

alter table public.hymn_sections add column updated_at timestamptz not null default now();
alter table public.bible_references add column updated_at timestamptz not null default now();
alter table public.people add column updated_at timestamptz not null default now();
alter table public.rights_records add column updated_at timestamptz not null default now();

create trigger set_updated_at before update on public.hymns
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.hymn_sections
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.bible_references
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.people
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.rights_records
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- C-13 : recherche plein texte insensible aux accents (back-office)
-- ---------------------------------------------------------------------------

drop index public.hymns_title_idx;
drop index public.hymns_opening_idx;
drop index public.hymn_search_idx;
drop index public.hymn_section_search_idx;

alter table public.hymns
  add column search_vector tsvector generated always as (
    to_tsvector(
      'french'::regconfig,
      private.f_unaccent(coalesce(title, '') || ' ' || coalesce(opening_line, ''))
    )
  ) stored;
create index hymns_search_vector_idx on public.hymns using gin (search_vector);

alter table public.hymn_sections
  add column search_vector tsvector generated always as (
    to_tsvector('french'::regconfig, private.f_unaccent(text))
  ) stored;
create index hymn_sections_search_vector_idx on public.hymn_sections using gin (search_vector);

-- ---------------------------------------------------------------------------
-- Index des clés étrangères (jointures et suppressions en cascade)
-- ---------------------------------------------------------------------------

create index hymn_people_person_id_idx on public.hymn_people (person_id);
create index hymn_relations_related_hymn_id_idx on public.hymn_relations (related_hymn_id);
create index hymn_themes_theme_id_idx on public.hymn_themes (theme_id);
create index bible_references_hymn_id_idx on public.bible_references (hymn_id);
create index audio_tracks_hymn_id_idx on public.audio_tracks (hymn_id);
create index audio_segments_section_id_idx on public.audio_segments (section_id);
create index partitions_hymn_id_idx on public.partitions (hymn_id);
create index rights_records_hymn_id_idx on public.rights_records (hymn_id);
create index favorites_hymn_id_idx on public.favorites (hymn_id);
create index playlists_user_id_idx on public.playlists (user_id);
create index playlist_items_hymn_id_idx on public.playlist_items (hymn_id);
create index worship_services_owner_user_id_idx on public.worship_services (owner_user_id);
create index worship_service_items_hymn_id_idx on public.worship_service_items (hymn_id);
create index downloads_hymn_id_idx on public.downloads (hymn_id);

-- ---------------------------------------------------------------------------
-- Droits : les contraintes et colonnes générées s'évaluent avec les droits de
-- l'utilisateur qui écrit ; seules ces fonctions pures lui sont ouvertes.
-- ---------------------------------------------------------------------------

grant usage on schema private to authenticated;
grant execute on function private.is_blank(text) to authenticated;
grant execute on function private.f_unaccent(text) to authenticated;
