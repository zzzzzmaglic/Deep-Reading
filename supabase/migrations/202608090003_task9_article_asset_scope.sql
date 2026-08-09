alter table public.reading_assets
add column article_id uuid references public.articles(id) on delete restrict;

create index reading_assets_owner_article_id_idx
on public.reading_assets (owner_id, article_id)
where article_id is not null;

create function public.create_standalone_note(
  p_note_content text,
  p_article_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_asset_id uuid := gen_random_uuid();
  v_locked_tag_id uuid;
  v_note_content text := nullif(btrim(p_note_content), '');
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;
  if v_note_content is null then
    raise exception using errcode = '22023', message = 'standalone notes require content';
  end if;
  if p_article_id is not null and not exists (
    select 1 from public.articles where id = p_article_id
  ) then
    raise exception using errcode = '23503', message = 'article does not exist';
  end if;

  insert into public.reading_assets (id, owner_id, article_id, note_content)
  values (v_asset_id, v_owner_id, p_article_id, v_note_content);

  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, '摘录与思考', true)
  on conflict (owner_id, name) do update set is_system = true
  returning id into v_locked_tag_id;

  insert into public.asset_tags (owner_id, asset_id, tag_id)
  values (v_owner_id, v_asset_id, v_locked_tag_id)
  on conflict (asset_id, tag_id) do nothing;

  return v_asset_id;
end;
$$;

create function public.create_standalone_note_with_tags(
  p_note_content text,
  p_article_id uuid,
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
  if p_article_id is not null and not exists (
    select 1 from public.articles where id = p_article_id
  ) then
    raise exception using errcode = '23503', message = 'article does not exist';
  end if;

  p_tag_ids := coalesce(p_tag_ids, '{}'::uuid[]);
  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, '摘录与思考', true)
  on conflict (owner_id, name) do update set is_system = true
  returning id into v_locked_tag_id;
  p_tag_ids := array(select distinct unnest(array_append(p_tag_ids, v_locked_tag_id)));

  if exists (
    select 1
    from unnest(p_tag_ids) as requested(tag_id)
    left join public.tags tag
      on tag.id = requested.tag_id
      and tag.owner_id = v_owner_id
    where tag.id is null
  ) then
    raise exception using errcode = '42501', message = 'tags must belong to the current user';
  end if;

  insert into public.reading_assets (id, owner_id, article_id, note_content)
  values (v_asset_id, v_owner_id, p_article_id, v_note_content);
  insert into public.asset_tags (owner_id, asset_id, tag_id)
  select v_owner_id, v_asset_id, requested.tag_id
  from unnest(p_tag_ids) as requested(tag_id);

  return v_asset_id;
end;
$$;

revoke all on function public.create_standalone_note(text, uuid) from public;
revoke all on function public.create_standalone_note_with_tags(text, uuid, uuid[]) from public;
grant execute on function public.create_standalone_note(text, uuid) to authenticated;
grant execute on function public.create_standalone_note_with_tags(text, uuid, uuid[]) to authenticated;
