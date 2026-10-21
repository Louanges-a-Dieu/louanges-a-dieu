-- Tableau de bord du back-office (planche 8, écran 2) : nombres globaux,
-- sans aucune donnée personnelle. Équipe éditoriale seulement.
create function public.community_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_role('editor') then
    raise exception 'Accès réservé à l''équipe éditoriale' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'programs', (select count(*) from public.worship_services
                  where deleted_at is null and not is_template),
    'sharedPrograms', (select count(*) from public.worship_services
                        where deleted_at is null and share_token is not null
                          and share_revoked_at is null and status = 'published'),
    'pendingReviews', (select count(*) from public.hymn_comments where status = 'pending'),
    'approvedReviews', (select count(*) from public.hymn_comments where status = 'approved'),
    'hymnsWithAudio', (select count(distinct hymn_id) from public.audio_tracks)
  );
end;
$$;
revoke all on function public.community_overview() from public, anon;
grant execute on function public.community_overview() to authenticated;
