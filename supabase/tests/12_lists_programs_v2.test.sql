-- Planche 4 : icône et couleur des listes ; lieu, description, image, modèle
-- et options des programmes ; un ancien client ne les efface pas ; page
-- publique avec lieu et description.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('31111111-1111-4111-8111-111111111111', 'c@test.invalid');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"31111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal1"}', true);

-- Listes
select lives_ok(
  $$ select public.sync_push_playlist('{"id":"c1000000-0000-4000-8000-000000000001","name":"Prière",
       "icon":"prayer","color":"teal","items":[]}') $$,
  'une liste avec icône et couleur est enregistrée'
);
select is(
  (select jsonb_build_object('icon', p -> 'icon', 'color', p -> 'color')
     from jsonb_array_elements(public.sync_pull(0) -> 'playlists') p),
  '{"icon": "prayer", "color": "teal"}'::jsonb,
  'icône et couleur reviennent par sync_pull'
);
select lives_ok(
  $$ select public.sync_push_playlist('{"id":"c1000000-0000-4000-8000-000000000001","name":"Prière du soir","items":[]}') $$,
  'un ancien client (sans icône ni couleur) renomme la liste'
);
select is(
  (select p ->> 'icon' from jsonb_array_elements(public.sync_pull(0) -> 'playlists') p),
  'prayer',
  'l’icône n’est pas effacée par un client qui ne la connaît pas'
);
select throws_ok(
  $$ select public.sync_push_playlist('{"id":"c1000000-0000-4000-8000-000000000002","name":"X","icon":"skull"}') $$,
  '23514', null, 'une icône inconnue est refusée'
);
select throws_ok(
  $$ select public.sync_push_playlist('{"id":"c1000000-0000-4000-8000-000000000002","name":"X","color":"#FF0000"}') $$,
  '23514', null, 'une couleur hors palette est refusée'
);

-- Programmes
select lives_ok(
  $$ select public.sync_push_worship_service('{"id":"c2000000-0000-4000-8000-000000000001",
       "title":"Culte du dimanche","serviceDate":"2026-10-25","status":"published",
       "location":"Temple central","description":"Louange et adoration.",
       "cover":"hero_wheat_sunset","isTemplate":false,
       "options":{"showNumbers":true,"background":"dark"},"items":[]}') $$,
  'un programme avec lieu, description, image et options est enregistré'
);
select is(
  (select w - 'revision' - 'id' - 'items'
     from jsonb_array_elements(public.sync_pull(0) -> 'worshipServices') w),
  '{"title": "Culte du dimanche", "serviceDate": "2026-10-25", "status": "published",
    "location": "Temple central", "description": "Louange et adoration.",
    "cover": "hero_wheat_sunset", "isTemplate": false,
    "options": {"showNumbers": true, "background": "dark"}, "deleted": false}'::jsonb,
  'tous les champs reviennent par sync_pull'
);
select lives_ok(
  $$ select public.sync_push_worship_service('{"id":"c2000000-0000-4000-8000-000000000001",
       "title":"Culte","serviceDate":"2026-10-25","status":"published","items":[]}') $$,
  'un ancien client modifie le titre'
);
select is(
  (select w ->> 'location' from jsonb_array_elements(public.sync_pull(0) -> 'worshipServices') w),
  'Temple central',
  'le lieu n’est pas effacé par un client qui ne le connaît pas'
);
select throws_ok(
  $$ select public.sync_push_worship_service('{"id":"c2000000-0000-4000-8000-000000000002",
       "title":"X","cover":"https://exemple.org/a.jpg"}') $$,
  '23514', null, 'une image doit être une photo de l’app, pas une adresse'
);
select throws_ok(
  $$ select public.sync_push_worship_service('{"id":"c2000000-0000-4000-8000-000000000002",
       "title":"X","options":[1,2]}') $$,
  '23514', null, 'les options sont un objet'
);
select lives_ok(
  $$ select public.sync_push_worship_service('{"id":"c2000000-0000-4000-8000-000000000003",
       "title":"Modèle de culte","isTemplate":true,"items":[]}') $$,
  'un modèle est enregistré'
);
select is(
  (select (w ->> 'isTemplate')::boolean from jsonb_array_elements(public.sync_pull(0) -> 'worshipServices') w
    where w ->> 'id' = 'c2000000-0000-4000-8000-000000000003'),
  true, 'le modèle est signalé'
);

-- Page publique
select public.create_share_link('c2000000-0000-4000-8000-000000000001', null);
reset role;
select is(
  (select jsonb_build_object('location', p -> 'location', 'description', p -> 'description')
     from (select public.get_shared_program(w.share_token) p
             from public.worship_services w
            where w.id = 'c2000000-0000-4000-8000-000000000001') s),
  '{"location": "Temple central", "description": "Louange et adoration."}'::jsonb,
  'la page publique donne le lieu et la description'
);

select * from finish();
rollback;
