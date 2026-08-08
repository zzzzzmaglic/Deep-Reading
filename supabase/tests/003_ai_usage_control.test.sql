begin;

select plan(13);

insert into auth.users (id, aud, role, is_anonymous)
values
  ('66666666-6666-4666-8666-666666666666', 'authenticated', 'authenticated', true),
  ('77777777-7777-4777-8777-777777777777', 'authenticated', 'authenticated', true),
  ('88888888-8888-4888-8888-888888888888', 'authenticated', 'authenticated', false);

set local role authenticated;
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated","is_anonymous":false}',
  true
);
select throws_ok(
  $$select * from public.reserve_ai_companion_usage(100)$$,
  'PRA01',
  'anonymous authentication is required',
  'usage reservation rejects a non-anonymous identity'
);

reset role;
update public.ai_usage_policy
set requests_per_hour = 2,
    daily_token_budget = 10000,
    weekly_token_budget = 20000
where singleton;
set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","is_anonymous":true}',
  true
);
select lives_ok(
  $$select * from public.reserve_ai_companion_usage(100)$$,
  'first hourly reservation succeeds'
);
select lives_ok(
  $$select * from public.reserve_ai_companion_usage(100)$$,
  'second hourly reservation succeeds'
);
select throws_ok(
  $$select * from public.reserve_ai_companion_usage(100)$$,
  'PRA02',
  'anonymous hourly request limit exceeded',
  'the next request in the anonymous-user hour is rejected'
);

reset role;
truncate public.ai_companion_reservations,
  public.ai_anonymous_hour_windows,
  public.ai_global_token_windows;
update public.ai_usage_policy
set requests_per_hour = 20,
    daily_token_budget = 10000,
    weekly_token_budget = 20000
where singleton;
set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","is_anonymous":true}',
  true
);
select set_config(
  'test.partial_reservation_id',
  (select reservation_id::text from public.reserve_ai_companion_usage(100)),
  true
);
select lives_ok(
  $$select * from public.settle_ai_companion_usage(
    current_setting('test.partial_reservation_id')::uuid,
    40,
    'completed'
  )$$,
  'known partial usage settles successfully'
);

reset role;
select is(
  (
    select reserved_tokens
    from public.ai_global_token_windows
    where window_kind = 'day'
  ),
  0::bigint,
  'known settlement releases all reserved daily tokens'
);
select is(
  (
    select consumed_tokens
    from public.ai_global_token_windows
    where window_kind = 'day'
  ),
  40::bigint,
  'known settlement charges only actual daily tokens'
);
select is(
  (
    select actual_output_tokens
    from public.ai_companion_reservations
    where id = current_setting('test.partial_reservation_id')::uuid
  ),
  40,
  'known settlement records actual token usage'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","is_anonymous":true}',
  true
);
select set_config(
  'test.unknown_reservation_id',
  (select reservation_id::text from public.reserve_ai_companion_usage(100)),
  true
);
select * from public.settle_ai_companion_usage(
  current_setting('test.unknown_reservation_id')::uuid,
  null,
  'upstream_error'
);
reset role;
select is(
  (
    select charged_output_tokens
    from public.ai_companion_reservations
    where id = current_setting('test.unknown_reservation_id')::uuid
  ),
  100,
  'unknown usage settles conservatively at the reserved maximum'
);

truncate public.ai_companion_reservations,
  public.ai_anonymous_hour_windows,
  public.ai_global_token_windows;
update public.ai_usage_policy
set requests_per_hour = 20,
    daily_token_budget = 100,
    weekly_token_budget = 1000
where singleton;
set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","is_anonymous":true}',
  true
);
select * from public.reserve_ai_companion_usage(100);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated","is_anonymous":true}',
  true
);
select throws_ok(
  $$select * from public.reserve_ai_companion_usage(1)$$,
  'PRA03',
  'global daily token budget exceeded',
  'daily budget exhaustion rejects a different anonymous user'
);

reset role;
truncate public.ai_companion_reservations,
  public.ai_anonymous_hour_windows,
  public.ai_global_token_windows;
update public.ai_usage_policy
set requests_per_hour = 20,
    daily_token_budget = 1000,
    weekly_token_budget = 100
where singleton;
set local role authenticated;
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","is_anonymous":true}',
  true
);
select * from public.reserve_ai_companion_usage(100);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated","is_anonymous":true}',
  true
);
select throws_ok(
  $$select * from public.reserve_ai_companion_usage(1)$$,
  'PRA04',
  'global weekly token budget exceeded',
  'weekly budget exhaustion rejects a different anonymous user'
);

reset role;
truncate public.ai_companion_reservations,
  public.ai_anonymous_hour_windows,
  public.ai_global_token_windows;
insert into public.ai_anonymous_hour_windows (
  anonymous_user_id,
  window_start,
  window_end,
  request_count,
  created_at,
  updated_at
)
values
  (
    '66666666-6666-4666-8666-666666666666',
    '2026-06-01 00:00:00+00',
    '2026-06-01 01:00:00+00',
    1,
    '2026-06-01 00:00:00+00',
    '2026-06-01 00:00:00+00'
  ),
  (
    '77777777-7777-4777-8777-777777777777',
    '2026-07-25 00:00:00+00',
    '2026-07-25 01:00:00+00',
    1,
    '2026-07-25 00:00:00+00',
    '2026-07-25 00:00:00+00'
  );
select * from public.cleanup_ai_companion_usage('2026-08-08 00:00:00+00');
select is(
  (
    select count(*)
    from public.ai_anonymous_hour_windows
    where created_at < '2026-07-09 00:00:00+00'
  ),
  0::bigint,
  'cleanup removes use-control rows older than 30 days'
);
select is(
  (
    select count(*)
    from public.ai_anonymous_hour_windows
    where anonymous_user_id = '77777777-7777-4777-8777-777777777777'
  ),
  1::bigint,
  'cleanup preserves use-control rows within 30 days'
);

select * from finish();

rollback;
