begin;

select plan(10);

insert into auth.users (id, aud, role, is_anonymous)
values ('66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated', true);

insert into public.tags (id, owner_id, name)
values ('77777777-7777-7777-7777-777777777777', '66666666-6666-6666-6666-666666666666', 'Existing user tag');

set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', true);

select set_config(
  'test.atomic_asset_id',
  public.create_highlight_asset(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    0, 4, 'Atomic highlight', 'sha256:atomic'
  )::text,
  true
);

select throws_ok(
  $$select public.save_reading_asset(
    current_setting('test.atomic_asset_id')::uuid,
    'must not persist',
    array['88888888-8888-8888-8888-888888888888'::uuid]
  )$$,
  '42501',
  'tags must belong to the current user',
  'atomic save rejects a foreign tag'
);
select is(
  (select note_content from public.reading_assets where id = current_setting('test.atomic_asset_id')::uuid),
  null,
  'failed atomic save leaves note content unchanged'
);
select is(
  (select count(*) from public.asset_tags where asset_id = current_setting('test.atomic_asset_id')::uuid),
  1::bigint,
  'failed atomic save leaves tag relations unchanged'
);
select is(
  public.save_reading_asset(
    current_setting('test.atomic_asset_id')::uuid,
    'Persisted together',
    array['77777777-7777-7777-7777-777777777777'::uuid, (
      select id from public.tags where owner_id = auth.uid() and is_system
    )]
  ),
  current_setting('test.atomic_asset_id')::uuid,
  'atomic save returns the existing asset ID'
);
select is(
  (select note_content from public.reading_assets where id = current_setting('test.atomic_asset_id')::uuid),
  'Persisted together',
  'atomic save persists note content'
);
select is(
  (select count(*) from public.asset_tags where asset_id = current_setting('test.atomic_asset_id')::uuid),
  2::bigint,
  'atomic save persists tag changes with the note'
);
select ok(
  public.create_standalone_note_with_tags('Standalone with tag', array['77777777-7777-7777-7777-777777777777'::uuid]) is not null,
  'atomic standalone creation returns an asset ID'
);

select throws_ok(
  $$select public.create_tag(repeat('x', 49))$$,
  '22023',
  'tag name is too long',
  'create_tag rejects names longer than 48 characters'
);
select throws_ok(
  $$select public.create_tag(E'line\nbreak')$$,
  '22023',
  'tag name contains control characters',
  'create_tag rejects control characters'
);
select public.create_tag('Duplicate tag');
select throws_ok(
  $$select public.create_tag('Duplicate tag')$$,
  '23505',
  'tag name already exists',
  'create_tag reports duplicates explicitly'
);

select * from finish();

rollback;
