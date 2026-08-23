create or replace function public.provision_locked_system_tag_for_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.tags (owner_id, name, is_system)
  values (new.id, '摘录与思考', true)
  on conflict (owner_id, name) do update
  set is_system = true;

  return new;
end;
$$;

revoke all on function public.provision_locked_system_tag_for_user() from public;

drop trigger if exists auth_users_provision_locked_system_tag on auth.users;
create trigger auth_users_provision_locked_system_tag
after insert on auth.users
for each row execute function public.provision_locked_system_tag_for_user();

-- Backfill every account that existed before this invariant was introduced.
insert into public.tags (owner_id, name, is_system)
select auth_user.id, '摘录与思考', true
from auth.users auth_user
on conflict (owner_id, name) do update
set is_system = true;

create or replace function public.attach_locked_system_tag_to_asset()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_locked_tag_id uuid;
begin
  insert into public.tags (owner_id, name, is_system)
  values (new.owner_id, '摘录与思考', true)
  on conflict (owner_id, name) do update
  set is_system = true
  returning id into v_locked_tag_id;

  insert into public.asset_tags (owner_id, asset_id, tag_id)
  values (new.owner_id, new.id, v_locked_tag_id)
  on conflict (asset_id, tag_id) do nothing;

  return new;
end;
$$;

revoke all on function public.attach_locked_system_tag_to_asset() from public;

drop trigger if exists reading_assets_attach_locked_system_tag on public.reading_assets;
create trigger reading_assets_attach_locked_system_tag
after insert on public.reading_assets
for each row execute function public.attach_locked_system_tag_to_asset();

-- Repair both existing users and historical assets idempotently.
insert into public.asset_tags (owner_id, asset_id, tag_id)
select asset.owner_id, asset.id, tag.id
from public.reading_assets asset
join public.tags tag
  on tag.owner_id = asset.owner_id
  and tag.is_system
on conflict (asset_id, tag_id) do nothing;
