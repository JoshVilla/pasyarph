-- pgTAP tests for the schema, RLS, storage policies and feed functions.
-- Run with `npx supabase test db` (local stack) or psql against a database
-- that has the migrations applied. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(34);

-- Helpers -------------------------------------------------------------------

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

create function pg_temp.act_as_postgres() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Riders: A (owns things), B (A's club member), C (stranger).
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.ph', '{"full_name": "Ana Rider", "terms_accepted": true}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.ph', '{"name": "Ben Rider"}'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.ph', '{}');

-- Every public table has RLS on ----------------------------------------------

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
  0,
  'every table in public has row level security enabled'
);

-- Profiles ----------------------------------------------------------------------

select is(
  (select full_name from profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Ana Rider',
  'sign-up trigger creates a profile with full_name from metadata'
);
select is(
  (select full_name from profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'Ben Rider',
  'sign-up trigger falls back to the "name" metadata key (Google)'
);
select ok(
  (select terms_accepted_at is not null from profiles where id = '00000000-0000-0000-0000-00000000000a')
  and (select terms_accepted_at is null from profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'sign-up trigger records terms acceptance from metadata'
);

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
update profiles set display_name = 'Hacked' where id = '00000000-0000-0000-0000-00000000000a';
update profiles set display_name = 'Ben' where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.act_as_postgres();
select is(
  (select display_name from profiles where id = '00000000-0000-0000-0000-00000000000a'),
  null,
  'users cannot update another profile'
);
select is(
  (select display_name from profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'Ben',
  'users can update their own profile'
);

-- Clubs ---------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into clubs (id, name) values ('10000000-0000-0000-0000-000000000001', 'Isabela Riders');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into club_members (club_id, user_id)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
select pg_temp.act_as_postgres();

select is(
  (select role::text from club_members
   where club_id = '10000000-0000-0000-0000-000000000001'
     and user_id = '00000000-0000-0000-0000-00000000000a'),
  'owner',
  'club creator becomes the owner member'
);

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
  $$insert into club_members (club_id, user_id, role)
    values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c', 'owner')$$,
  '42501',
  null,
  'users cannot join a club as owner'
);
select throws_ok(
  $$insert into club_members (club_id, user_id)
    values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$$,
  '42501',
  null,
  'users cannot add someone else to a club'
);
select is(
  (select count(*)::int from club_members),
  0,
  'non-members cannot see a club''s members'
);
select pg_temp.act_as_postgres();

-- Loops: visibility -------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into loops (id, name, source, route, distance_m, duration_s, visibility, club_id, main_stop)
values
  ('20000000-0000-0000-0000-000000000001', 'Public loop', 'generated',
   'SRID=4326;LINESTRING(121.45 16.67,121.47 16.69,121.49 16.67,121.45 16.67)',
   9000, 900, 'public', null, '{"name": "Falls", "type": "waterfall", "lat": 16.69, "lng": 121.47}'),
  ('20000000-0000-0000-0000-000000000002', 'Club loop', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.46 16.70,121.45 16.67)',
   7000, 700, 'club', '10000000-0000-0000-0000-000000000001', null),
  ('20000000-0000-0000-0000-000000000003', 'Private loop', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.44 16.70,121.45 16.67)',
   7000, 700, 'private', null, null);

select pg_temp.act_as_postgres();
-- As postgres (no RLS) to hit the check constraint itself.
select throws_ok(
  $$insert into loops (owner_id, name, source, route, distance_m, duration_s, visibility)
    values ('00000000-0000-0000-0000-00000000000a', 'Bad', 'custom',
            'SRID=4326;LINESTRING(121 16,121.1 16.1)', 1, 1, 'club')$$,
  '23514',
  null,
  'club visibility requires a club'
);

-- Simulate privacy trimming (Prompt 12 adds the real trigger).
update loops set shared_route = 'SRID=4326;LINESTRING(121.46 16.68,121.47 16.69,121.48 16.68)';

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is((select count(*)::int from loops), 3, 'owners see all their loops');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select set_eq(
  'select name from loops',
  array['Public loop', 'Club loop'],
  'club members see public and club loops'
);
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select set_eq('select name from loops', array['Public loop'], 'others see public loops only');

-- Loops: home privacy ---------------------------------------------------------------------

select throws_ok(
  'select route from loops',
  '42501',
  null,
  'other users cannot read loops.route'
);
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  'select * from loops',
  '42501',
  null,
  'select * on loops is denied (route is never returned)'
);
select ok(
  (select loop_route('20000000-0000-0000-0000-000000000003') is not null),
  'owners get their full route from loop_route()'
);
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is(
  loop_route('20000000-0000-0000-0000-000000000001'),
  null,
  'loop_route() returns nothing to other users'
);
select throws_ok(
  $$update loops set shared_route = route where id = '20000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'users cannot write shared_route'
);
select pg_temp.act_as_postgres();

-- Posts and photos --------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into posts (id, loop_id, caption, stop_location)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   'Falls were full', 'SRID=4326;POINT(121.47 16.69)'),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003',
   'Secret spot', 'SRID=4326;POINT(121.44 16.70)');

insert into post_photos (post_id, storage_path, position)
select '30000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-00000000000a/30000000-0000-0000-0000-000000000001/' || n || '.jpg',
       n
from generate_series(0, 9) n;

select is(
  (select count(*)::int from post_photos where post_id = '30000000-0000-0000-0000-000000000001'),
  10,
  'a post can have 10 photos'
);
select throws_ok(
  $$insert into post_photos (post_id, storage_path, position)
    values ('30000000-0000-0000-0000-000000000001',
            '00000000-0000-0000-0000-00000000000a/x/10.jpg', 10)$$,
  '23514',
  null,
  'an 11th photo is rejected'
);
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select set_eq('select caption from posts', array['Falls were full'], 'posts follow their loop''s visibility');
select throws_ok(
  $$insert into posts (loop_id, stop_location)
    values ('20000000-0000-0000-0000-000000000003', 'SRID=4326;POINT(121.44 16.70)')$$,
  '42501',
  null,
  'users cannot post on a loop they cannot see'
);
update posts set caption = 'Hacked' where id = '30000000-0000-0000-0000-000000000001';
select throws_ok(
  $$update posts set loop_id = '20000000-0000-0000-0000-000000000003'
    where id = '30000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'only the caption of a post can be updated'
);
select pg_temp.act_as_postgres();
select is(
  (select caption from posts where id = '30000000-0000-0000-0000-000000000001'),
  'Falls were full',
  'users cannot edit someone else''s post'
);

-- Likes and comments ------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into likes (post_id) values ('30000000-0000-0000-0000-000000000001');
insert into comments (post_id, body) values ('30000000-0000-0000-0000-000000000001', 'Paved all the way?');
select throws_ok(
  $$insert into likes (post_id) values ('30000000-0000-0000-0000-000000000003')$$,
  '42501',
  null,
  'users cannot like a post they cannot see'
);

-- RPCs --------------------------------------------------------------------------------------

select results_eq(
  $$select caption, like_count::int, comment_count::int, liked_by_me, jsonb_array_length(photos)
    from feed_near(16.69, 121.47, 20000)$$,
  $$values ('Falls were full'::text, 1, 1, true, 10)$$,
  'feed_near returns visible posts with photos and counts'
);
select is(
  (select loop ->> 'name' from feed_near(16.69, 121.47, 20000)),
  'Public loop',
  'feed_near embeds the loop'
);
select is(
  (select count(*)::int from feed_near(16.69, 121.47, 20000, 20, '2000-01-01')),
  0,
  'feed_near pages by created_at cursor'
);
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select set_eq(
  'select name from loops_near(16.68, 121.47, 20000)',
  array['Public loop'],
  'loops_near returns public loops only'
);
select is(
  (select count(*)::int from loops_near(10.0, 123.0, 1000)),
  0,
  'loops_near respects the radius'
);

-- Storage -----------------------------------------------------------------------------------

select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('avatars', '00000000-0000-0000-0000-00000000000c/avatar.jpg',
            '00000000-0000-0000-0000-00000000000c')$$,
  'users upload into their own avatar folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('post-photos', '00000000-0000-0000-0000-00000000000a/p/0.jpg',
            '00000000-0000-0000-0000-00000000000c')$$,
  '42501',
  null,
  'users cannot upload into another user''s folder'
);

-- Anonymous users see nothing ---------------------------------------------------------------

select pg_temp.act_as_postgres();
set local role anon;
select is((select count(*)::int from posts), 0, 'anonymous users cannot read posts');

select * from finish();
rollback;
