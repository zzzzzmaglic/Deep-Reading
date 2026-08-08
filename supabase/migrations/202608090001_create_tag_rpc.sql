create or replace function public.create_tag(p_name text)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_name text := nullif(btrim(p_name), '');
  v_tag_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  if v_name is null then
    raise exception using errcode = '22023', message = 'tag name is required';
  end if;

  if v_name = U&'\6458\5F55\4E0E\601D\8003' then
    raise exception using errcode = '22023', message = 'system tags cannot be created';
  end if;

  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, v_name, false)
  returning id into v_tag_id;

  return v_tag_id;
end;
$$;

revoke all on function public.create_tag(text) from public;
grant execute on function public.create_tag(text) to authenticated;
