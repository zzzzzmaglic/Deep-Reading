create table public.ai_usage_policy (
  singleton boolean primary key default true check (singleton),
  requests_per_hour integer not null check (requests_per_hour > 0),
  daily_token_budget bigint not null check (daily_token_budget > 0),
  weekly_token_budget bigint not null check (weekly_token_budget > 0),
  updated_at timestamptz not null default now()
);

insert into public.ai_usage_policy (
  singleton,
  requests_per_hour,
  daily_token_budget,
  weekly_token_budget
)
values (true, 20, 10000, 20000);

create table public.ai_global_token_windows (
  window_kind text not null check (window_kind in ('day', 'week')),
  window_start timestamptz not null,
  window_end timestamptz not null,
  reserved_tokens bigint not null default 0 check (reserved_tokens >= 0),
  consumed_tokens bigint not null default 0 check (consumed_tokens >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (window_kind, window_start),
  check (window_end > window_start)
);

create table public.ai_anonymous_hour_windows (
  anonymous_user_id uuid not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (anonymous_user_id, window_start),
  check (window_end > window_start)
);

create table public.ai_companion_reservations (
  id uuid primary key default gen_random_uuid(),
  anonymous_user_id uuid not null,
  hour_window_start timestamptz not null,
  day_window_start timestamptz not null,
  week_window_start timestamptz not null,
  estimated_output_tokens integer not null check (estimated_output_tokens > 0),
  actual_output_tokens integer check (actual_output_tokens >= 0),
  charged_output_tokens integer check (charged_output_tokens >= 0),
  outcome text check (outcome in ('completed', 'cancelled', 'upstream_error')),
  reserved_at timestamptz not null default now(),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (settled_at is null and outcome is null and charged_output_tokens is null)
    or (settled_at is not null and outcome is not null and charged_output_tokens is not null)
  ),
  check (actual_output_tokens is null or actual_output_tokens <= estimated_output_tokens),
  check (charged_output_tokens is null or charged_output_tokens <= estimated_output_tokens)
);

create index ai_companion_reservations_created_at_idx
on public.ai_companion_reservations (created_at);

create index ai_companion_reservations_unsettled_idx
on public.ai_companion_reservations (reserved_at)
where settled_at is null;

create index ai_anonymous_hour_windows_created_at_idx
on public.ai_anonymous_hour_windows (created_at);

create index ai_global_token_windows_created_at_idx
on public.ai_global_token_windows (created_at);

alter table public.ai_usage_policy enable row level security;
alter table public.ai_global_token_windows enable row level security;
alter table public.ai_anonymous_hour_windows enable row level security;
alter table public.ai_companion_reservations enable row level security;

create or replace function public.reserve_ai_companion_usage(
  p_estimated_output_tokens integer
)
returns table (
  reservation_id uuid,
  requests_per_hour integer,
  daily_token_budget bigint,
  weekly_token_budget bigint
)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_owner_id uuid := auth.uid();
  v_is_anonymous boolean := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
  v_now timestamptz := statement_timestamp();
  v_hour_start timestamptz := date_trunc('hour', v_now);
  v_day_start timestamptz := date_trunc('day', v_now);
  v_week_start timestamptz := date_trunc('week', v_now);
  v_policy public.ai_usage_policy%rowtype;
  v_week public.ai_global_token_windows%rowtype;
  v_day public.ai_global_token_windows%rowtype;
  v_hour public.ai_anonymous_hour_windows%rowtype;
begin
  if v_owner_id is null or not v_is_anonymous then
    raise exception using errcode = 'PRA01', message = 'anonymous authentication is required';
  end if;
  if p_estimated_output_tokens is null or p_estimated_output_tokens <= 0 then
    raise exception using errcode = '22023', message = 'estimated output tokens must be positive';
  end if;

  select * into strict v_policy
  from public.ai_usage_policy
  where singleton;

  -- Every reservation and settlement acquires global week, global day, then user hour/reservation.
  insert into public.ai_global_token_windows (window_kind, window_start, window_end)
  values ('week', v_week_start, v_week_start + interval '7 days')
  on conflict do nothing;
  select * into strict v_week
  from public.ai_global_token_windows
  where window_kind = 'week' and window_start = v_week_start
  for update;

  insert into public.ai_global_token_windows (window_kind, window_start, window_end)
  values ('day', v_day_start, v_day_start + interval '1 day')
  on conflict do nothing;
  select * into strict v_day
  from public.ai_global_token_windows
  where window_kind = 'day' and window_start = v_day_start
  for update;

  insert into public.ai_anonymous_hour_windows (
    anonymous_user_id,
    window_start,
    window_end
  )
  values (v_owner_id, v_hour_start, v_hour_start + interval '1 hour')
  on conflict do nothing;
  select * into strict v_hour
  from public.ai_anonymous_hour_windows
  where anonymous_user_id = v_owner_id and window_start = v_hour_start
  for update;

  if v_hour.request_count >= v_policy.requests_per_hour then
    raise exception using errcode = 'PRA02', message = 'anonymous hourly request limit exceeded';
  end if;
  if v_day.reserved_tokens + v_day.consumed_tokens + p_estimated_output_tokens
      > v_policy.daily_token_budget then
    raise exception using errcode = 'PRA03', message = 'global daily token budget exceeded';
  end if;
  if v_week.reserved_tokens + v_week.consumed_tokens + p_estimated_output_tokens
      > v_policy.weekly_token_budget then
    raise exception using errcode = 'PRA04', message = 'global weekly token budget exceeded';
  end if;

  update public.ai_global_token_windows
  set reserved_tokens = reserved_tokens + p_estimated_output_tokens,
      updated_at = v_now
  where window_kind = 'week' and window_start = v_week_start;

  update public.ai_global_token_windows
  set reserved_tokens = reserved_tokens + p_estimated_output_tokens,
      updated_at = v_now
  where window_kind = 'day' and window_start = v_day_start;

  update public.ai_anonymous_hour_windows
  set request_count = request_count + 1,
      updated_at = v_now
  where anonymous_user_id = v_owner_id and window_start = v_hour_start;

  insert into public.ai_companion_reservations (
    anonymous_user_id,
    hour_window_start,
    day_window_start,
    week_window_start,
    estimated_output_tokens,
    reserved_at,
    created_at,
    updated_at
  )
  values (
    v_owner_id,
    v_hour_start,
    v_day_start,
    v_week_start,
    p_estimated_output_tokens,
    v_now,
    v_now,
    v_now
  )
  returning id into reservation_id;

  requests_per_hour := v_policy.requests_per_hour;
  daily_token_budget := v_policy.daily_token_budget;
  weekly_token_budget := v_policy.weekly_token_budget;
  return next;
end;
$$;

create or replace function public.settle_ai_companion_usage(
  p_reservation_id uuid,
  p_actual_output_tokens integer,
  p_outcome text
)
returns table (
  settled_reservation_id uuid,
  settled_outcome text,
  charged_tokens integer
)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_owner_id uuid := auth.uid();
  v_is_anonymous boolean := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
  v_now timestamptz := statement_timestamp();
  v_reservation public.ai_companion_reservations%rowtype;
begin
  if v_owner_id is null or not v_is_anonymous then
    raise exception using errcode = 'PRA01', message = 'anonymous authentication is required';
  end if;
  if p_outcome not in ('completed', 'cancelled', 'upstream_error') then
    raise exception using errcode = '22023', message = 'invalid AI settlement outcome';
  end if;
  if p_actual_output_tokens is not null and p_actual_output_tokens < 0 then
    raise exception using errcode = '22023', message = 'actual output tokens must be non-negative';
  end if;

  select * into v_reservation
  from public.ai_companion_reservations
  where id = p_reservation_id and anonymous_user_id = v_owner_id;
  if not found then
    raise exception using errcode = '42501', message = 'AI reservation is not owned by the caller';
  end if;

  perform 1
  from public.ai_global_token_windows
  where window_kind = 'week' and window_start = v_reservation.week_window_start
  for update;
  perform 1
  from public.ai_global_token_windows
  where window_kind = 'day' and window_start = v_reservation.day_window_start
  for update;
  select * into strict v_reservation
  from public.ai_companion_reservations
  where id = p_reservation_id and anonymous_user_id = v_owner_id
  for update;

  if v_reservation.settled_at is not null then
    settled_reservation_id := v_reservation.id;
    settled_outcome := v_reservation.outcome;
    charged_tokens := v_reservation.charged_output_tokens;
    return next;
    return;
  end if;

  if p_actual_output_tokens is not null
      and p_actual_output_tokens > v_reservation.estimated_output_tokens then
    raise exception using
      errcode = '22023',
      message = 'actual output tokens cannot exceed reserved estimate';
  end if;

  charged_tokens := coalesce(p_actual_output_tokens, v_reservation.estimated_output_tokens);

  update public.ai_global_token_windows
  set reserved_tokens = greatest(0, reserved_tokens - v_reservation.estimated_output_tokens),
      consumed_tokens = consumed_tokens + charged_tokens,
      updated_at = v_now
  where window_kind = 'week' and window_start = v_reservation.week_window_start;

  update public.ai_global_token_windows
  set reserved_tokens = greatest(0, reserved_tokens - v_reservation.estimated_output_tokens),
      consumed_tokens = consumed_tokens + charged_tokens,
      updated_at = v_now
  where window_kind = 'day' and window_start = v_reservation.day_window_start;

  update public.ai_companion_reservations
  set actual_output_tokens = p_actual_output_tokens,
      charged_output_tokens = charged_tokens,
      outcome = p_outcome,
      settled_at = v_now,
      updated_at = v_now
  where id = v_reservation.id;

  settled_reservation_id := v_reservation.id;
  settled_outcome := p_outcome;
  return next;
end;
$$;

create or replace function public.cleanup_ai_companion_usage(
  p_now timestamptz default now()
)
returns table (
  reservations_reconciled bigint,
  reservations_deleted bigint,
  hour_windows_deleted bigint,
  global_windows_deleted bigint
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_reservation public.ai_companion_reservations%rowtype;
begin
  reservations_reconciled := 0;

  -- Cleanup takes the same global-week, global-day, reservation lock order as settlement.
  perform 1
  from public.ai_global_token_windows
  where window_kind = 'week'
  order by window_start
  for update;

  perform 1
  from public.ai_global_token_windows
  where window_kind = 'day'
  order by window_start
  for update;

  for v_reservation in
    select reservation.*
    from public.ai_companion_reservations as reservation
    where reservation.settled_at is null
      and reservation.reserved_at < p_now - interval '1 day'
    order by
      reservation.week_window_start,
      reservation.day_window_start,
      reservation.id
    for update skip locked
  loop
    update public.ai_global_token_windows
    set reserved_tokens = greatest(
          0,
          reserved_tokens - v_reservation.estimated_output_tokens
        ),
        consumed_tokens = consumed_tokens + v_reservation.estimated_output_tokens,
        updated_at = p_now
    where window_kind = 'week'
      and window_start = v_reservation.week_window_start;

    update public.ai_global_token_windows
    set reserved_tokens = greatest(
          0,
          reserved_tokens - v_reservation.estimated_output_tokens
        ),
        consumed_tokens = consumed_tokens + v_reservation.estimated_output_tokens,
        updated_at = p_now
    where window_kind = 'day'
      and window_start = v_reservation.day_window_start;

    update public.ai_companion_reservations
    set charged_output_tokens = estimated_output_tokens,
        outcome = 'upstream_error',
        settled_at = p_now,
        updated_at = p_now
    where id = v_reservation.id;

    reservations_reconciled := reservations_reconciled + 1;
  end loop;

  delete from public.ai_companion_reservations
  where created_at < p_now - interval '30 days';
  get diagnostics reservations_deleted = row_count;

  delete from public.ai_anonymous_hour_windows
  where created_at < p_now - interval '30 days';
  get diagnostics hour_windows_deleted = row_count;

  delete from public.ai_global_token_windows
  where created_at < p_now - interval '30 days';
  get diagnostics global_windows_deleted = row_count;

  return next;
end;
$$;

revoke all on table public.ai_usage_policy from public, anon, authenticated;
revoke all on table public.ai_global_token_windows from public, anon, authenticated;
revoke all on table public.ai_anonymous_hour_windows from public, anon, authenticated;
revoke all on table public.ai_companion_reservations from public, anon, authenticated;

revoke all on function public.reserve_ai_companion_usage(integer) from public;
revoke all on function public.settle_ai_companion_usage(uuid, integer, text) from public;
revoke all on function public.cleanup_ai_companion_usage(timestamptz) from public;

grant execute on function public.reserve_ai_companion_usage(integer) to authenticated;
grant execute on function public.settle_ai_companion_usage(uuid, integer, text) to authenticated;
grant execute on function public.cleanup_ai_companion_usage(timestamptz) to service_role;

create extension if not exists pg_cron with schema extensions;

select cron.schedule(
  'ai-companion-usage-cleanup-daily',
  '17 3 * * *',
  $$select public.cleanup_ai_companion_usage();$$
)
where not exists (
  select 1 from cron.job where jobname = 'ai-companion-usage-cleanup-daily'
);
