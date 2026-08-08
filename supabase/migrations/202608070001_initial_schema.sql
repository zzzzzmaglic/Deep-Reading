create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  source_name text not null,
  content_checksum text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.article_blocks (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete restrict,
  position integer not null check (position > 0),
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (article_id, position)
);

create table public.collections (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.article_collections (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete restrict,
  collection_id uuid not null references public.collections(id) on delete restrict,
  position integer not null check (position > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (article_id, collection_id),
  unique (collection_id, position)
);

create table public.asset_anchors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  asset_id uuid not null,
  article_id uuid not null references public.articles(id) on delete restrict,
  start_block_id uuid not null references public.article_blocks(id) on delete restrict,
  end_block_id uuid not null references public.article_blocks(id) on delete restrict,
  start_utf16_offset integer not null check (start_utf16_offset >= 0),
  end_utf16_offset integer not null check (end_utf16_offset >= 0),
  selected_text text not null,
  content_checksum text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    start_block_id <> end_block_id
    or start_utf16_offset <= end_utf16_offset
  ),
  unique (id, owner_id),
  unique (asset_id),
  unique (asset_id, id)
);

create table public.reading_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  anchor_id uuid,
  note_content text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (note_content is not null or anchor_id is not null),
  unique (id, owner_id),
  foreign key (anchor_id, owner_id)
    references public.asset_anchors(id, owner_id)
    on delete no action
    deferrable initially deferred,
  foreign key (id, anchor_id)
    references public.asset_anchors(asset_id, id)
    on delete no action
    deferrable initially deferred
);

create table public.reading_progress (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete restrict,
  block_id uuid references public.article_blocks(id) on delete restrict,
  utf16_offset integer not null default 0 check (utf16_offset >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, article_id)
);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name),
  unique (id, owner_id),
  check (not is_system or name = '摘录与思考')
);

create table public.asset_tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  asset_id uuid not null,
  tag_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (asset_id, tag_id),
  foreign key (asset_id, owner_id)
    references public.reading_assets(id, owner_id)
    on delete cascade,
  foreign key (tag_id, owner_id)
    references public.tags(id, owner_id)
    on delete cascade
);

alter table public.asset_anchors
add constraint asset_anchors_asset_id_owner_id_fkey
foreign key (asset_id, owner_id)
references public.reading_assets(id, owner_id)
on delete cascade
deferrable initially deferred;

create trigger articles_set_updated_at
before update on public.articles
for each row execute function public.set_updated_at();

create trigger article_blocks_set_updated_at
before update on public.article_blocks
for each row execute function public.set_updated_at();

create trigger collections_set_updated_at
before update on public.collections
for each row execute function public.set_updated_at();

create trigger article_collections_set_updated_at
before update on public.article_collections
for each row execute function public.set_updated_at();

create trigger asset_anchors_set_updated_at
before update on public.asset_anchors
for each row execute function public.set_updated_at();

create trigger reading_assets_set_updated_at
before update on public.reading_assets
for each row execute function public.set_updated_at();

create trigger reading_progress_set_updated_at
before update on public.reading_progress
for each row execute function public.set_updated_at();

create trigger tags_set_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

create trigger asset_tags_set_updated_at
before update on public.asset_tags
for each row execute function public.set_updated_at();

alter table public.articles enable row level security;
alter table public.article_blocks enable row level security;
alter table public.collections enable row level security;
alter table public.article_collections enable row level security;
alter table public.reading_progress enable row level security;
alter table public.reading_assets enable row level security;
alter table public.asset_anchors enable row level security;
alter table public.tags enable row level security;
alter table public.asset_tags enable row level security;

grant select on public.articles, public.article_blocks, public.collections, public.article_collections to authenticated;
grant select on public.reading_progress, public.reading_assets, public.asset_anchors, public.tags, public.asset_tags to authenticated;

create policy "authenticated users can read seed articles"
on public.articles for select to authenticated using (true);

create policy "authenticated users can read seed article blocks"
on public.article_blocks for select to authenticated using (true);

create policy "authenticated users can read seed collections"
on public.collections for select to authenticated using (true);

create policy "authenticated users can read seed article collections"
on public.article_collections for select to authenticated using (true);

create policy "owners can read reading progress"
on public.reading_progress for select to authenticated using (owner_id = auth.uid());

create policy "owners can read reading assets"
on public.reading_assets for select to authenticated using (owner_id = auth.uid());

create policy "owners can read asset anchors"
on public.asset_anchors for select to authenticated using (owner_id = auth.uid());

create policy "owners can read tags"
on public.tags for select to authenticated using (owner_id = auth.uid());

create policy "owners can read asset tags"
on public.asset_tags for select to authenticated using (owner_id = auth.uid());

create or replace function public.create_highlight_asset(
  p_article_id uuid,
  p_start_block_id uuid,
  p_end_block_id uuid,
  p_start_utf16_offset integer,
  p_end_utf16_offset integer,
  p_selected_text text,
  p_content_checksum text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_asset_id uuid := gen_random_uuid();
  v_anchor_id uuid := gen_random_uuid();
  v_locked_tag_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  if p_start_utf16_offset < 0 or p_end_utf16_offset < 0 then
    raise exception using errcode = '22023', message = 'anchor offsets must be non-negative';
  end if;

  if p_start_block_id = p_end_block_id and p_start_utf16_offset > p_end_utf16_offset then
    raise exception using errcode = '22023', message = 'anchor end must not precede anchor start';
  end if;

  if not exists (
    select 1
    from public.article_blocks start_block
    join public.article_blocks end_block on end_block.id = p_end_block_id
    where start_block.id = p_start_block_id
      and start_block.article_id = p_article_id
      and end_block.article_id = p_article_id
  ) then
    raise exception using errcode = '23503', message = 'anchor blocks must belong to the article';
  end if;

  insert into public.reading_assets (id, owner_id, anchor_id, note_content)
  values (v_asset_id, v_owner_id, v_anchor_id, null);

  insert into public.asset_anchors (
    id,
    owner_id,
    asset_id,
    article_id,
    start_block_id,
    end_block_id,
    start_utf16_offset,
    end_utf16_offset,
    selected_text,
    content_checksum
  )
  values (
    v_anchor_id,
    v_owner_id,
    v_asset_id,
    p_article_id,
    p_start_block_id,
    p_end_block_id,
    p_start_utf16_offset,
    p_end_utf16_offset,
    p_selected_text,
    p_content_checksum
  );

  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, '摘录与思考', true)
  on conflict (owner_id, name) do update
  set is_system = true
  returning id into v_locked_tag_id;

  insert into public.asset_tags (owner_id, asset_id, tag_id)
  values (v_owner_id, v_asset_id, v_locked_tag_id)
  on conflict (asset_id, tag_id) do nothing;

  return v_asset_id;
end;
$$;

create or replace function public.create_standalone_note(
  p_note_content text
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

  insert into public.reading_assets (id, owner_id, note_content)
  values (v_asset_id, v_owner_id, v_note_content);

  insert into public.tags (owner_id, name, is_system)
  values (v_owner_id, '摘录与思考', true)
  on conflict (owner_id, name) do update
  set is_system = true
  returning id into v_locked_tag_id;

  insert into public.asset_tags (owner_id, asset_id, tag_id)
  values (v_owner_id, v_asset_id, v_locked_tag_id)
  on conflict (asset_id, tag_id) do nothing;

  return v_asset_id;
end;
$$;

create or replace function public.update_reading_asset(
  p_asset_id uuid,
  p_note_content text
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

  select anchor_id into v_anchor_id
  from public.reading_assets
  where id = p_asset_id
    and owner_id = v_owner_id
  for update;

  if not found then
    raise exception using errcode = '42501', message = 'reading asset is not owned by the current user';
  end if;

  if v_anchor_id is null and v_note_content is null then
    raise exception using errcode = '22023', message = 'an anchorless reading asset requires note content';
  end if;

  update public.reading_assets
  set note_content = v_note_content
  where id = p_asset_id
    and owner_id = v_owner_id;

  return p_asset_id;
end;
$$;

create or replace function public.set_asset_tags(
  p_asset_id uuid,
  p_tag_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  p_tag_ids := coalesce(p_tag_ids, '{}'::uuid[]);

  if not exists (
    select 1
    from public.reading_assets
    where id = p_asset_id
      and owner_id = v_owner_id
  ) then
    raise exception using errcode = '42501', message = 'reading asset is not owned by the current user';
  end if;

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

  if exists (
    select 1
    from public.asset_tags asset_tag
    join public.tags tag on tag.id = asset_tag.tag_id
    where asset_tag.asset_id = p_asset_id
      and asset_tag.owner_id = v_owner_id
      and tag.is_system
      and not (asset_tag.tag_id = any(p_tag_ids))
  ) then
    raise exception using errcode = '22023', message = 'locked tag relations cannot be removed';
  end if;

  delete from public.asset_tags
  where asset_id = p_asset_id
    and owner_id = v_owner_id
    and not (tag_id = any(p_tag_ids));

  insert into public.asset_tags (owner_id, asset_id, tag_id)
  select v_owner_id, p_asset_id, requested.tag_id
  from unnest(p_tag_ids) as requested(tag_id)
  on conflict (asset_id, tag_id) do nothing;
end;
$$;

create or replace function public.delete_reading_asset(
  p_asset_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  delete from public.reading_assets
  where id = p_asset_id
    and owner_id = v_owner_id;

  if not found then
    raise exception using errcode = '42501', message = 'reading asset is not owned by the current user';
  end if;
end;
$$;

create or replace function public.upsert_reading_progress(
  p_article_id uuid,
  p_block_id uuid,
  p_utf16_offset integer
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_progress_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  if p_utf16_offset < 0 then
    raise exception using errcode = '22023', message = 'reading progress offset must be non-negative';
  end if;

  if not exists (
    select 1
    from public.articles
    where id = p_article_id
  ) then
    raise exception using errcode = '23503', message = 'article does not exist';
  end if;

  if p_block_id is not null and not exists (
    select 1
    from public.article_blocks
    where id = p_block_id
      and article_id = p_article_id
  ) then
    raise exception using errcode = '23503', message = 'progress block must belong to the article';
  end if;

  insert into public.reading_progress (owner_id, article_id, block_id, utf16_offset)
  values (v_owner_id, p_article_id, p_block_id, p_utf16_offset)
  on conflict (owner_id, article_id) do update
  set block_id = excluded.block_id,
      utf16_offset = excluded.utf16_offset
  returning id into v_progress_id;

  return v_progress_id;
end;
$$;

revoke all on function public.create_highlight_asset(uuid, uuid, uuid, integer, integer, text, text) from public;
revoke all on function public.create_standalone_note(text) from public;
revoke all on function public.update_reading_asset(uuid, text) from public;
revoke all on function public.set_asset_tags(uuid, uuid[]) from public;
revoke all on function public.delete_reading_asset(uuid) from public;
revoke all on function public.upsert_reading_progress(uuid, uuid, integer) from public;

grant execute on function public.create_highlight_asset(uuid, uuid, uuid, integer, integer, text, text) to authenticated;
grant execute on function public.create_standalone_note(text) to authenticated;
grant execute on function public.update_reading_asset(uuid, text) to authenticated;
grant execute on function public.set_asset_tags(uuid, uuid[]) to authenticated;
grant execute on function public.delete_reading_asset(uuid) to authenticated;
grant execute on function public.upsert_reading_progress(uuid, uuid, integer) to authenticated;
