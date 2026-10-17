-- Migration 0007 — Accès aux tables éditoriales (§14 du plan)
--
-- Seuls les rôles « editor » et « super_admin » lisent et modifient la copie de
-- travail. « anon » n'a AUCUN accès : le public lit uniquement les releases.
-- Suppression des cantiques et des éditions réservée au super_admin
-- (l'archivage est la voie normale).

do $$
declare
  t text;
  editorial_tables text[] := array[
    'editions', 'hymns', 'hymn_sections', 'people', 'hymn_people',
    'bible_references', 'hymn_relations', 'themes', 'hymn_themes',
    'audio_tracks', 'audio_segments', 'partitions', 'rights_records',
    'import_batches', 'import_issues'
  ];
  super_admin_delete text[] := array['editions', 'hymns'];
begin
  foreach t in array editorial_tables loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);

    execute format(
      'create policy %I on public.%I for select to authenticated
         using ((select private.has_role(''editor'')))',
      t || ' : lecture éditeur', t);

    execute format(
      'create policy %I on public.%I for insert to authenticated
         with check ((select private.has_role(''editor'')))',
      t || ' : création éditeur', t);

    execute format(
      'create policy %I on public.%I for update to authenticated
         using ((select private.has_role(''editor'')))
         with check ((select private.has_role(''editor'')))',
      t || ' : modification éditeur', t);

    execute format(
      'create policy %I on public.%I for delete to authenticated
         using ((select private.has_role(%L)))',
      t || ' : suppression',
      t,
      case when t = any (super_admin_delete) then 'super_admin' else 'editor' end);
  end loop;
end;
$$;

-- Journal : lecture seule pour les éditeurs (écrit uniquement par trigger).
grant select on public.audit_log to authenticated;

create policy "audit_log : lecture éditeur"
  on public.audit_log for select
  to authenticated
  using ((select private.has_role('editor')));

-- Vue des droits effectifs (security_invoker : RLS de hymns appliquée).
grant select on public.hymn_rights to authenticated;
