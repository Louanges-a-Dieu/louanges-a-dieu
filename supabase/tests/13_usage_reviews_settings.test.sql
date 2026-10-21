-- Planche 8 : statistiques anonymes, avis modérés, paramètres de l'app.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('41111111-1111-4111-8111-111111111111', 'fidele@test.invalid'),
  ('42222222-2222-4222-8222-222222222222', 'editeur@test.invalid'),
  ('43333333-3333-4333-8333-333333333333', 'admin@test.invalid');
insert into public.user_roles (user_id, role) values
  ('42222222-2222-4222-8222-222222222222', 'editor'),
  ('43333333-3333-4333-8333-333333333333', 'super_admin');
insert into public.editions (id, name) values ('ed000000-0000-4000-8000-000000000013', 'Test 13');
insert into public.hymns (id, edition_id, number_label, number_numeric, title) values
  ('d1300000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000013', '1', 1, 'Un'),
  ('d1300000-0000-4000-8000-000000000002', 'ed000000-0000-4000-8000-000000000013', '2', 2, 'Deux');

-- --------------------------------------------------------------- anonyme
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select lives_ok(
  $$ select public.record_usage('[
       {"hymnId":"d1300000-0000-4000-8000-000000000001","event":"view"},
       {"hymnId":"d1300000-0000-4000-8000-000000000001","event":"view","count":2},
       {"hymnId":"d1300000-0000-4000-8000-000000000002","event":"listen"},
       {"hymnId":"pas-un-uuid","event":"view"},
       {"hymnId":"d1300000-0000-4000-8000-000000000002","event":"autre"},
       {"hymnId":"d1300000-0000-4000-8000-000000000001","event":"project","count":"x"}
     ]') $$,
  'un visiteur sans compte envoie des compteurs ; les éléments mal formés sont ignorés'
);
select lives_ok(
  $$ select public.record_usage('[{"hymnId":"d1300000-0000-4000-8000-000000000001","event":"view","count":999}]') $$,
  'un compteur exagéré est borné'
);
select throws_ok(
  $$ select public.record_usage('{"pas":"une liste"}') $$,
  '22023', null, 'un envoi qui n’est pas une liste est refusé'
);
select throws_ok(
  $$ select * from public.usage_daily $$,
  '42501', null, 'un visiteur ne lit pas les statistiques'
);
select throws_ok(
  $$ select public.usage_stats(30) $$,
  '42501', null, 'un visiteur n’a pas accès au tableau des statistiques'
);
select throws_ok(
  $$ select public.community_overview() $$,
  '42501', null, 'un visiteur n’a pas accès à la vue d’ensemble'
);
select is(
  (select value from public.app_settings where key = 'comments_enabled'),
  'true'::jsonb, 'les paramètres sont lisibles sans compte'
);
select is(
  (public.hymn_reviews('d1300000-0000-4000-8000-000000000001') ->> 'count')::integer,
  0, 'aucun avis approuvé au départ'
);

reset role;
select is(
  (select jsonb_object_agg(event, count) from public.usage_daily
    where hymn_id = 'd1300000-0000-4000-8000-000000000001'),
  '{"view": 53, "project": 1}'::jsonb,
  'compteurs agrégés par jour : 1 + 2 + 50 (borné) consultations, 1 projection'
);
select ok(
  not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'usage_daily'
       and column_name not in ('day', 'hymn_id', 'event', 'count')
  ),
  'les statistiques ne contiennent aucune donnée d’identification'
);

-- ----------------------------------------------------------------- fidèle
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"41111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal1"}', true);

select lives_ok(
  $$ select public.submit_review('d1300000-0000-4000-8000-000000000001', 5, '  Très beau cantique.  ') $$,
  'un fidèle connecté laisse un avis'
);
select is(
  public.hymn_reviews('d1300000-0000-4000-8000-000000000001') -> 'mine',
  '{"rating": 5, "body": "Très beau cantique.", "status": "pending", "reply": null}'::jsonb,
  'il voit son avis, en attente de modération'
);
select is(
  (public.hymn_reviews('d1300000-0000-4000-8000-000000000001') ->> 'count')::integer,
  0, 'un avis en attente n’est pas public'
);
select throws_ok(
  $$ select public.submit_review('d1300000-0000-4000-8000-000000000001', 6) $$,
  '23514', null, 'une note hors de 1 à 5 est refusée'
);
select throws_ok(
  $$ select public.moderate_review('00000000-0000-4000-8000-000000000000', 'approved') $$,
  '42501', null, 'un fidèle ne peut pas modérer'
);
select is(
  (select count(*)::integer from public.hymn_comments), 0,
  'un fidèle ne lit pas directement la table des avis'
);

-- ---------------------------------------------------------------- éditeur
select set_config('request.jwt.claims', '{"sub":"42222222-2222-4222-8222-222222222222","role":"authenticated","aal":"aal2"}', true);
select is((select count(*)::integer from public.hymn_comments), 1, 'l’éditeur voit l’avis à modérer');
select lives_ok(
  $$ select public.moderate_review(id, 'approved', 'Merci !') from public.hymn_comments $$,
  'l’éditeur approuve et répond'
);
select is(
  (public.usage_stats(7) -> 'totals'),
  '{"view": 53, "listen": 1, "project": 1}'::jsonb,
  'l’éditeur lit les totaux'
);
select is(jsonb_array_length(public.usage_stats(7) -> 'daily'), 7, 'une ligne par jour de la période');
select is(public.usage_stats(7) -> 'top' -> 0 ->> 'title', 'Un', 'cantique le plus consulté');
select is(
  (public.community_overview() ->> 'pendingReviews')::integer, 0,
  'vue d’ensemble : plus d’avis en attente après approbation'
);
select ok(
  (public.community_overview() ->> 'users')::integer >= 3,
  'vue d’ensemble : nombre de comptes'
);
update public.app_settings set value = 'false' where key = 'comments_enabled';
select is(
  (select value from public.app_settings where key = 'comments_enabled'),
  'true'::jsonb, 'un éditeur ne modifie pas les paramètres'
);

-- --------------------------------------------------------- public, puis réglage
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(
  public.hymn_reviews('d1300000-0000-4000-8000-000000000001') - 'enabled' - 'mine'
    - 'reviews',
  '{"count": 1, "average": 5.0}'::jsonb,
  'l’avis approuvé est public : nombre et moyenne'
);
select is(
  (public.hymn_reviews('d1300000-0000-4000-8000-000000000001') -> 'reviews' -> 0) - 'createdAt',
  '{"rating": 5, "body": "Très beau cantique.", "reply": "Merci !"}'::jsonb,
  'aucune donnée sur l’auteur de l’avis'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"43333333-3333-4333-8333-333333333333","role":"authenticated","aal":"aal2"}', true);
select lives_ok(
  $$ update public.app_settings
        set value = 'false', updated_at = now(), updated_by = '43333333-3333-4333-8333-333333333333'
      where key in ('comments_enabled', 'stats_enabled') $$,
  'le super administrateur désactive avis et statistiques'
);
select set_config('request.jwt.claims', '{"sub":"41111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal1"}', true);
select throws_ok(
  $$ select public.submit_review('d1300000-0000-4000-8000-000000000002', 4) $$,
  '42501', null, 'avis désactivés : dépôt refusé'
);
select lives_ok(
  $$ select public.record_usage('[{"hymnId":"d1300000-0000-4000-8000-000000000002","event":"view"}]') $$,
  'statistiques désactivées : envoi accepté mais ignoré'
);
select lives_ok(
  $$ select public.delete_my_review('d1300000-0000-4000-8000-000000000001') $$,
  'un fidèle retire son avis'
);
reset role;
select is(
  (select count(*)::integer from public.usage_daily where event = 'view'
     and hymn_id = 'd1300000-0000-4000-8000-000000000002'), 0,
  'rien n’est compté quand les statistiques sont désactivées'
);
select is((select count(*)::integer from public.hymn_comments), 0, 'l’avis est retiré');

select * from finish();
rollback;
