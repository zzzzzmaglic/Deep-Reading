begin;

select plan(4);

insert into auth.users (id, aud, role, is_anonymous)
values ('99999999-9999-9999-9999-999999999999', 'authenticated', 'authenticated', true);

select is(
  (
    select count(*)
    from public.tags
    where owner_id = '99999999-9999-9999-9999-999999999999'
      and name = '摘录与思考'
      and is_system
  ),
  1::bigint,
  'every new auth user immediately owns the locked system tag'
);

insert into public.reading_assets (id, owner_id, note_content)
values (
  '99999999-9999-9999-9999-999999999901',
  '99999999-9999-9999-9999-999999999999',
  'directly inserted asset'
);

select is(
  (
    select count(*)
    from public.asset_tags asset_tag
    join public.tags tag on tag.id = asset_tag.tag_id
    where asset_tag.asset_id = '99999999-9999-9999-9999-999999999901'
      and tag.owner_id = '99999999-9999-9999-9999-999999999999'
      and tag.is_system
  ),
  1::bigint,
  'every new reading asset is automatically linked to the locked system tag'
);

delete from public.tags
where owner_id = '99999999-9999-9999-9999-999999999999'
  and is_system;

insert into public.reading_assets (id, owner_id, note_content)
values (
  '99999999-9999-9999-9999-999999999902',
  '99999999-9999-9999-9999-999999999999',
  'asset repairs missing system tag'
);

select is(
  (
    select count(*)
    from public.tags
    where owner_id = '99999999-9999-9999-9999-999999999999'
      and name = '摘录与思考'
      and is_system
  ),
  1::bigint,
  'asset creation repairs a missing locked system tag'
);

select is(
  (
    select count(*)
    from public.asset_tags asset_tag
    join public.tags tag on tag.id = asset_tag.tag_id
    where asset_tag.asset_id = '99999999-9999-9999-9999-999999999902'
      and tag.is_system
  ),
  1::bigint,
  'the repaired system tag is linked to the new asset'
);

select * from finish();

rollback;
