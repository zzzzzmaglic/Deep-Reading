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
