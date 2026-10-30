-- pgTAP tests for the feed's Global filter (feed_page scope 'global').
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(3);

create function pg_temp.act_as(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
end;
$$;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.ph', '{"full_name": "Ana Far"}'),
  ('00000000-0000-0000-0000-0000000000b2', 'b2@test.ph', '{"full_name": "Ben Viewer"}');

-- Ana's loops: public in Isabela, public in Davao (far away), club, private.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
insert into clubs (id, name) values ('12000000-0000-0000-0000-000000000001', 'Far Riders');
insert into loops (id, name, source, route, distance_m, duration_s, visibility, club_id)
values
  ('22000000-0000-0000-0000-000000000001', 'Isabela public', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.50 16.72,121.55 16.67,121.45 16.67)',
   30000, 3000, 'public', null),
  ('22000000-0000-0000-0000-000000000002', 'Davao public', 'custom',
   'SRID=4326;LINESTRING(125.60 7.07,125.65 7.12,125.70 7.07,125.60 7.07)',
   30000, 3000, 'public', null),
  ('22000000-0000-0000-0000-000000000003', 'Club only', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.50 16.62,121.55 16.67,121.45 16.67)',
   30000, 3000, 'club', '12000000-0000-0000-0000-000000000001'),
  ('22000000-0000-0000-0000-000000000004', 'Secret', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.40 16.62,121.35 16.67,121.45 16.67)',
   30000, 3000, 'private', null);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b2');
select set_eq(
  $$select id from feed_page('global') where id in (
      '22000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000002',
      '22000000-0000-0000-0000-000000000003', '22000000-0000-0000-0000-000000000004')$$,
  $$values ('22000000-0000-0000-0000-000000000001'::uuid), ('22000000-0000-0000-0000-000000000002'::uuid)$$,
  'Global: public loops from anywhere, never club or private ones'
);
select ok(
  (select distance_away_m > 900000 from feed_page('global', null, 16.67, 121.45)
   where id = '22000000-0000-0000-0000-000000000002'),
  'Global still says how far away a ride is'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select is_empty(
  $$select id from feed_page('global') where id = '22000000-0000-0000-0000-000000000003'$$,
  'club loops stay out of Global, even for club members'
);

select * from finish();
rollback;
