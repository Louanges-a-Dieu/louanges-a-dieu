-- Back-office (Phase 9) : MFA exigée par la base, import, aperçu et retour
-- arrière de release, recherche, équipe, journal.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'fidele@test.invalid'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editeur@test.invalid'),
  ('55555555-5555-4555-8555-555555555555', 'super@test.invalid');
insert into public.user_roles (user_id, role) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor'),
  ('55555555-5555-4555-8555-555555555555', 'super_admin');
delete from public.catalog_releases;
-- Seul super_admin de la transaction (la base de dev peut en avoir d'autres, ex. compte E2E).
delete from public.user_roles
 where role = 'super_admin' and user_id <> '55555555-5555-4555-8555-555555555555';

create function pg_temp.as_user(p_id text, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;
grant execute on function pg_temp.as_user(text, text) to authenticated;

-- --------------------------------------------------- MFA exigée par la base
set local role authenticated;
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal1');
select is(private.has_role('editor'), false, 'éditeur sans second facteur : aucun rôle');
select is_empty($$ select 1 from public.hymns $$, 'sans MFA, aucun brouillon lisible');
select throws_ok($$ select public.publish_release(gen_random_uuid()) $$, '42501', null,
                 'sans MFA, publication refusée');
select throws_ok($$ select public.import_catalog_draft('{"format":"lad.catalog-draft"}'::jsonb) $$,
                 '42501', null, 'sans MFA, import refusé');
select throws_ok($$ select * from public.set_hymns_status(array[gen_random_uuid()], 'review') $$,
                 '42501', null, 'sans MFA, validation refusée');
select is((select count(*)::integer from public.user_roles), 1,
          'sans MFA, l''éditeur peut tout de même voir son propre rôle (pour demander la MFA)');
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'aal2');
select is(private.has_role('editor'), true, 'avec second facteur : rôle éditeur reconnu');

-- ------------------------------------------------------------------ import
create temporary table draft as select $json$
{
  "format": "lad.catalog-draft", "version": 1,
  "source": {"filename": "test.docx", "sha256": "0000000000000000000000000000000000000000000000000000000000000001", "parserVersion": "test"},
  "edition": {"name": "Édition back-office (test)", "editionNumber": 99},
  "hymns": [
    {"numberLabel": "1", "numberNumeric": 1, "numberSuffix": null, "title": "Ô jour heureux", "openingLine": "Ô jour heureux",
     "sourceParagraphStart": 1, "sourceParagraphEnd": 3,
     "sections": [{"type": "verse", "order": 0, "text": "Ô jour heureux\nJour de bonheur"},
                  {"type": "refrain", "order": 1, "text": "Alléluia (bis)"}],
     "bibleReferences": [{"displayText": "Psaumes 100", "book": "Psaumes", "chapterStart": 100, "verseStart": null, "chapterEnd": null, "verseEnd": null}],
     "relations": []},
    {"numberLabel": "1bis", "numberNumeric": 1, "numberSuffix": "bis", "title": "Autre texte", "openingLine": null,
     "sourceParagraphStart": 4, "sourceParagraphEnd": 5,
     "sections": [{"type": "verse", "order": 0, "text": "Autre texte sur la même mélodie"}],
     "bibleReferences": [], "relations": [{"type": "bis_of", "relatedNumberLabel": "1"}]}
  ],
  "issues": [
    {"code": "A-10", "severity": "blocking", "numberLabel": "1bis", "message": "Parenthèse ambiguë", "details": {}},
    {"code": "A-01", "severity": "info", "numberLabel": null, "message": "Note du document", "details": {"page": 3}}
  ]
}
$json$::jsonb as doc;
grant select on draft to authenticated;

select is((select public.import_catalog_draft(doc, true) from draft) -> 'inserted',
          '["1", "1bis"]'::jsonb, 'simulation : deux cantiques seraient ajoutés');
select is_empty($$ select 1 from public.editions where edition_number = 99 $$,
                'la simulation n''écrit rien');

select set_config('test.summary', (select public.import_catalog_draft(doc) from draft)::text, true);
select is((current_setting('test.summary')::jsonb ->> 'issuesCreated')::integer, 2,
          'import : anomalies du document et des cantiques créées');
select is((select status::text from public.hymns where number_label = '1bis'
             and edition_id = (current_setting('test.summary')::jsonb ->> 'editionId')::uuid),
          'draft', 'les cantiques importés sont en brouillon');
select is((select count(*)::integer from public.hymn_relations r
             join public.hymns h on h.id = r.hymn_id where h.number_label = '1bis'),
          1, 'relation « bis » créée');
select is((select display_order from public.hymn_sections s join public.hymns h on h.id = s.hymn_id
            where h.number_label = '1' and s.section_type = 'refrain'),
          1, 'ordre des sections conservé');

select is((select public.import_catalog_draft(doc) from draft) ->> 'batchId', null,
          'réimport identique : aucun nouveau lot (idempotent)');

-- Réimport avec un texte modifié et un cantique disparu : A-20 / A-21, rien d'écrasé.
update draft set doc = jsonb_set(doc, '{hymns,0,title}', '"Ô jour heureux (corrigé)"');
update draft set doc = jsonb_set(doc, '{hymns}', (doc -> 'hymns') - 1);
select is((select public.import_catalog_draft(doc, true) from draft) -> 'changed', '["1"]'::jsonb,
          'diff de réimport : texte modifié détecté');
select is((select public.import_catalog_draft(doc, true) from draft) -> 'missingFromSource', '["1bis"]'::jsonb,
          'diff de réimport : cantique absent de la source détecté');
select lives_ok($$ select public.import_catalog_draft(doc) from draft $$, 'réimport');
select is((select title from public.hymns where number_label = '1'
             and edition_id = (current_setting('test.summary')::jsonb ->> 'editionId')::uuid),
          'Ô jour heureux', 'le texte en base n''est jamais écrasé');
select set_eq($$ select code from public.import_issues
                  where code in ('A-20', 'A-21') and status = 'open' $$,
              array['A-20', 'A-21'], 'A-20 et A-21 ouvertes pour arbitrage');

-- ---------------------------------------------------------------- recherche
-- (limitée à l'édition de test : la base de développement contient le vrai recueil)
create function pg_temp.found(p_query text, p_status public.publication_status default null,
                              p_issues text default null)
returns setof text language sql as $$
  select number_label from public.search_hymns_admin(p_query, p_status, p_issues, null, 50, 0,
    (current_setting('test.summary')::jsonb ->> 'editionId')::uuid)
$$;
grant execute on function pg_temp.found(text, public.publication_status, text) to authenticated;
select results_eq($$ select pg_temp.found('JOUR HEUREUX') $$, array['1'],
                  'recherche sans accents ni casse dans le titre');
select results_eq($$ select pg_temp.found('bonheur') $$, array['1'], 'recherche dans le texte des sections');
select results_eq($$ select pg_temp.found('1bis') $$, array['1bis'], 'recherche par numéro');
select results_eq($$ select pg_temp.found(null, null, 'blocking') $$, array['1bis'],
                  'filtre « anomalie bloquante »');
select is_empty($$ select pg_temp.found(null, 'published') $$, 'filtre par statut');
select ok((select count(*) from public.search_hymns_admin('jour')) >=
          (select count(*) from pg_temp.found('jour')), 'sans édition : toutes les éditions');

-- -------------------------------------------- publication, aperçu, retour arrière
select set_config('test.edition', current_setting('test.summary')::jsonb ->> 'editionId', true);
select is((select bool_and(ok) from public.set_hymns_status(
            array(select id from public.hymns where number_label = '1'
                    and edition_id = current_setting('test.edition')::uuid), 'review')), true, 'en relecture');
select is((select bool_and(ok) from public.set_hymns_status(
            array(select id from public.hymns where number_label = '1'
                    and edition_id = current_setting('test.edition')::uuid), 'published')), true, 'validé');
select results_eq(
  $$ select number_label, change from public.preview_release(current_setting('test.edition')::uuid) $$,
  $$ values ('1', 'added') $$,
  'aperçu avant la première publication');
select set_config('test.r1', public.publish_release(current_setting('test.edition')::uuid, 'R1')::text, true);
select is_empty($$ select * from public.preview_release(current_setting('test.edition')::uuid) $$,
                'rien à publier juste après');

update public.hymns set title = 'Ô jour heureux !'
 where number_label = '1' and edition_id = current_setting('test.edition')::uuid;
select is_empty($$ select * from public.preview_release(current_setting('test.edition')::uuid) $$,
                'modification non validée : la version publiée reste (T-009)');
select is((select bool_and(ok) from public.set_hymns_status(
            array(select id from public.hymns where number_label = '1'
                    and edition_id = current_setting('test.edition')::uuid), 'review')), true, 'relecture');
select is((select bool_and(ok) from public.set_hymns_status(
            array(select id from public.hymns where number_label = '1'
                    and edition_id = current_setting('test.edition')::uuid), 'published')), true, 'revalidé');
select results_eq(
  $$ select number_label, title, change from public.preview_release(current_setting('test.edition')::uuid) $$,
  $$ values ('1', 'Ô jour heureux !', 'changed') $$,
  'aperçu : modification annoncée');
select set_config('test.r2', public.publish_release(current_setting('test.edition')::uuid, 'R2')::text, true);

select set_config('test.r3', public.rollback_release(current_setting('test.edition')::uuid,
                                                     current_setting('test.r1')::integer)::text, true);
select ok(current_setting('test.r3')::integer > current_setting('test.r2')::integer,
          'retour arrière : nouvelle release');
select is((select payload ->> 'title' from public.published_hymns
            where release_id = current_setting('test.r3')::integer),
          'Ô jour heureux', 'contenu de la release 1 republié');
select is((select notes from public.catalog_releases where id = current_setting('test.r3')::integer),
          'Retour au contenu de la release ' || current_setting('test.r1'), 'note automatique');
select is((public.get_catalog_delta(current_setting('test.r2')::integer) -> 'upserts' -> 0 ->> 'title'),
          'Ô jour heureux', 'les applications reçoivent le retour arrière comme une mise à jour');
select is(public.rollback_release(current_setting('test.edition')::uuid, current_setting('test.r1')::integer),
          current_setting('test.r3')::integer, 'retour vers un contenu identique : rien de nouveau');

-- ------------------------------------------------- aperçu et anomalies
select is((public.preview_hymn((select id from public.hymns where number_label = '1'
             and edition_id = current_setting('test.edition')::uuid)) -> 'sections' -> 1 -> 'lines' -> 0 -> 'repeat' ->> 'count'),
          '2', 'aperçu : contenu publié calculé (répétition « (bis) »)');
select is(public.preview_hymn(gen_random_uuid()), null, 'aperçu d''un cantique inconnu');
select throws_ok(
  $$ select public.resolve_issues(array(select id from public.import_issues where code = 'A-21'), 'ignored', '  ') $$,
  '23514', null, 'ignorer sans justification : refusé');
select is(public.resolve_issues(array(select id from public.import_issues where code = 'A-21'),
                                'ignored', 'Retiré volontairement de la v8'), 1, 'anomalie ignorée avec justification');
select is((select resolved_by from public.import_issues where code = 'A-21'),
          'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid, 'auteur de la décision fixé par le serveur');
select is(public.resolve_issues(array(select id from public.import_issues where code = 'A-21'), 'open'), 1,
          'anomalie rouverte');
select is((select resolved_at from public.import_issues where code = 'A-21'), null, 'réouverture : décision effacée');

-- -------------------------------------------------------------- équipe
select throws_ok($$ select public.admin_grant_role('fidele@test.invalid', 'editor') $$, '42501', null,
                 'un éditeur ne peut pas attribuer de rôle');
select is_empty($$ select * from public.admin_list_team() $$, 'un éditeur ne voit pas l''équipe');

select pg_temp.as_user('55555555-5555-4555-8555-555555555555', 'aal2');
select is(public.admin_grant_role('FIDELE@test.invalid', 'editor'),
          '11111111-1111-4111-8111-111111111111'::uuid, 'attribution par e-mail (casse ignorée)');
select is((select roles from public.admin_list_team() where email = 'fidele@test.invalid'),
          array['editor']::public.app_role[], 'l''équipe liste le nouveau membre');
select throws_ok($$ select public.admin_grant_role('inconnu@test.invalid', 'editor') $$, 'P0002', null,
                 'adresse inconnue');
select throws_ok($$ select public.admin_revoke_role('55555555-5555-4555-8555-555555555555', 'super_admin') $$,
                 '23514', null, 'le dernier super_admin ne peut pas être retiré');
select lives_ok($$ select public.admin_revoke_role('11111111-1111-4111-8111-111111111111', 'editor') $$,
                'retrait d''un rôle');

-- -------------------------------------------------------------- journal
select ok((select count(*) from public.admin_audit_log()) > 0, 'journal consultable');
select ok(exists (select 1 from public.admin_audit_log() where actor_email = 'super@test.invalid'
                    and table_name = 'user_roles'), 'auteur identifié par son adresse');
select pg_temp.as_user('11111111-1111-4111-8111-111111111111', 'aal2');
select is_empty($$ select * from public.admin_audit_log() $$, 'un fidèle ne lit pas le journal');
select is(public.editorial_stats(), null, 'ni les statistiques');
reset role;

set local role anon;
select throws_ok($$ select * from public.admin_audit_log() $$, '42501', null, 'anon : refusé');
select throws_ok($$ select public.rollback_release(gen_random_uuid(), 1) $$, '42501', null,
                 'anon : retour arrière refusé');
select throws_ok($$ select public.preview_hymn(gen_random_uuid()) $$, '42501', null, 'anon : aperçu refusé');
reset role;

select * from finish();
rollback;
