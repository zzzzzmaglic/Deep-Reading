create table public.article_full_texts (
  article_id uuid primary key references public.articles(id) on delete cascade,
  content text not null check (nullif(btrim(content), '') is not null),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.article_full_texts enable row level security;
grant select on public.article_full_texts to authenticated;
create policy article_full_texts_authenticated_read
on public.article_full_texts for select to authenticated
using (true);

create table public.reading_report_demo_bootstraps (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  version integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reading_report_demo_bootstraps enable row level security;
revoke all on public.reading_report_demo_bootstraps from public, anon, authenticated;

create or replace function public.ensure_reading_report_demo_assets()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_owner_id uuid := auth.uid();
  v_version constant integer := 1;
  v_article_ids constant uuid[] := array[
    '10000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000005'::uuid,
    '10000000-0000-0000-0000-000000000006'::uuid
  ];
  v_article_id uuid;
  v_block_id uuid;
  v_asset_id uuid;
  v_anchor_id uuid;
  v_selected_text text;
  v_checksum text;
  v_note text;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'authentication is required';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is not true then
    raise exception using errcode = '42501', message = 'anonymous demo account is required';
  end if;
  if exists (
    select 1 from public.reading_report_demo_bootstraps
    where owner_id = v_owner_id and version >= v_version
  ) then
    return false;
  end if;

  set constraints all deferred;

  -- Version 1 intentionally replaces every prior demo asset attached to these
  -- four articles, so the first article's historical highlight/note is cleared.
  delete from public.reading_assets asset
  where asset.owner_id = v_owner_id
    and (
      asset.article_id = any(v_article_ids)
      or exists (
        select 1 from public.asset_anchors anchor
        where anchor.asset_id = asset.id
          and anchor.owner_id = v_owner_id
          and anchor.article_id = any(v_article_ids)
      )
    );

  for v_article_id, v_note in
    select * from (values
      (
        '10000000-0000-0000-0000-000000000001'::uuid,
        '工具省下的时间并不会自动还给个人。我想到周报自动化后，自己反而会顺手多接任务。下周我想把省出的半小时提前留给阅读，并记录它最终去了哪里，看看效率的收益究竟由谁决定。'
      ),
      (
        '10000000-0000-0000-0000-000000000004'::uuid,
        '文章让我意识到，学习新领域只收集技巧，像在没有样本时优化模型。以后做产品研究，我想每周保留三个优秀方案和一个失败案例，比较它们的约束与取舍，避免只被符合既有偏好的案例训练。'
      ),
      (
        '10000000-0000-0000-0000-000000000005'::uuid,
        '我过去把休息当作工作后的奖励，越忙越先取消散步。但文章提醒我，休息也可以是创作节奏的一部分。我想同时记录专注工作与散步后出现的想法，看看真正有效的投入是否等于更长的在线时间。'
      ),
      (
        '10000000-0000-0000-0000-000000000006'::uuid,
        '文章让我把情商理解为一条链条：识别情绪，调节反应，再理解别人。面对临时改需求时，我常把焦躁直接归因于对方不专业。下次我想先写下触发点和担忧，再决定如何回应，让情绪从结论变成信息。'
      )
    ) as notes(article_id, note_content)
  loop
    select block.id, left(block.content, 12), article.content_checksum
    into strict v_block_id, v_selected_text, v_checksum
    from public.article_blocks block
    join public.articles article on article.id = block.article_id
    where block.article_id = v_article_id
      and block.content not like '[[image:%'
    order by block.position
    limit 1;

    v_asset_id := gen_random_uuid();
    v_anchor_id := gen_random_uuid();
    insert into public.reading_assets (id, owner_id, anchor_id, article_id, note_content)
    values (v_asset_id, v_owner_id, v_anchor_id, null, v_note);
    insert into public.asset_anchors (
      id, owner_id, asset_id, article_id, start_block_id, end_block_id,
      start_utf16_offset, end_utf16_offset, selected_text, content_checksum
    ) values (
      v_anchor_id, v_owner_id, v_asset_id, v_article_id, v_block_id, v_block_id,
      0, char_length(v_selected_text), v_selected_text, v_checksum
    );
  end loop;

  insert into public.reading_report_demo_bootstraps (owner_id, version)
  values (v_owner_id, v_version)
  on conflict (owner_id) do update
  set version = excluded.version, updated_at = now();
  return true;
end;
$$;

revoke all on function public.ensure_reading_report_demo_assets() from public;
grant execute on function public.ensure_reading_report_demo_assets() to authenticated;
