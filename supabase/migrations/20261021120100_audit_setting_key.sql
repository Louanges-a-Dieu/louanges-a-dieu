-- Journal : une ligne de app_settings est identifiée par sa clé (pas de
-- colonne id). Même fonction que 0005, avec `key` en dernier recours.
create or replace function private.audit_row()
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
    coalesce(v_row ->> 'id', v_row ->> 'hymn_id', v_row ->> 'user_id', v_row ->> 'key'),
    lower(tg_op),
    v_changes
  );
  return coalesce(new, old);
end;
$$;
