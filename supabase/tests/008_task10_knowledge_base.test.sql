begin;

select plan(11);

insert into auth.users (id, aud, role, is_anonymous)
values
  ('81111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', true),
  ('82222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', true);

insert into public.collections (id, name, description)
values ('83333333-3333-3333-3333-333333333333', 'Owner one collection', 'A removable collection');

insert into public.article_collections (id, article_id, collection_id, position)
values (
  '84444444-4444-4444-4444-444444444444',
  '10000000-0000-0000-0000-000000000001',
  '83333333-3333-3333-3333-333333333333',
  1
);

insert into public.tags (id, owner_id, name)
values (
  '85555555-5555-5555-5555-555555555555',
  '81111111-1111-1111-1111-111111111111',
  'Ordinary tag'
), (
  '86666666-6666-6666-6666-666666666666',
  '81111111-1111-1111-1111-111111111111',
  'Other ordinary tag'
);

insert into public.reading_assets (id, owner_id, note_content)
values (
  '87777777-7777-7777-7777-777777777777',
  '81111111-1111-1111-1111-111111111111',
  'Owner one asset'
), (
  '88888888-8888-8888-8888-888888888888',
  '82222222-2222-2222-2222-222222222222',
  'Owner two asset'
);

insert into public.asset_tags (owner_id, asset_id, tag_id)
values (
  '81111111-1111-1111-1111-111111111111',
  '87777777-7777-7777-7777-777777777777',
  '85555555-5555-5555-5555-555555555555'
), (
  '81111111-1111-1111-1111-111111111111',
  '87777777-7777-7777-7777-777777777777',
  '86666666-6666-6666-6666-666666666666'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81111111-1111-1111-1111-111111111111', true);
select set_config('test.owner_one', '81111111-1111-1111-1111-111111111111', true);
select set_config('test.normal_collection_id', '83333333-3333-3333-3333-333333333333', true);
select set_config('test.article_id', '10000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$select public.remove_articles_from_collection(
      '30000000-0000-0000-0000-000000000001'::uuid,
      array['10000000-0000-0000-0000-000000000001'::uuid]
  )$$,
  '42501',
  'locked collections cannot be changed'
);
select throws_ok(
  $$insert into public.collection_article_exclusions (owner_id, collection_id, article_id)
    values (
      current_setting('test.owner_one')::uuid,
      '30000000-0000-0000-0000-000000000001'::uuid,
      '10000000-0000-0000-0000-000000000001'::uuid
    )$$,
  '42501',
  null,
  'authenticated clients cannot directly hide articles in locked collections'
);
select is(
  (select count(*) from public.collection_article_exclusions
    where owner_id = current_setting('test.owner_one')::uuid
      and collection_id = '30000000-0000-0000-0000-000000000001'::uuid
      and article_id = '10000000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  'locked collection articles cannot become hidden through direct table writes'
);

select lives_ok(
  $$select public.remove_articles_from_collection(
      current_setting('test.normal_collection_id')::uuid,
      array[current_setting('test.article_id')::uuid]
  )$$,
  'normal collection removal records an owner-scoped exclusion'
);
select is(
  (select count(*) from public.collection_article_exclusions
    where owner_id = current_setting('test.owner_one')::uuid),
  1::bigint,
  'only the current owner receives the exclusion'
);
select throws_ok(
  $$delete from public.collection_article_exclusions
    where owner_id = current_setting('test.owner_one')::uuid
      and collection_id = current_setting('test.normal_collection_id')::uuid
      and article_id = current_setting('test.article_id')::uuid$$,
  '42501',
  null,
  'authenticated clients cannot directly delete collection exclusions'
);

select lives_ok(
  $$select public.remove_assets_from_tag(
      '85555555-5555-5555-5555-555555555555'::uuid,
      array['87777777-7777-7777-7777-777777777777'::uuid]
  )$$,
  'ordinary tag removal succeeds'
);
select is(
  (select count(*) from public.asset_tags
    where asset_id = '87777777-7777-7777-7777-777777777777'::uuid
      and tag_id = '85555555-5555-5555-5555-555555555555'::uuid),
  0::bigint,
  'ordinary tag removal deletes only the requested tag relation'
);
select is(
  (select count(*) from public.asset_tags
    where asset_id = '87777777-7777-7777-7777-777777777777'::uuid
      and tag_id = '86666666-6666-6666-6666-666666666666'::uuid),
  1::bigint,
  'ordinary tag removal preserves other tag relations'
);

select throws_ok(
  $$select public.delete_reading_assets(array[
      '87777777-7777-7777-7777-777777777777'::uuid,
      '88888888-8888-8888-8888-888888888888'::uuid
  ])$$,
  '42501',
  'reading assets must be owned by the current user'
);
select is(
  (select count(*) from public.reading_assets
    where id = '87777777-7777-7777-7777-777777777777'::uuid),
  1::bigint,
  'atomic batch delete leaves a valid asset intact when any requested asset is foreign'
);

select * from finish();

rollback;
