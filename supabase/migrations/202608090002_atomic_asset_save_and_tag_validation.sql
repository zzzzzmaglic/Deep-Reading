create or replace function public.save_reading_asset(
  p_asset_id uuid,
  p_note_content text,
  p_tag_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_anchor_id uuid;
  v_note_content text := nullif(btrim(p_note_content), '');
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;
  p_tag_ids := coalesce(p_tag_ids, '{}'::uuid[]);
  select anchor_id into v_anchor_id from public.reading_assets
  where id = p_asset_id and owner_id = v_owner_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'reading asset is not owned by the current user';
  end if;
  if v_anchor_id is null and v_note_content is null then
    raise exception using errcode = '22023', message = 'an anchorless reading asset requires note content';
  end if;
  if exists (
    select 1 from unnest(p_tag_ids) as requested(tag_id)
    left join public.tags tag on tag.id = requested.tag_id and tag.owner_id = v_owner_id
    where tag.id is null
  ) then
    raise exception using errcode = '42501', message = 'tags must belong to the current user';
  end if;
  if exists (
    select 1 from public.asset_tags asset_tag join public.tags tag on tag.id = asset_tag.tag_id
    where asset_tag.asset_id = p_asset_id and asset_tag.owner_id = v_owner_id
      and tag.is_system and not (asset_tag.tag_id = any(p_tag_ids))
  ) then
    raise exception using errcode = '22023', message = 'locked tag relations cannot be removed';
  end if;
  update public.reading_assets set note_content = v_note_content
  where id = p_asset_id and owner_id = v_owner_id;
  delete from public.asset_tags where asset_id = p_asset_id and owner_id = v_owner_id
    and not (tag_id = any(p_tag_ids));
  insert into public.asset_tags (owner_id, asset_id, tag_id)
  select v_owner_id, p_asset_id, requested.tag_id from unnest(p_tag_ids) as requested(tag_id)
  on conflict (asset_id, tag_id) do nothing;
  return p_asset_id;
end;
$$;

create or replace function public.create_standalone_note_with_tags(
  p_note_content text,
  p_tag_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_note_content text := nullif(btrim(p_note_content), '');
  v_asset_id uuid := gen_random_uuid();
  v_locked_tag_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;
  if v_note_content is null then
    raise exception using errcode = '22023', message = 'standalone notes require content';
  end if;
  p_tag_ids := coalesce(p_tag_ids, '{}'::uuid[]);
  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, U&'\6458\5F55\4E0E\601D\8003', true)
  on conflict (owner_id, name) do update set is_system = true
  returning id into v_locked_tag_id;
  p_tag_ids := array(select distinct unnest(array_append(p_tag_ids, v_locked_tag_id)));
  if exists (
    select 1 from unnest(p_tag_ids) as requested(tag_id)
    left join public.tags tag on tag.id = requested.tag_id and tag.owner_id = v_owner_id
    where tag.id is null
  ) then
    raise exception using errcode = '42501', message = 'tags must belong to the current user';
  end if;
  insert into public.reading_assets (id, owner_id, note_content)
  values (v_asset_id, v_owner_id, v_note_content);
  insert into public.asset_tags (owner_id, asset_id, tag_id)
  select v_owner_id, v_asset_id, requested.tag_id from unnest(p_tag_ids) as requested(tag_id);
  return v_asset_id;
end;
$$;

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
  if v_owner_id is null then raise exception using errcode = '28000', message = 'authentication is required'; end if;
  if v_name is null then raise exception using errcode = '22023', message = 'tag name is required'; end if;
  if char_length(v_name) > 48 then raise exception using errcode = '22023', message = 'tag name is too long'; end if;
  if v_name ~ '[[:cntrl:]]' then raise exception using errcode = '22023', message = 'tag name contains control characters'; end if;
  if v_name = U&'\6458\5F55\4E0E\601D\8003' then raise exception using errcode = '22023', message = 'system tags cannot be created'; end if;
  if exists (select 1 from public.tags where owner_id = v_owner_id and name = v_name) then
    raise exception using errcode = '23505', message = 'tag name already exists';
  end if;
  insert into public.tags (owner_id, name, is_system) values (v_owner_id, v_name, false)
  returning id into v_tag_id;
  return v_tag_id;
end;
$$;

revoke all on function public.save_reading_asset(uuid, text, uuid[]) from public;
revoke all on function public.create_standalone_note_with_tags(text, uuid[]) from public;
revoke all on function public.create_tag(text) from public;
grant execute on function public.save_reading_asset(uuid, text, uuid[]) to authenticated;
grant execute on function public.create_standalone_note_with_tags(text, uuid[]) to authenticated;
grant execute on function public.create_tag(text) to authenticated;
