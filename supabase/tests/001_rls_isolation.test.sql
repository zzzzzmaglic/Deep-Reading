begin;

select plan(2);

insert into public.reading_assets (id, owner_id, note_content)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'RLS fixture asset'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is((select count(*) from public.reading_assets), 1::bigint, 'owner sees its asset');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is((select count(*) from public.reading_assets), 0::bigint, 'other owner cannot see the asset');

reset role;
select * from finish();

rollback;
