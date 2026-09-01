begin;

select plan(6);

select is(
  (
    select count(*)
    from public.articles
    where id in (
      '10000000-0000-0000-0000-000000000001'::uuid,
      '10000000-0000-0000-0000-000000000004'::uuid,
      '10000000-0000-0000-0000-000000000005'::uuid,
      '10000000-0000-0000-0000-000000000006'::uuid
    )
  ),
  4::bigint,
  'demo keeps the original article and adds the three replacement articles'
);

select is(
  (
    select array_agg(article.title order by membership.position)
    from public.article_collections as membership
    join public.articles as article on article.id = membership.article_id
    where membership.collection_id = '30000000-0000-0000-0000-000000000001'::uuid
  ),
  array[
    '1600-2100年的公司简史',
    '为你的大脑收集训练数据',
    '达尔文是个“懒虫”，你也应该如此',
    '当我们在聊情商时，到底在聊什么？'
  ]::text[],
  'the published collection exposes the four demo articles in order'
);

select is(
  (
    select array_agg(article.cover_asset_name order by membership.position)
    from public.article_collections as membership
    join public.articles as article on article.id = membership.article_id
    where membership.collection_id = '30000000-0000-0000-0000-000000000001'::uuid
  ),
  array['KnowledgeCover1', 'KnowledgeCover2', 'KnowledgeCover3', 'KnowledgeCover4']::text[],
  'the four collection cards map to their intended cover assets'
);

select is(
  (
    select count(*)
    from public.articles
    where id in (
      '10000000-0000-0000-0000-000000000002'::uuid,
      '10000000-0000-0000-0000-000000000003'::uuid
    )
  ),
  0::bigint,
  'the two superseded demo articles are removed'
);

select is(
  (
    select count(distinct article_id)
    from public.article_blocks
    where article_id in (
      '10000000-0000-0000-0000-000000000004'::uuid,
      '10000000-0000-0000-0000-000000000005'::uuid,
      '10000000-0000-0000-0000-000000000006'::uuid
    )
  ),
  3::bigint,
  'each imported article has reader content'
);

select ok(
  not exists (
    select 1
    from public.article_blocks
    where article_id in (
      '10000000-0000-0000-0000-000000000004'::uuid,
      '10000000-0000-0000-0000-000000000005'::uuid,
      '10000000-0000-0000-0000-000000000006'::uuid
    )
      and content ~ '[一-龥][[:space:]]+[一-龥]'
  ),
  'imported Chinese paragraphs do not retain formatting spaces inside Chinese text'
);

select * from finish();

rollback;
