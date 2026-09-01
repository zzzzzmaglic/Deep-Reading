begin;

select plan(7);

insert into auth.users (id, aud, role, is_anonymous)
values ('88888888-8888-8888-8888-888888888888', 'authenticated', 'authenticated', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888888', true);

select set_config(
  'test.reader_note_id',
  public.create_standalone_note_with_tags(
    'Reader note',
    '10000000-0000-0000-0000-000000000001',
    '{}'::uuid[]
  )::text,
  true
);
select is(
  (select article_id from public.reading_assets where id = current_setting('test.reader_note_id')::uuid),
  '10000000-0000-0000-0000-000000000001'::uuid,
  'reader standalone notes persist their article association'
);

select set_config(
  'test.global_note_id',
  public.create_standalone_note_with_tags('Global note', null, '{}'::uuid[])::text,
  true
);
select is(
  (select article_id from public.reading_assets where id = current_setting('test.global_note_id')::uuid),
  null::uuid,
  'non-article standalone notes preserve a null article association'
);

select set_config(
  'test.other_note_id',
  public.create_standalone_note_with_tags(
    'Other article note',
    '10000000-0000-0000-0000-000000000004',
    '{}'::uuid[]
  )::text,
  true
);
select is(
  (select count(*) from public.reading_assets where article_id = '10000000-0000-0000-0000-000000000001'),
  1::bigint,
  'article association is scoped to the requested article'
);
select is(
  (select count(*) from public.reading_assets where article_id is null),
  1::bigint,
  'global notes are not assigned to an article'
);
select is(
  (select count(*) from public.reading_assets asset where asset.article_id = '10000000-0000-0000-0000-000000000001'
    or exists (
      select 1 from public.asset_anchors anchor
      where anchor.asset_id = asset.id
        and anchor.article_id = '10000000-0000-0000-0000-000000000001'
    )),
  1::bigint,
  'current article scope excludes global and other-article standalone notes'
);
select is(
  (select count(*) from public.reading_assets asset where asset.article_id = '10000000-0000-0000-0000-000000000004'),
  1::bigint,
  'other article standalone notes remain assigned to their own article'
);
select is(
  (select count(*) from public.reading_assets where id = current_setting('test.reader_note_id')::uuid and owner_id = auth.uid()),
  1::bigint,
  'article-associated notes remain owner scoped'
);

select * from finish();
rollback;
