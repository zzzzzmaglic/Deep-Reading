begin;

select plan(15);

insert into auth.users (id, aud, role, is_anonymous)
values (
  '11111111-1111-1111-1111-111111111111',
  'authenticated',
  'authenticated',
  true
), (
  '22222222-2222-2222-2222-222222222222',
  'authenticated',
  'authenticated',
  true
);

insert into public.reading_assets (id, owner_id, anchor_id, note_content)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    null
  ),
  (
    'abababab-abab-abab-abab-abababababab',
    '11111111-1111-1111-1111-111111111111',
    null,
    'RLS fixture note'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    null
  );

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
values
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    0,
    4,
    '真正留下',
    'sha256:fixture-owner-one'
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '22222222-2222-2222-2222-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    0,
    4,
    '真正留下',
    'sha256:fixture-owner-two'
  );

insert into public.reading_progress (owner_id, article_id, block_id, utf16_offset)
values (
  '11111111-1111-1111-1111-111111111111',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  4
);

insert into public.tags (id, owner_id, name)
values
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '11111111-1111-1111-1111-111111111111',
    'Fixture tag one'
  ),
  (
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    '22222222-2222-2222-2222-222222222222',
    'Fixture tag two'
  );

insert into public.asset_tags (owner_id, asset_id, tag_id)
values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
);

set constraints all immediate;

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is((select count(*) from public.reading_assets), 2::bigint, 'owner sees its assets');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is((select count(*) from public.reading_assets), 1::bigint, 'other owner cannot see another owner assets');
select is((select count(*) from public.reading_progress), 0::bigint, 'other owner cannot see reading progress');
select is((select count(*) from public.asset_anchors), 1::bigint, 'other owner cannot see anchors');
select is((select count(*) from public.tags), 2::bigint, 'other owner sees only its own fixed and fixture tags');
select is((select count(*) from public.asset_tags), 1::bigint, 'other owner sees only its own fixed asset tag');

reset role;
select throws_ok(
  $$insert into public.reading_assets (id, owner_id, anchor_id) values ('12121212-1212-1212-1212-121212121212', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd')$$,
  '23503',
  'insert or update on table "reading_assets" violates foreign key constraint "reading_assets_anchor_id_owner_id_fkey"',
  'cross-owner asset anchor is rejected'
);
select throws_ok(
  $$insert into public.asset_tags (owner_id, asset_id, tag_id) values ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ffffffff-ffff-ffff-ffff-ffffffffffff')$$,
  '23503',
  'insert or update on table "asset_tags" violates foreign key constraint "asset_tags_tag_id_owner_id_fkey"',
  'cross-owner asset tag is rejected'
);
select throws_ok(
  $$insert into public.asset_anchors (id, owner_id, asset_id, article_id, start_block_id, end_block_id, start_utf16_offset, end_utf16_offset, selected_text, content_checksum) values ('99999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 5, 8, '的阅读', 'sha256:duplicate-anchor')$$,
  '23505',
  'duplicate key value violates unique constraint "asset_anchors_asset_id_key"',
  'a reading asset cannot have a second anchor'
);
delete from public.reading_assets where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
select is((select count(*) from public.asset_anchors where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'), 0::bigint, 'deleting an asset removes its anchor');
select is((select count(*) from public.asset_tags where asset_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), 0::bigint, 'deleting an asset removes its tags');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$insert into public.reading_assets (owner_id, note_content) values ('11111111-1111-1111-1111-111111111111', 'blocked direct insert')$$,
  '42501',
  'permission denied for table reading_assets',
  'authenticated users cannot directly insert private data'
);
select is((select count(*) from public.collections where name = '往期推文'), 1::bigint, 'authenticated users can read the canonical seed collection');
select throws_ok(
  $$update public.articles set title = 'blocked update' where id = '10000000-0000-0000-0000-000000000001'$$,
  '42501',
  'permission denied for table articles',
  'authenticated users cannot modify seed content'
);

reset role;
delete from auth.users where id = '22222222-2222-2222-2222-222222222222';
select is((
  select count(*)
  from (
    select owner_id from public.reading_assets
    union all
    select owner_id from public.asset_anchors
    union all
    select owner_id from public.tags
  ) private_rows
  where owner_id = '22222222-2222-2222-2222-222222222222'
), 0::bigint, 'deleting an auth user removes their private data');
select * from finish();

rollback;
