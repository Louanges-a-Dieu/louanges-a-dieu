-- Migration 0027 — Corrections linguistiques proposées (Q-04, A-13, tâche 3.11)
--
-- Les tableurs de relecture (≈ 450 propositions, ancienne numérotation) sont
-- rapprochés du texte actuel PAR LE TEXTE dans `content-tools corrections`.
-- Chaque proposition encore utile devient une anomalie A-13 de la file
-- éditoriale, rattachée au cantique concerné :
--   pending   : le passage fautif est toujours là, la correction est prête ;
--   conflict  : le passage a été retouché depuis la relecture, à arbitrer ;
--   not_found : aucun passage correspondant (information).
-- Rien n'est appliqué automatiquement : l'éditeur applique (`apply_correction`)
-- ou refuse (`resolve_issues` … 'ignored', justification obligatoire) chaque
-- proposition. L'application passe par la RLS et les triggers habituels :
-- journal, et retour en brouillon d'un cantique validé (T-009).

-- ---------------------------------------------------------------------------
-- Position d'un passage dans un texte
-- ---------------------------------------------------------------------------

-- Position (à partir de 0, en caractères) de l'occurrence de p_passage la plus
-- proche de p_offset ; NULL si le passage n'y figure plus. Tolère les
-- retouches faites ailleurs dans le texte depuis la proposition (décalage).
create function private.locate_passage(p_text text, p_passage text, p_offset integer)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_best integer;
  v_from integer := 1;
  v_found integer;
begin
  if p_text is null or p_passage is null or p_passage = '' then
    return null;
  end if;
  if substr(p_text, p_offset + 1, length(p_passage)) = p_passage then
    return p_offset;
  end if;
  loop
    v_found := strpos(substr(p_text, v_from), p_passage);
    exit when v_found = 0;
    v_found := v_from + v_found - 2;
    if v_best is null or abs(v_found - p_offset) < abs(v_best - p_offset) then
      v_best := v_found;
    end if;
    v_from := v_found + 2;
  end loop;
  return v_best;
end;
$$;

revoke all on function private.locate_passage(text, text, integer) from public, anon;
grant execute on function private.locate_passage(text, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Chargement des propositions
-- ---------------------------------------------------------------------------

-- p_payload (format « lad.corrections », produit par content-tools) :
--   source      { filename, sha256, parserVersion }
--   editionId   édition corrigée
--   stats       décompte par statut, conservé dans le lot
--   suggestions [{ key, status, hymnId, passages[{unit, sectionId, offset,
--                  current, replacement, context}], source{…ligne du tableur} }]
-- Idempotent : une proposition déjà chargée (même clé, quel que soit son
-- statut dans la file) n'est pas recréée — une proposition refusée ne revient
-- pas au chargement suivant.
create function public.import_corrections(p_payload jsonb, p_dry_run boolean default false)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_edition_id uuid;
  v_batch_id uuid;
  v_new jsonb;
  v_known integer;
  v_suggestion jsonb;
  v_passage jsonb;
  v_hymn_id uuid;
  v_text text;
  v_status text;
  v_created integer := 0;
  v_first jsonb;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;
  if p_payload ->> 'format' is distinct from 'lad.corrections'
     or (p_payload ->> 'version') is distinct from '1' then
    raise exception 'Format de propositions inattendu' using errcode = 'invalid_parameter_value';
  end if;

  v_edition_id := (p_payload ->> 'editionId')::uuid;
  if not exists (select 1 from public.editions e where e.id = v_edition_id) then
    raise exception 'Édition introuvable' using errcode = 'invalid_parameter_value';
  end if;

  select count(*) into v_known
    from jsonb_array_elements(p_payload -> 'suggestions') s
   where exists (
     select 1 from public.import_issues i
      where i.code = 'A-13' and i.details ->> 'key' = s ->> 'key');
  select coalesce(jsonb_agg(s), '[]'::jsonb) into v_new
    from jsonb_array_elements(p_payload -> 'suggestions') s
   where not exists (
     select 1 from public.import_issues i
      where i.code = 'A-13' and i.details ->> 'key' = s ->> 'key');

  -- Contrôle de chaque nouvelle proposition : cantique de l'édition, section
  -- du cantique, passage présent à la position indiquée.
  for v_suggestion in select * from jsonb_array_elements(v_new) loop
    v_status := v_suggestion ->> 'status';
    if v_status is null or v_status not in ('pending', 'conflict', 'not_found') then
      raise exception 'Statut de proposition inattendu : %', v_status
        using errcode = 'invalid_parameter_value';
    end if;
    if private.is_blank(v_suggestion ->> 'key') then
      raise exception 'Proposition sans clé' using errcode = 'invalid_parameter_value';
    end if;
    v_hymn_id := (v_suggestion ->> 'hymnId')::uuid;
    if (v_status = 'not_found') <> (v_hymn_id is null)
       or (v_status = 'not_found') <> (jsonb_array_length(v_suggestion -> 'passages') = 0) then
      raise exception 'Proposition incohérente : %', v_suggestion ->> 'key'
        using errcode = 'invalid_parameter_value';
    end if;
    if v_hymn_id is not null and not exists (
      select 1 from public.hymns h where h.id = v_hymn_id and h.edition_id = v_edition_id
    ) then
      raise exception 'Cantique hors de l''édition : %', v_suggestion ->> 'key'
        using errcode = 'invalid_parameter_value';
    end if;
    for v_passage in select * from jsonb_array_elements(v_suggestion -> 'passages') loop
      v_text := case v_passage ->> 'unit'
        when 'title' then (select h.title from public.hymns h where h.id = v_hymn_id)
        when 'opening_line' then (select h.opening_line from public.hymns h where h.id = v_hymn_id)
        when 'section' then (
          select s.text from public.hymn_sections s
           where s.id = (v_passage ->> 'sectionId')::uuid and s.hymn_id = v_hymn_id)
      end;
      if v_text is null
         or substr(v_text, (v_passage ->> 'offset')::integer + 1, length(v_passage ->> 'current'))
            is distinct from v_passage ->> 'current'
         or (v_status = 'pending') <> (v_passage ->> 'replacement' is not null) then
        raise exception 'Passage introuvable à la position indiquée : %', v_suggestion ->> 'key'
          using errcode = 'invalid_parameter_value';
      end if;
    end loop;
  end loop;

  if not p_dry_run and jsonb_array_length(v_new) > 0 then
    insert into public.import_batches (edition_id, source_filename, source_sha256, parser_version, stats)
    values (v_edition_id,
            p_payload #>> '{source,filename}',
            p_payload #>> '{source,sha256}',
            p_payload #>> '{source,parserVersion}',
            coalesce(p_payload -> 'stats', '{}'::jsonb)
              || jsonb_build_object('suggestionsCreated', jsonb_array_length(v_new)))
    returning id into v_batch_id;

    for v_suggestion in select * from jsonb_array_elements(v_new) loop
      v_status := v_suggestion ->> 'status';
      v_first := v_suggestion -> 'passages' -> 0;
      insert into public.import_issues (batch_id, hymn_id, code, severity, message, details)
      values (
        v_batch_id,
        (v_suggestion ->> 'hymnId')::uuid,
        'A-13',
        case when v_status = 'not_found' then 'info' else 'warning' end::public.issue_severity,
        case v_status
          when 'pending' then format('Correction proposée : « %s » → « %s »',
                                     v_first ->> 'current', v_first ->> 'replacement')
          when 'conflict' then format('Correction proposée sur un passage retouché depuis la relecture : « %s » (à arbitrer)',
                                      v_suggestion #>> '{source,proposed}')
          else format('Correction proposée introuvable dans le recueil : « %s »',
                      v_suggestion #>> '{source,original}')
        end,
        jsonb_build_object(
          'key', v_suggestion ->> 'key',
          'suggestion', v_status,
          'passages', v_suggestion -> 'passages',
          'source', v_suggestion -> 'source'
        )
      );
      v_created := v_created + 1;
    end loop;
  end if;

  return jsonb_build_object(
    'dryRun', p_dry_run,
    'batchId', v_batch_id,
    'received', jsonb_array_length(p_payload -> 'suggestions'),
    'alreadyKnown', v_known,
    'created', case when p_dry_run then 0 else v_created end,
    'new', jsonb_array_length(v_new)
  );
end;
$$;

revoke all on function public.import_corrections(jsonb, boolean) from public, anon;
grant execute on function public.import_corrections(jsonb, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Application d'une proposition
-- ---------------------------------------------------------------------------

-- Applique une proposition A-13 ouverte : chaque passage est remplacé par la
-- correction proposée, ou par le texte saisi par l'éditeur (p_replacements,
-- dans l'ordre des passages ; NULL ou absent = proposition conservée). Refuse
-- si un passage n'est plus dans le texte (corriger alors dans la fiche du
-- cantique). La proposition est marquée résolue par l'éditeur.
create function public.apply_correction(p_issue_id uuid, p_replacements text[] default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_issue public.import_issues;
  v_passages jsonb;
  v_passage jsonb;
  v_index integer;
  v_replacement text;
  v_current text;
  v_text text;
  v_at integer;
  v_edited boolean := false;
  v_applied jsonb := '[]'::jsonb;
begin
  if not private.has_role('editor') then
    raise exception 'Rôle éditeur requis' using errcode = 'insufficient_privilege';
  end if;

  select * into v_issue from public.import_issues i where i.id = p_issue_id for update;
  if v_issue.id is null or v_issue.code <> 'A-13' then
    raise exception 'Proposition de correction introuvable' using errcode = 'no_data_found';
  end if;
  if v_issue.status <> 'open' then
    raise exception 'Cette proposition a déjà été traitée' using errcode = 'check_violation';
  end if;
  v_passages := coalesce(v_issue.details -> 'passages', '[]'::jsonb);
  if jsonb_array_length(v_passages) = 0 then
    raise exception 'Passage introuvable dans le recueil : corrigez dans la fiche du cantique'
      using errcode = 'check_violation';
  end if;
  if p_replacements is not null and cardinality(p_replacements) > jsonb_array_length(v_passages) then
    raise exception 'Plus de textes corrigés que de passages' using errcode = 'invalid_parameter_value';
  end if;

  -- Du dernier passage au premier : les positions des précédents restent justes.
  for v_index, v_passage in
    select (o - 1)::integer, p
      from jsonb_array_elements(v_passages) with ordinality as t(p, o)
     order by p ->> 'unit', p ->> 'sectionId', (p ->> 'offset')::integer desc
  loop
    v_current := v_passage ->> 'current';
    v_replacement := coalesce(nullif(p_replacements[v_index + 1], ''), v_passage ->> 'replacement');
    if p_replacements[v_index + 1] is not null and p_replacements[v_index + 1] <> ''
       and p_replacements[v_index + 1] is distinct from v_passage ->> 'replacement' then
      v_edited := true;
    end if;
    if v_replacement is null then
      raise exception 'Indiquez le texte corrigé du passage « % »', v_current
        using errcode = 'check_violation';
    end if;
    if v_passage ->> 'unit' in ('title', 'opening_line') and v_replacement ~ '[\r\n]' then
      raise exception 'Le titre et le premier vers tiennent sur une seule ligne'
        using errcode = 'check_violation';
    end if;

    v_text := case v_passage ->> 'unit'
      when 'title' then (select h.title from public.hymns h where h.id = v_issue.hymn_id)
      when 'opening_line' then (select h.opening_line from public.hymns h where h.id = v_issue.hymn_id)
      else (select s.text from public.hymn_sections s
             where s.id = (v_passage ->> 'sectionId')::uuid and s.hymn_id = v_issue.hymn_id)
    end;
    v_at := private.locate_passage(v_text, v_current, (v_passage ->> 'offset')::integer);
    if v_at is null then
      raise exception 'Le passage « % » a changé depuis la proposition : corrigez dans la fiche du cantique', v_current
        using errcode = 'check_violation';
    end if;
    if v_replacement = v_current then
      continue;
    end if;
    v_text := overlay(v_text placing v_replacement from v_at + 1 for length(v_current));

    case v_passage ->> 'unit'
      when 'title' then
        update public.hymns h set title = v_text where h.id = v_issue.hymn_id;
      when 'opening_line' then
        update public.hymns h set opening_line = v_text where h.id = v_issue.hymn_id;
      else
        update public.hymn_sections s set text = v_text
         where s.id = (v_passage ->> 'sectionId')::uuid;
    end case;
    v_applied := v_applied || jsonb_build_object(
      'unit', v_passage ->> 'unit', 'sectionId', v_passage -> 'sectionId',
      'before', v_current, 'after', v_replacement);
  end loop;

  if jsonb_array_length(v_applied) = 0 then
    raise exception 'La correction ne change rien : refusez-la si le texte actuel convient'
      using errcode = 'check_violation';
  end if;

  update public.import_issues i
     set status = 'resolved',
         resolution_note = case when v_edited then 'Correction appliquée (texte ajusté par l’éditeur)'
                                else 'Correction appliquée' end,
         resolved_by = auth.uid(),
         resolved_at = now(),
         details = i.details || jsonb_build_object('applied', v_applied)
   where i.id = p_issue_id;

  return jsonb_build_object('hymnId', v_issue.hymn_id, 'applied', v_applied, 'edited', v_edited);
end;
$$;

revoke all on function public.apply_correction(uuid, text[]) from public, anon;
grant execute on function public.apply_correction(uuid, text[]) to authenticated;

-- Propositions encore ouvertes, pour l'écran « Corrections » du back-office.
create index import_issues_open_corrections_idx on public.import_issues (created_at)
  where code = 'A-13' and status = 'open';
