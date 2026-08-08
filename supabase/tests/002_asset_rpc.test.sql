begin;

select plan(5);

insert into auth.users (id, aud, role, is_anonymous)
values (
  '33333333-3333-3333-3333-333333333333',
  'authenticated',
  'authenticated',
  true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);

select set_config(
  'test.asset_id',
  public.create_highlight_asset(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    0,
    4,
    'Test highlight',
    'sha256:asset-rpc-test'
  )::text,
  true
);

select is(
  (select count(*) from public.reading_assets where id = current_setting('test.asset_id')::uuid),
  1::bigint,
  'create_highlight_asset creates an asset'
);
select is(
  (
    select count(*)
    from public.asset_tags asset_tag
    join public.tags tag on tag.id = asset_tag.tag_id
    where asset_tag.asset_id = current_setting('test.asset_id')::uuid
      and tag.name = U&'\6458\5F55\4E0E\601D\8003'
      and tag.is_system
  ),
  1::bigint,
  'created highlight has the locked tag'
);

select is(
  public.update_reading_asset(
    current_setting('test.asset_id')::uuid,
    'A linked note'
  ),
  current_setting('test.asset_id')::uuid,
  'adding a note preserves the highlight asset ID'
);
select is(
  (
    select note_content
    from public.reading_assets
    where id = current_setting('test.asset_id')::uuid
  ),
  'A linked note',
  'adding a note updates the existing highlight'
);

select public.delete_reading_asset(current_setting('test.asset_id')::uuid);
select is(
  (
    select count(*)
    from public.asset_anchors
    where asset_id = current_setting('test.asset_id')::uuid
  ) + (
    select count(*)
    from public.asset_tags
    where asset_id = current_setting('test.asset_id')::uuid
  ),
  0::bigint,
  'deleting an asset removes its anchor and all tag rows'
);

select * from finish();

rollback;
