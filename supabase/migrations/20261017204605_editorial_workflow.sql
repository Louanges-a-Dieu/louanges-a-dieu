-- Migration 0006 — Workflow éditorial (C-04, C-08, C-09, F-ADM-001/002, T-009)
--
-- Statuts de la copie de travail d'un cantique :
--   draft     : en cours de saisie ou de correction
--   review    : soumis à relecture
--   published : VALIDÉ, inclus dans la prochaine release de catalogue
--   archived  : retiré du recueil (réservé au super_admin)
-- Le public ne lit jamais ces tables : il lit les releases (migration suivante).
-- Toute modification de contenu d'un cantique validé le repasse en « draft » ;
-- sa dernière version publiée reste servie au public jusqu'à la prochaine
-- validation (T-009).

-- ---------------------------------------------------------------------------
-- Journal des modifications (C-08)
-- ---------------------------------------------------------------------------

create table public.audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid default auth.uid(),
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('insert', 'update', 'delete')),
  changes jsonb not null
);

alter table public.audit_log enable row level security;

create index audit_log_record_idx on public.audit_log (table_name, record_id);
create index audit_log_occurred_at_idx on public.audit_log (occurred_at desc);

create function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_row jsonb := coalesce(v_new, v_old);
  v_changes jsonb;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(n.key, jsonb_build_object('old', v_old -> n.key, 'new', n.value))
      into v_changes
      from jsonb_each(v_new) as n
     where n.key not in ('updated_at', 'search_vector')
       and n.value is distinct from v_old -> n.key;
    if v_changes is null then
      return new;
    end if;
  else
    v_changes := (v_row - 'search_vector');
  end if;

  insert into public.audit_log (table_name, record_id, action, changes)
  values (
    tg_table_name,
    coalesce(v_row ->> 'id', v_row ->> 'hymn_id', v_row ->> 'user_id'),
    lower(tg_op),
    v_changes
  );
  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- Import et anomalies (C-09)
-- ---------------------------------------------------------------------------

create type public.issue_severity as enum ('info', 'warning', 'blocking');
create type public.issue_status as enum ('open', 'resolved', 'ignored');

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  edition_id uuid not null references public.editions (id) on delete restrict,
  source_filename text not null check (not private.is_blank(source_filename)),
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  parser_version text not null check (not private.is_blank(parser_version)),
  stats jsonb not null default '{}'::jsonb,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.import_issues (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches (id) on delete cascade,
  hymn_id uuid references public.hymns (id) on delete cascade,
  code text not null check (code ~ '^[A-Z]-[0-9]{2}$'),
  severity public.issue_severity not null,
  message text not null check (not private.is_blank(message)),
  details jsonb not null default '{}'::jsonb,
  status public.issue_status not null default 'open',
  resolution_note text,
  resolved_by uuid references auth.users (id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint import_issues_resolution_consistent
    check ((status = 'open') = (resolved_at is null)),
  constraint import_issues_ignore_justified
    check (status <> 'ignored' or not private.is_blank(resolution_note))
);

alter table public.import_batches enable row level security;
alter table public.import_issues enable row level security;

create index import_batches_edition_id_idx on public.import_batches (edition_id);
create index import_issues_batch_id_idx on public.import_issues (batch_id);
create index import_issues_open_by_hymn_idx on public.import_issues (hymn_id)
  where status = 'open';

alter table public.hymns
  add column import_batch_id uuid references public.import_batches (id) on delete set null,
  add column validated_by uuid references auth.users (id) on delete set null,
  add column validated_at timestamptz;

create index hymns_import_batch_id_idx on public.hymns (import_batch_id);

-- ---------------------------------------------------------------------------
-- Statut de droits effectif (cahier §13, Q-02)
-- ---------------------------------------------------------------------------

-- Dernier enregistrement de droits valide pour le texte du cantique
-- (media_id NULL) ; « unknown » en l'absence d'enregistrement.
create function private.effective_rights_status(p_hymn_id uuid)
returns public.rights_status
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select rr.rights_status
      from public.rights_records rr
      where rr.hymn_id = p_hymn_id
        and rr.media_id is null
        and (rr.valid_until is null or rr.valid_until >= current_date)
      order by rr.created_at desc, rr.id
      limit 1
    ),
    'unknown'::public.rights_status
  )
$$;

revoke all on function private.effective_rights_status(uuid) from public, anon;
grant execute on function private.effective_rights_status(uuid) to authenticated;

-- Vue du back-office (security_invoker : respecte la RLS de l'appelant).
create view public.hymn_rights
with (security_invoker = true)
as
select h.id as hymn_id, private.effective_rights_status(h.id) as rights_status
from public.hymns h;

-- ---------------------------------------------------------------------------
-- Transitions de statut et retour automatique en brouillon
-- ---------------------------------------------------------------------------

create function private.guard_hymn_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_content_changed boolean :=
    (new.edition_id, new.number_label, new.number_numeric, new.number_suffix,
     new.title, new.opening_line, new.language_code)
    is distinct from
    (old.edition_id, old.number_label, old.number_numeric, old.number_suffix,
     old.title, old.opening_line, old.language_code);
begin
  -- Modification de contenu d'un cantique validé : retour en brouillon.
  if new.status = old.status then
    if old.status = 'published' and v_content_changed then
      new.status := 'draft';
      new.validated_by := null;
      new.validated_at := null;
    end if;
    return new;
  end if;

  if not (
    (old.status, new.status) in (
      ('draft', 'review'),
      ('review', 'draft'),
      ('review', 'published'),
      ('published', 'draft'),
      ('published', 'archived'),
      ('draft', 'archived'),
      ('review', 'archived'),
      ('archived', 'draft')
    )
  ) then
    raise exception 'Transition de statut interdite : % → %', old.status, new.status
      using errcode = 'check_violation';
  end if;

  if (new.status = 'archived' or old.status = 'archived')
     and not private.has_role('super_admin') then
    raise exception 'Archivage réservé au super_admin'
      using errcode = 'insufficient_privilege';
  end if;

  if new.status = 'published' then
    if not exists (select 1 from public.hymn_sections s where s.hymn_id = new.id) then
      raise exception 'Le cantique % n''a aucune section', new.number_label
        using errcode = 'check_violation';
    end if;
    if exists (
      select 1 from public.import_issues i
      where i.hymn_id = new.id and i.status = 'open' and i.severity = 'blocking'
    ) then
      raise exception 'Le cantique % a une anomalie bloquante ouverte', new.number_label
        using errcode = 'check_violation';
    end if;
    if private.effective_rights_status(new.id) = 'restricted' then
      raise exception 'Le cantique % a des droits restreints', new.number_label
        using errcode = 'check_violation';
    end if;
    new.validated_by := auth.uid();
    new.validated_at := now();
  elsif old.status = 'published' then
    new.validated_by := null;
    new.validated_at := null;
  end if;

  return new;
end;
$$;

create trigger guard_status before update on public.hymns
  for each row execute function private.guard_hymn_status();

-- Un nouveau cantique entre toujours en brouillon.
create function private.force_draft_on_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.status := 'draft';
  new.validated_by := null;
  new.validated_at := null;
  return new;
end;
$$;

create trigger force_draft before insert on public.hymns
  for each row execute function private.force_draft_on_insert();

-- Toute modification d'un élément rattaché (sections, références, relations,
-- personnes, thèmes) repasse le cantique validé en brouillon.
create function private.mark_hymn_dirty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.hymns
     set status = 'draft'
   where id = coalesce(new.hymn_id, old.hymn_id)
     and status = 'published';
  return coalesce(new, old);
end;
$$;

create trigger mark_hymn_dirty after insert or update or delete on public.hymn_sections
  for each row execute function private.mark_hymn_dirty();
create trigger mark_hymn_dirty after insert or update or delete on public.bible_references
  for each row execute function private.mark_hymn_dirty();
create trigger mark_hymn_dirty after insert or update or delete on public.hymn_relations
  for each row execute function private.mark_hymn_dirty();
create trigger mark_hymn_dirty after insert or update or delete on public.hymn_people
  for each row execute function private.mark_hymn_dirty();
create trigger mark_hymn_dirty after insert or update or delete on public.hymn_themes
  for each row execute function private.mark_hymn_dirty();

-- Validation par lots (Q-03) : applique un statut à plusieurs cantiques et
-- renvoie, pour chacun, le succès ou le motif de refus (les autres continuent).
create function public.set_hymns_status(p_hymn_ids uuid[], p_status public.publication_status)
returns table (hymn_id uuid, ok boolean, error text)
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  foreach v_id in array p_hymn_ids loop
    begin
      update public.hymns h set status = p_status where h.id = v_id;
      if found then
        hymn_id := v_id; ok := true; error := null;
      else
        hymn_id := v_id; ok := false; error := 'Cantique introuvable';
      end if;
    exception
      when check_violation or insufficient_privilege then
        hymn_id := v_id; ok := false; error := sqlerrm;
    end;
    return next;
  end loop;
end;
$$;

revoke all on function public.set_hymns_status(uuid[], public.publication_status) from public, anon;
grant execute on function public.set_hymns_status(uuid[], public.publication_status) to authenticated;

-- ---------------------------------------------------------------------------
-- Journalisation des tables éditoriales
-- ---------------------------------------------------------------------------

create trigger audit after insert or update or delete on public.editions
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.hymns
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.hymn_sections
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.bible_references
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.hymn_relations
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.people
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.hymn_people
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.themes
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.hymn_themes
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.rights_records
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.import_issues
  for each row execute function private.audit_row();
create trigger audit after insert or update or delete on public.user_roles
  for each row execute function private.audit_row();
