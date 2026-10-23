begin;
select plan(9);

insert into auth.users (id, aud, role, is_anonymous)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated","is_anonymous":true}',
  true
);

select is(public.ensure_reading_report_demo_assets(), true, 'first bootstrap creates report demo assets');
select is(public.ensure_reading_report_demo_assets(), false, 'second bootstrap is idempotent');

select is(
  (select count(*)::integer from public.article_full_texts),
  4,
  'all four demo articles have server-side full text'
);
select ok(
  not exists (
    select 1 from public.article_full_texts
    where char_length(content) < 5000
  ),
  'every demo full text contains a substantial original article body'
);

select is(
  (select count(*)::integer from public.reading_assets where owner_id = auth.uid()),
  4,
  'exactly four reading assets exist'
);
select is(
  (select count(*)::integer from public.asset_anchors where owner_id = auth.uid()),
  4,
  'all four demo assets are linked notes'
);
select is(
  (select count(distinct anchor.article_id)::integer from public.asset_anchors anchor where anchor.owner_id = auth.uid()),
  4,
  'each demo article has one linked note'
);
select ok(
  not exists (
    select 1 from public.reading_assets
    where owner_id = auth.uid()
      and (nullif(btrim(note_content), '') is null or char_length(note_content) > 100)
  ),
  'every shortened demo note is non-empty and no longer than 100 characters'
);
select is(
  (
    select count(*)::integer
    from public.asset_tags relation
    join public.tags tag on tag.id = relation.tag_id and tag.owner_id = relation.owner_id
    where relation.owner_id = auth.uid() and tag.name = '摘录与思考' and tag.is_system
  ),
  4,
  'the locked system tag is attached to all demo notes'
);

select * from finish();
rollback;
