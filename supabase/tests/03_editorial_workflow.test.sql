-- Workflow éditorial : accès, contraintes, transitions, retour en brouillon,
-- anomalies bloquantes, droits restreints, archivage, journal (T-009 côté base).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'a@test.invalid'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editeur@test.invalid'),
  ('55555555-5555-4555-8555-555555555555', 'super@test.invalid');
insert into public.user_roles (user_id, role) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'editor'),
  ('55555555-5555-4555-8555-555555555555', 'super_admin');

-- ---------------------------------------------------------------- éditeur
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}', true);

select lives_ok(
  $$ insert into public.editions (id, name, edition_number)
     values ('ed000000-0000-4000-8000-000000000006', 'Louanges à Dieu (test)', 6) $$,
  'l''éditeur crée une édition'
);

select lives_ok(
  $$ insert into public.hymns (id, edition_id, number_label, number_numeric, number_suffix, title, status)
     values ('a0000000-0000-4000-8000-000000000037', 'ed000000-0000-4000-8000-000000000006',
             '37bis', 37, 'bis', 'Titre de test', 'published') $$,
  'l''éditeur crée un cantique 37bis'
);
select is(
  (select status::text from public.hymns where id = 'a0000000-0000-4000-8000-000000000037'),
  'draft', 'un nouveau cantique entre toujours en brouillon, même si un autre statut est fourni'
);

select throws_ok(
  $$ insert into public.hymns (edition_id, number_label, number_numeric, title)
     values ('ed000000-0000-4000-8000-000000000006', '38', 38, E'   ') $$,
  '23514', null, 'un titre vide (espaces insécables compris) est refusé'
);
select throws_ok(
  $$ insert into public.hymns (edition_id, number_label, number_numeric, number_suffix, title)
     values ('ed000000-0000-4000-8000-000000000006', '39', 38, 'bis', 'Incohérent') $$,
  '23514', null, 'un libellé de numéro incohérent est refusé'
);
select throws_ok(
  $$ insert into public.hymns (edition_id, number_label, number_numeric, title, opening_line)
     values ('ed000000-0000-4000-8000-000000000006', '40', 40, 'Titre', '') $$,
  '23514', null, 'une première ligne vide est refusée (inconnu = NULL)'
);

select throws_ok(
  $$ update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000037';
     update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037' $$,
  '23514', null, 'un cantique sans section ne peut pas être validé'
);

insert into public.hymn_sections (id, hymn_id, section_type, section_number, text, display_order)
values ('5e000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000037',
        'verse', 1, E'Première ligne,\nDeuxième ligne. (bis)', 0);

select throws_ok(
  $$ update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037' $$,
  '23514', null, 'draft → published directement est interdit'
);

update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000037';
update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037';
select is(
  (select status::text || '/' || validated_by::text from public.hymns
    where id = 'a0000000-0000-4000-8000-000000000037'),
  'published/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'review → published enregistre le validateur'
);

update public.hymns set title = 'Titre corrigé' where id = 'a0000000-0000-4000-8000-000000000037';
select is(
  (select status::text from public.hymns where id = 'a0000000-0000-4000-8000-000000000037'),
  'draft', 'modifier le titre d''un cantique validé le repasse en brouillon'
);
select is(
  (select validated_by from public.hymns where id = 'a0000000-0000-4000-8000-000000000037'),
  null, 'la validation précédente est effacée'
);

update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000037';
update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037';
update public.hymn_sections set text = E'Première ligne modifiée,\nDeuxième ligne. (bis)'
 where id = '5e000000-0000-4000-8000-000000000001';
select is(
  (select status::text from public.hymns where id = 'a0000000-0000-4000-8000-000000000037'),
  'draft', 'modifier une section d''un cantique validé le repasse en brouillon'
);

-- Anomalie bloquante
insert into public.import_batches (id, edition_id, source_filename, source_sha256, parser_version)
values ('ba000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006',
        'test.docx', repeat('a', 64), 'test');
insert into public.import_issues (id, batch_id, hymn_id, code, severity, message)
values ('15000000-0000-4000-8000-000000000001', 'ba000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000037', 'A-05', 'blocking', 'Section très longue');

update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000037';
select throws_ok(
  $$ update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037' $$,
  '23514', null, 'une anomalie bloquante ouverte empêche la validation'
);
select throws_ok(
  $$ update public.import_issues set status = 'ignored', resolved_at = now()
      where id = '15000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'ignorer une anomalie exige une justification'
);
update public.import_issues
   set status = 'resolved', resolved_at = now(), resolved_by = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
 where id = '15000000-0000-4000-8000-000000000001';
select lives_ok(
  $$ update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037' $$,
  'une fois l''anomalie résolue, la validation est possible'
);

-- Droits restreints
insert into public.rights_records (hymn_id, rights_status) values
  ('a0000000-0000-4000-8000-000000000037', 'restricted');
select is(
  (select rights_status::text from public.hymn_rights where hymn_id = 'a0000000-0000-4000-8000-000000000037'),
  'restricted', 'la vue hymn_rights expose le statut effectif'
);
update public.hymns set status = 'draft' where id = 'a0000000-0000-4000-8000-000000000037';
update public.hymns set status = 'review' where id = 'a0000000-0000-4000-8000-000000000037';
select throws_ok(
  $$ update public.hymns set status = 'published' where id = 'a0000000-0000-4000-8000-000000000037' $$,
  '23514', null, 'des droits restreints empêchent la validation'
);

-- Validation par lots
insert into public.hymns (id, edition_id, number_label, number_numeric, title)
values ('a0000000-0000-4000-8000-000000000001', 'ed000000-0000-4000-8000-000000000006', '1', 1, 'Un');
insert into public.hymn_sections (hymn_id, section_type, text, display_order)
values ('a0000000-0000-4000-8000-000000000001', 'verse', 'Ligne unique.', 0);
select results_eq(
  $$ select hymn_id::text || ':' || ok::text
       from public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001',
                                         'a0000000-0000-4000-8000-000000000037']::uuid[], 'published') $$,
  array['a0000000-0000-4000-8000-000000000001:false', 'a0000000-0000-4000-8000-000000000037:false'],
  'lot : draft → published refusé pour le premier, droits restreints pour le second'
);
select results_eq(
  $$ select ok from public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001']::uuid[], 'review') $$,
  array[true], 'lot : soumission en relecture'
);
select results_eq(
  $$ select ok from public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001']::uuid[], 'published') $$,
  array[true], 'lot : validation'
);

-- Archivage
select throws_ok(
  $$ update public.hymns set status = 'archived' where id = 'a0000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'l''éditeur ne peut pas archiver'
);
-- Sous RLS, un DELETE non autorisé ne lève pas d'erreur : il n'affecte aucune ligne.
delete from public.hymns where id = 'a0000000-0000-4000-8000-000000000001';
select ok(
  exists (select 1 from public.hymns where id = 'a0000000-0000-4000-8000-000000000001'),
  'l''éditeur ne peut pas supprimer un cantique (aucune ligne supprimée)'
);

select ok(
  (select count(*) from public.audit_log
    where table_name = 'hymns' and record_id = 'a0000000-0000-4000-8000-000000000037'
      and actor_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') >= 5,
  'les modifications sont journalisées avec leur auteur'
);

-- ------------------------------------------------------------ super_admin
select set_config('request.jwt.claims', '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}', true);
select lives_ok(
  $$ update public.hymns set status = 'archived' where id = 'a0000000-0000-4000-8000-000000000001' $$,
  'le super_admin archive'
);

-- ------------------------------------------------------- utilisateur simple
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select is_empty($$ select 1 from public.hymns $$, 'un utilisateur simple ne voit pas la copie de travail');
select is_empty($$ select 1 from public.audit_log $$, 'ni le journal');
select throws_ok(
  $$ insert into public.hymns (edition_id, number_label, number_numeric, title)
     values ('ed000000-0000-4000-8000-000000000006', '2', 2, 'Deux') $$,
  '42501', null, 'un utilisateur simple ne peut pas créer de cantique'
);
select throws_ok(
  $$ select * from public.set_hymns_status(array['a0000000-0000-4000-8000-000000000001']::uuid[], 'review') $$,
  '42501', null, 'un utilisateur simple ne peut pas changer de statut'
);

-- ----------------------------------------------------------------- anonyme
reset role;
set local role anon;
select throws_ok($$ select * from public.hymns $$, '42501', null, 'anon ne peut pas lire la copie de travail');
select throws_ok($$ select * from public.audit_log $$, '42501', null, 'anon ne peut pas lire le journal');

reset role;
select * from finish();
rollback;
