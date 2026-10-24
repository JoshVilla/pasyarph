-- pgTAP tests for share links: link_preview() and feed_page('post')
-- (Prompt 18). Run with `npx supabase test db`. Everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

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

create function pg_temp.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end;
$$;

create function pg_temp.act_as_postgres() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- A owns everything and the club, B is in A's club, C is a stranger.
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.ph', '{"full_name": "Ana Sharer"}'),
  ('00000000-0000-0000-0000-0000000000b2', 'b2@test.ph', '{"full_name": "Ben Member"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.ph', '{"full_name": "Cara Stranger"}');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
insert into clubs (id, name) values ('12000000-0000-0000-0000-000000000001', 'Rizal Riders');

-- Long enough (~22 km) that the home privacy trim leaves a shared_route.
insert into loops (id, name, source, route, distance_m, duration_s, main_stop, visibility, club_id)
values
  ('22000000-0000-0000-0000-000000000001', 'Tanay Sunrise', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.40 14.50,121.30 14.50)',
   82000, 9000, '{"name": "Daranak Falls", "lat": 14.55, "lng": 121.35}', 'public', null),
  ('22000000-0000-0000-0000-000000000002', 'Club only', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.45,121.40 14.50,121.30 14.50)',
   30000, 3000, null, 'club', '12000000-0000-0000-0000-000000000001'),
  ('22000000-0000-0000-0000-000000000003', 'Secret', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.25 14.55,121.20 14.50,121.30 14.50)',
   30000, 3000, null, 'private', null);

select pg_temp.act_as_postgres();
insert into club_members (club_id, user_id)
values ('12000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2')
on conflict do nothing;
insert into posts (id, author_id, loop_id, caption, stop_location)
values
  ('32000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a2',
   '22000000-0000-0000-0000-000000000001', 'Sulit!', 'SRID=4326;POINT(121.35 14.55)'),
  ('32000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a2',
   '22000000-0000-0000-0000-000000000002', 'Club day', 'SRID=4326;POINT(121.35 14.45)');
insert into post_photos (post_id, storage_path, position)
values
  ('32000000-0000-0000-0000-000000000001', 'a2/p1/1.jpg', 1),
  ('32000000-0000-0000-0000-000000000001', 'a2/p1/0.jpg', 0);

-- Signed out (the web page) --------------------------------------------------------

select pg_temp.act_as_anon();
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000001')
    - 'route' - 'id' - 'loop_id',
  jsonb_build_object(
    'status', 'ok', 'kind', 'loop', 'name', 'Tanay Sunrise',
    'distance_m', 82000, 'duration_s', 9000, 'main_stop', 'Daranak Falls',
    'author', 'Ana Sharer'
  ),
  'anyone can preview a public loop'
);
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000001')->'route'->>'type',
  'LineString',
  'the preview has the route as GeoJSON'
);
select ok(
  not (link_preview('loop', '22000000-0000-0000-0000-000000000001')->'route'->'coordinates'->0
    = '[121.3, 14.5]'::jsonb),
  'the preview route is the trimmed one, not the owner''s start'
);
select is(
  link_preview('post', '32000000-0000-0000-0000-000000000001')->>'photo',
  'a2/p1/0.jpg',
  'a public post''s preview has its first photo'
);
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000002'),
  jsonb_build_object(
    'status', 'club',
    'club_id', '12000000-0000-0000-0000-000000000001'::uuid,
    'club_name', 'Rizal Riders'
  ),
  'a club loop only says which club it belongs to'
);
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000003'),
  '{"status": "private"}'::jsonb,
  'a private loop says nothing about itself'
);
select is(
  link_preview('post', '00000000-0000-0000-0000-000000000000'),
  '{"status": "missing"}'::jsonb,
  'an unknown post is missing'
);
select throws_ok(
  $$select * from feed_page('post', '32000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'signed-out callers cannot use feed_page'
);

-- Signed in ------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b2');
select is(
  link_preview('post', '32000000-0000-0000-0000-000000000002')->>'status',
  'ok',
  'a club member can open a club post''s link'
);
select results_eq(
  $$select kind, id from feed_page('post', '32000000-0000-0000-0000-000000000002')$$,
  $$values ('post', '32000000-0000-0000-0000-000000000002'::uuid)$$,
  'feed_page(''post'') returns just that post'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c2');
select is(
  link_preview('post', '32000000-0000-0000-0000-000000000002')->>'status',
  'club',
  'a non-member is asked to join the club'
);
select is_empty(
  $$select id from feed_page('post', '32000000-0000-0000-0000-000000000002')$$,
  'feed_page(''post'') hides a club post from non-members'
);
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000003')->>'status',
  'private',
  'other riders cannot open a private loop'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select is(
  link_preview('loop', '22000000-0000-0000-0000-000000000003')->>'status',
  'ok',
  'the owner can open their own private loop'
);

select * from finish();
rollback;
