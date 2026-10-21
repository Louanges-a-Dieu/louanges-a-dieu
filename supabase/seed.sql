-- Données de démonstration (développement uniquement) — tâche 2.13
--
-- Contenu ENTIÈREMENT SYNTHÉTIQUE : aucune parole du recueil (droits, Q-19).
-- Passe par le vrai circuit éditorial (validation puis publish_release) pour
-- fournir aux applications une release de catalogue réelle.
-- Exécuté par `supabase db reset` ; jamais appliqué en recette ni en production.

-- Compte éditeur de démonstration (sans mot de passe : ne peut pas se connecter).
insert into auth.users (id, email)
values ('d0000000-0000-4000-8000-00000000ed17', 'editeur.demo@exemple.invalid')
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values ('d0000000-0000-4000-8000-00000000ed17', 'editor')
on conflict do nothing;

-- Agir en tant que cet éditeur pour le reste du script.
select set_config(
  'request.jwt.claims',
  -- aal2 : le rôle éditeur exige le second facteur (has_role, migration 0015).
  '{"sub":"d0000000-0000-4000-8000-00000000ed17","role":"authenticated","aal":"aal2"}',
  false
);

insert into public.editions (id, name, edition_number, description)
values ('d0000000-0000-4000-8000-000000000ed0', 'Édition de démonstration', 1,
        'Données synthétiques pour le développement — aucun contenu réel.');

insert into public.hymns (id, edition_id, number_label, number_numeric, number_suffix, title, opening_line) values
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000ed0', '1', 1, null,
   'Premier chant de démonstration', 'Premier chant de démonstration,'),
  ('d0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000ed0', '2', 2, null,
   'Chant avec refrain', 'Chant avec refrain'),
  ('d0000000-0000-4000-8000-000000000102', 'd0000000-0000-4000-8000-000000000ed0', '2bis', 2, 'bis',
   'Autre texte, même mélodie', 'Autre texte, même mélodie'),
  ('d0000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000ed0', '3', 3, null,
   'Chant resté en brouillon', null);

insert into public.hymn_sections (hymn_id, section_type, section_number, text, display_order) values
  ('d0000000-0000-4000-8000-000000000001', 'verse', 1,
   E'Premier chant de démonstration,\nDeuxième ligne du couplet,\nTroisième ligne répétée. (bis)', 0),
  ('d0000000-0000-4000-8000-000000000001', 'verse', 2,
   E'Second couplet, première ligne,\nSecond couplet, dernière ligne.', 1),
  ('d0000000-0000-4000-8000-000000000002', 'verse', 1,
   E'Chant avec refrain\nLigne de couplet.', 0),
  ('d0000000-0000-4000-8000-000000000002', 'refrain', null,
   E'Ligne de refrain,\nRefrain chanté trois fois. (ter)', 1),
  ('d0000000-0000-4000-8000-000000000002', 'verse', 2,
   E'Deuxième couplet,\nAvec une réponse (amen !)', 2),
  ('d0000000-0000-4000-8000-000000000102', 'verse', 1,
   E'Autre texte, même mélodie,\nLigne finale. (4x)', 0),
  ('d0000000-0000-4000-8000-000000000003', 'verse', 1, 'Texte en cours de saisie.', 0);

insert into public.bible_references (hymn_id, book, chapter_start, display_text)
values ('d0000000-0000-4000-8000-000000000001', 'Psaumes', 150, 'Psaumes 150');

insert into public.hymn_relations (hymn_id, related_hymn_id, relation)
values ('d0000000-0000-4000-8000-000000000102', 'd0000000-0000-4000-8000-000000000002', 'bis_of');

select * from public.set_hymns_status(
  array['d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002',
        'd0000000-0000-4000-8000-000000000102']::uuid[], 'review');
select * from public.set_hymns_status(
  array['d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002',
        'd0000000-0000-4000-8000-000000000102']::uuid[], 'published');

select public.publish_release('d0000000-0000-4000-8000-000000000ed0', 'Release de démonstration');

select set_config('request.jwt.claims', '', false);
