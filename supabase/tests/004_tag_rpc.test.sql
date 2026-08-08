begin;

select plan(8);

insert into auth.users (id, aud, role, is_anonymous)
values ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-3333-3333-333333333333',
  true
);

select set_config(
  'test.tag_id',
  public.create_tag('New user tag')::text,
  true
);

select is(
  (select owner_id from public.tags where id = current_setting('test.tag_id')::uuid),
  '33333333-3333-3333-3333-333333333333'::uuid,
  'create_tag assigns the authenticated owner'
);
select is(
  (select name from public.tags where id = current_setting('test.tag_id')::uuid),
  'New user tag',
  'create_tag stores the trimmed requested name'
);
select is(
  (select is_system from public.tags where id = current_setting('test.tag_id')::uuid),
  false,
  'create_tag only creates ordinary user tags'
);
select throws_ok(
  $$select public.create_tag('   ')$$,
  '22023',
  'tag name is required',
  'create_tag rejects blank names'
);
select throws_ok(
  $$select public.create_tag(U&'\6458\5F55\4E0E\601D\8003')$$,
  '22023',
  'system tags cannot be created',
  'create_tag cannot create the locked system tag'
);

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.create_tag('Unauthenticated')$$,
  '28000',
  'authentication is required',
  'create_tag requires auth.uid'
);

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-3333-3333-333333333333',
  true
);
select throws_ok(
  $$insert into public.tags (owner_id, name) values ('33333333-3333-3333-3333-333333333333', 'Direct write')$$,
  '42501',
  null,
  'direct tag writes remain denied by RLS'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_tag(text)',
    'EXECUTE'
  ),
  true,
  'authenticated users can execute create_tag'
);

select * from finish();

rollback;
