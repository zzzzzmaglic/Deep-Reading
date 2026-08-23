alter table public.collections
  add column is_system boolean not null default false;

alter table public.articles
  add column cover_asset_name text not null default 'KnowledgeCoverPlaceholder',
  add column cognitive_dimension text not null default '方法论',
  add column published_at timestamptz not null default now();

create table public.collection_article_exclusions (
  owner_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete restrict,
  article_id uuid not null references public.articles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (owner_id, collection_id, article_id)
);

alter table public.collection_article_exclusions enable row level security;
grant select, insert, delete on public.collection_article_exclusions to authenticated;

create policy "owners can read collection article exclusions"
on public.collection_article_exclusions for select to authenticated
using (owner_id = auth.uid());

create policy "owners can insert collection article exclusions"
on public.collection_article_exclusions for insert to authenticated
with check (owner_id = auth.uid());

create policy "owners can delete collection article exclusions"
on public.collection_article_exclusions for delete to authenticated
using (owner_id = auth.uid());

create or replace function public.remove_articles_from_collection(
  p_collection_id uuid,
  p_article_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_is_system boolean;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  p_article_ids := coalesce(p_article_ids, '{}'::uuid[]);
  select is_system into v_is_system
  from public.collections
  where id = p_collection_id;

  if not found then
    raise exception using errcode = '42501', message = 'collection is not available';
  end if;
  if v_is_system then
    raise exception using errcode = '42501', message = 'locked collections cannot be changed';
  end if;
  if exists (
    select 1
    from unnest(p_article_ids) as requested(article_id)
    left join public.article_collections membership
      on membership.collection_id = p_collection_id
      and membership.article_id = requested.article_id
    where membership.article_id is null
  ) then
    raise exception using errcode = '42501', message = 'articles must belong to the collection';
  end if;

  insert into public.collection_article_exclusions (owner_id, collection_id, article_id)
  select v_owner_id, p_collection_id, requested.article_id
  from unnest(p_article_ids) as requested(article_id)
  on conflict do nothing;
end;
$$;

create or replace function public.remove_assets_from_tag(
  p_tag_id uuid,
  p_asset_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_is_system boolean;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;

  p_asset_ids := coalesce(p_asset_ids, '{}'::uuid[]);
  select is_system into v_is_system
  from public.tags
  where id = p_tag_id
    and owner_id = v_owner_id;

  if not found then
    raise exception using errcode = '42501', message = 'tag is not owned by the current user';
  end if;
  if v_is_system then
    raise exception using errcode = '42501', message = 'locked tag relations cannot be removed';
  end if;
  if exists (
    select 1
    from unnest(p_asset_ids) as requested(asset_id)
    left join public.reading_assets asset
      on asset.id = requested.asset_id
      and asset.owner_id = v_owner_id
    left join public.asset_tags relation
      on relation.asset_id = requested.asset_id
      and relation.tag_id = p_tag_id
      and relation.owner_id = v_owner_id
    where asset.id is null or relation.id is null
  ) then
    raise exception using errcode = '42501', message = 'assets must belong to the current user and tag';
  end if;

  delete from public.asset_tags
  where owner_id = v_owner_id
    and tag_id = p_tag_id
    and asset_id = any(p_asset_ids);
end;
$$;

create or replace function public.delete_reading_assets(
  p_asset_ids uuid[]
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

  p_asset_ids := coalesce(p_asset_ids, '{}'::uuid[]);
  if exists (
    select 1
    from unnest(p_asset_ids) as requested(asset_id)
    left join public.reading_assets asset
      on asset.id = requested.asset_id
      and asset.owner_id = v_owner_id
    where asset.id is null
  ) then
    raise exception using errcode = '42501', message = 'reading assets must be owned by the current user';
  end if;

  delete from public.reading_assets
  where owner_id = v_owner_id
    and id = any(p_asset_ids);
end;
$$;

revoke all on function public.remove_articles_from_collection(uuid, uuid[]) from public;
revoke all on function public.remove_assets_from_tag(uuid, uuid[]) from public;
revoke all on function public.delete_reading_assets(uuid[]) from public;
grant execute on function public.remove_articles_from_collection(uuid, uuid[]) to authenticated;
grant execute on function public.remove_assets_from_tag(uuid, uuid[]) to authenticated;
grant execute on function public.delete_reading_assets(uuid[]) to authenticated;
