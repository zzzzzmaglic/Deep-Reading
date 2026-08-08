begin;

select plan(16);

insert into auth.users (id, aud, role, is_anonymous)
values (
  '33333333-3333-3333-3333-333333333333',
  'authenticated',
  'authenticated',
  true
), (
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  'authenticated',
  true
);

insert into public.tags (id, owner_id, name)
values (
  '55555555-5555-5555-5555-555555555555',
  '44444444-4444-4444-4444-444444444444',
  'Other owner tag'
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

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.create_standalone_note('Unauthenticated note')$$,
  '28000',
  'authentication is required',
  'RPCs reject a null authenticated identity'
);

select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select set_config(
  'test.owner_one_asset_id',
  public.create_highlight_asset(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    0,
    4,
    'Owner one highlight',
    'sha256:owner-one'
  )::text,
  true
);

select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
select throws_ok(
  $$select public.update_reading_asset(current_setting('test.owner_one_asset_id')::uuid, 'Unauthorized update')$$,
  '42501',
  'reading asset is not owned by the current user',
  'owners cannot update another owner asset'
);
select throws_ok(
  $$select public.delete_reading_asset(current_setting('test.owner_one_asset_id')::uuid)$$,
  '42501',
  'reading asset is not owned by the current user',
  'owners cannot delete another owner asset'
);
select throws_ok(
  $$select public.set_asset_tags(current_setting('test.owner_one_asset_id')::uuid, '{}'::uuid[])$$,
  '42501',
  'reading asset is not owned by the current user',
  'owners cannot set tags on another owner asset'
);

select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select throws_ok(
  $$select public.set_asset_tags(current_setting('test.owner_one_asset_id')::uuid, array['55555555-5555-5555-5555-555555555555'::uuid])$$,
  '42501',
  'tags must belong to the current user',
  'asset tags reject a foreign-owner tag injection'
);
select throws_ok(
  $$select public.set_asset_tags(current_setting('test.owner_one_asset_id')::uuid, '{}'::uuid[])$$,
  '22023',
  'locked tag relations cannot be removed',
  'locked tag relations cannot be removed'
);

select set_config(
  'test.owner_one_progress_id',
  public.upsert_reading_progress(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    4
  )::text,
  true
);
select is(
  public.upsert_reading_progress(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    9
  ),
  current_setting('test.owner_one_progress_id')::uuid,
  'progress upsert preserves the existing row ID'
);
select is(
  (
    select utf16_offset
    from public.reading_progress
    where id = current_setting('test.owner_one_progress_id')::uuid
  ),
  9,
  'progress upsert updates the stored offset'
);

select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
select is(
  (
    select count(*)
    from public.reading_progress
    where article_id = '10000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'other owners cannot read another owner progress'
);
select set_config(
  'test.owner_two_progress_id',
  public.upsert_reading_progress(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    3
  )::text,
  true
);
select isnt(
  current_setting('test.owner_two_progress_id')::uuid,
  current_setting('test.owner_one_progress_id')::uuid,
  'each owner has an independent progress row'
);
select throws_ok(
  $$select public.upsert_reading_progress('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', 0)$$,
  '23503',
  'progress block must belong to the article',
  'progress rejects a block from another article'
);

select * from finish();

rollback;
