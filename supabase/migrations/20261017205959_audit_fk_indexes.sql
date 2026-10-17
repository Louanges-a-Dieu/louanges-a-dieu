-- Migration 0012 — Index des clés étrangères vers auth.users
-- (signalés par `supabase db advisors` : supprimer un compte parcourrait ces
-- tables sans index).

create index hymns_validated_by_idx on public.hymns (validated_by);
create index import_batches_created_by_idx on public.import_batches (created_by);
create index import_issues_resolved_by_idx on public.import_issues (resolved_by);
create index user_roles_granted_by_idx on public.user_roles (granted_by);
