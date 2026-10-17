-- Migration 0001 — Schéma PostgreSQL V1 tel que fourni par le propriétaire
-- (louanges_a_dieu_schema_v1.sql, 27/09/2026), repris SANS modification pour la
-- traçabilité (tâche 2.1). Les corrections font l’objet des migrations suivantes.

-- LOUANGES À DIEU
-- Schéma PostgreSQL V1
-- Ce script crée la structure de données; il ne préjuge pas des droits
-- de diffusion des paroles, partitions ou enregistrements.

create extension if not exists pgcrypto;

create type publication_status as enum ('draft','review','published','archived');
create type section_type as enum ('verse','refrain','bridge','intro','outro','note');
create type repeat_type as enum ('none','bis','ter','custom');
create type relation_type as enum ('same_melody','variant','bis_of','related');
create type media_type as enum ('melody','accompaniment','choir','soprano','alto','tenor','bass','instrumental','other');
create type rights_status as enum ('unknown','pending','cleared','restricted','public_domain');
create type service_status as enum ('draft','published','archived');

create table editions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    edition_number integer,
    description text,
    source_filename text,
    created_at timestamptz not null default now()
);

create table hymns (
    id uuid primary key default gen_random_uuid(),
    edition_id uuid references editions(id) on delete set null,
    number_label text not null,
    number_numeric integer not null,
    number_suffix text,
    title text not null,
    opening_line text,
    language_code text not null default 'fr',
    status publication_status not null default 'draft',
    source_paragraph_start integer,
    source_paragraph_end integer,
    editorial_notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (edition_id, number_label)
);

create index hymns_number_idx on hymns(number_numeric);
create index hymns_title_idx on hymns using gin(to_tsvector('french', coalesce(title,'')));
create index hymns_opening_idx on hymns using gin(to_tsvector('french', coalesce(opening_line,'')));

create table hymn_sections (
    id uuid primary key default gen_random_uuid(),
    hymn_id uuid not null references hymns(id) on delete cascade,
    section_type section_type not null,
    section_number integer,
    text text not null,
    display_order integer not null,
    repeat_type repeat_type not null default 'none',
    repeat_count integer,
    source_style text,
    editorial_status publication_status not null default 'draft'
);

create index hymn_sections_hymn_order_idx
    on hymn_sections(hymn_id, display_order);

create table people (
    id uuid primary key default gen_random_uuid(),
    full_name text not null,
    biography text,
    created_at timestamptz not null default now()
);

create table hymn_people (
    hymn_id uuid not null references hymns(id) on delete cascade,
    person_id uuid not null references people(id) on delete cascade,
    role text not null check (role in ('author','composer','translator','arranger')),
    primary key (hymn_id, person_id, role)
);

create table bible_references (
    id uuid primary key default gen_random_uuid(),
    hymn_id uuid not null references hymns(id) on delete cascade,
    book text not null,
    chapter_start integer not null,
    verse_start integer,
    chapter_end integer,
    verse_end integer,
    display_text text,
    source_status publication_status not null default 'draft'
);

create table hymn_relations (
    hymn_id uuid not null references hymns(id) on delete cascade,
    related_hymn_id uuid not null references hymns(id) on delete cascade,
    relation relation_type not null,
    notes text,
    primary key (hymn_id, related_hymn_id, relation)
);

create table themes (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    slug text not null unique
);

create table hymn_themes (
    hymn_id uuid not null references hymns(id) on delete cascade,
    theme_id uuid not null references themes(id) on delete cascade,
    source text not null default 'editorial',
    confidence numeric(4,3),
    primary key (hymn_id, theme_id)
);

create table audio_tracks (
    id uuid primary key default gen_random_uuid(),
    hymn_id uuid not null references hymns(id) on delete cascade,
    media_type media_type not null,
    storage_key text not null,
    duration_seconds numeric(10,2),
    bitrate_kbps integer,
    sample_rate integer,
    channels integer,
    musical_key text,
    tempo_bpm numeric(6,2),
    rights_status rights_status not null default 'unknown',
    created_at timestamptz not null default now()
);

create table audio_segments (
    id uuid primary key default gen_random_uuid(),
    audio_track_id uuid not null references audio_tracks(id) on delete cascade,
    section_id uuid references hymn_sections(id) on delete set null,
    start_ms bigint not null,
    end_ms bigint not null,
    display_order integer not null,
    unique(audio_track_id, display_order)
);

create table partitions (
    id uuid primary key default gen_random_uuid(),
    hymn_id uuid not null references hymns(id) on delete cascade,
    storage_key text not null,
    format text,
    musical_key text,
    rights_status rights_status not null default 'unknown',
    created_at timestamptz not null default now()
);

create table rights_records (
    id uuid primary key default gen_random_uuid(),
    hymn_id uuid references hymns(id) on delete cascade,
    media_id uuid,
    rights_status rights_status not null default 'unknown',
    rights_holder text,
    license_type text,
    territory text,
    valid_from date,
    valid_until date,
    evidence_storage_key text,
    notes text,
    created_at timestamptz not null default now()
);

create table app_users (
    id uuid primary key,
    display_name text,
    email text,
    created_at timestamptz not null default now()
);

create table favorites (
    user_id uuid not null references app_users(id) on delete cascade,
    hymn_id uuid not null references hymns(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key(user_id, hymn_id)
);

create table playlists (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references app_users(id) on delete cascade,
    name text not null,
    description text,
    is_shared boolean not null default false,
    created_at timestamptz not null default now()
);

create table playlist_items (
    playlist_id uuid not null references playlists(id) on delete cascade,
    hymn_id uuid not null references hymns(id) on delete cascade,
    display_order integer not null,
    primary key(playlist_id, hymn_id),
    unique(playlist_id, display_order)
);

create table worship_services (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid references app_users(id) on delete set null,
    title text not null,
    service_date date,
    status service_status not null default 'draft',
    public_token text unique,
    created_at timestamptz not null default now()
);

create table worship_service_items (
    id uuid primary key default gen_random_uuid(),
    worship_service_id uuid not null references worship_services(id) on delete cascade,
    hymn_id uuid references hymns(id) on delete set null,
    label text,
    display_order integer not null,
    section_notes text,
    unique(worship_service_id, display_order)
);

create table downloads (
    user_id uuid not null references app_users(id) on delete cascade,
    hymn_id uuid not null references hymns(id) on delete cascade,
    downloaded_at timestamptz not null default now(),
    primary key(user_id, hymn_id)
);

-- Recherche plein texte combinant titre, première ligne et paroles.
create index hymn_search_idx on hymns using gin (
    to_tsvector(
        'french',
        coalesce(title,'') || ' ' || coalesce(opening_line,'')
    )
);

create index hymn_section_search_idx on hymn_sections using gin (
    to_tsvector('french', coalesce(text,''))
);
