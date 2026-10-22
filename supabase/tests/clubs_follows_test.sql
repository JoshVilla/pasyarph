-- pgTAP tests for clubs, invites, follows and feed_page (Prompt 17).
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(29);

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

-- A owns the club, B joins it, C is a stranger.
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.ph', '{"full_name": "Ana Owner"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.ph', '{"full_name": "Ben Member"}'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.ph', '{"full_name": "Cara Stranger"}');

-- Clubs and invites -----------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
insert into clubs (id, name, photo_url)
values ('11000000-0000-0000-0000-000000000001', 'Cordon Riders', 'https://example.test/club.jpg');
select set_config('test.invite', club_invite_code('11000000-0000-0000-0000-000000000001'), true);

select ok(
  char_length(current_setting('test.invite')) = 16,
  'the owner gets the club''s invite code'
);
select results_eq(
  'select my_role::text, member_count from my_clubs()',
  $$values ('owner', 1::bigint)$$,
  'my_clubs() lists the owner''s club with its role and member count'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  'select invite_code from clubs',
  '42501',
  null,
  'riders cannot read invite codes from clubs'
);
select is(
  club_invite_code('11000000-0000-0000-0000-000000000001'),
  null,
  'club_invite_code() returns nothing to non-owners'
);
select is(
  (select photo_url from clubs where id = '11000000-0000-0000-0000-000000000001'),
  'https://example.test/club.jpg',
  'riders can read a club''s name and photo'
);
select results_eq(
  format('select name, my_role::text, member_count from club_by_invite(%L)', current_setting('test.invite')),
  $$values ('Cordon Riders', null::text, 1::bigint)$$,
  'club_by_invite() previews the club before joining'
);
select is_empty(
  $$select * from club_by_invite('0000000000000000')$$,
  'club_by_invite() finds nothing for an unknown code'
);
select throws_ok(
  $$insert into club_members (club_id, user_id)
    values ('11000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1')$$,
  '42501',
  null,
  'riders cannot join a club without its invite code'
);
select throws_ok(
  $$select join_club('0000000000000000')$$,
  'P0002',
  'invite_not_found',
  'join_club() refuses an unknown code'
);
select throws_ok(
  $$update clubs set invite_code = 'mine' where id = '11000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'riders cannot set an invite code'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select is(
  join_club(current_setting('test.invite')),
  '11000000-0000-0000-0000-000000000001'::uuid,
  'join_club() joins with the invite code'
);
select lives_ok(
  format('select join_club(%L)', current_setting('test.invite')),
  'joining twice is fine'
);
select results_eq(
  $$select my_role::text, member_count from club_info('11000000-0000-0000-0000-000000000001')$$,
  $$values ('member', 2::bigint)$$,
  'club_info() shows the member''s role and the member count'
);
select is(
  club_invite_code('11000000-0000-0000-0000-000000000001'),
  null,
  'members don''t get the invite code (only the owner invites)'
);

-- Club loops and the clubs feed -----------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
-- Long enough (~22 km) that the home privacy trim leaves a shared_route.
insert into loops (id, name, source, route, distance_m, duration_s, visibility, club_id)
values
  ('21000000-0000-0000-0000-000000000001', 'Club ride', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.50 16.72,121.55 16.67,121.45 16.67)',
   30000, 3000, 'club', '11000000-0000-0000-0000-000000000001'),
  ('21000000-0000-0000-0000-000000000002', 'Club loop, no post', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.50 16.62,121.55 16.67,121.45 16.67)',
   30000, 3000, 'club', '11000000-0000-0000-0000-000000000001'),
  ('21000000-0000-0000-0000-000000000003', 'Public ride', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.40 16.72,121.35 16.67,121.45 16.67)',
   30000, 3000, 'public', null),
  ('21000000-0000-0000-0000-000000000004', 'Secret loop', 'custom',
   'SRID=4326;LINESTRING(121.45 16.67,121.40 16.62,121.35 16.67,121.45 16.67)',
   30000, 3000, 'private', null);

-- Posts are made by create_post_from_ride(); insert directly here.
select pg_temp.act_as_postgres();
insert into posts (id, author_id, loop_id, caption, stop_location, created_at)
values
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
   '21000000-0000-0000-0000-000000000001', 'Club Sunday', 'SRID=4326;POINT(121.50 16.72)',
   now() - interval '1 hour'),
  ('31000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1',
   '21000000-0000-0000-0000-000000000003', 'Open road', 'SRID=4326;POINT(121.40 16.72)',
   now() - interval '2 hours');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select set_eq(
  $$select id from loops where visibility = 'club'$$,
  $$values ('21000000-0000-0000-0000-000000000001'::uuid), ('21000000-0000-0000-0000-000000000002'::uuid)$$,
  'a club loop is visible to a member'
);
select results_eq(
  $$select kind, id from feed_page('clubs')$$,
  $$values
    ('loop', '21000000-0000-0000-0000-000000000002'::uuid),
    ('post', '31000000-0000-0000-0000-000000000001'::uuid)$$,
  'My clubs: club posts and club loops shared without a post, newest first'
);
select results_eq(
  $$select kind, distance_away_m is null from feed_page('club', '11000000-0000-0000-0000-000000000001') limit 1$$,
  $$values ('loop', true)$$,
  'a club''s page lists its items; no distance without a location'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c1');
select is_empty(
  $$select id from loops where visibility = 'club'$$,
  'a club loop is invisible to a non-member'
);
select is_empty(
  $$select id from feed_page('club', '11000000-0000-0000-0000-000000000001')$$,
  'non-members see nothing on a club''s page'
);
select is_empty(
  $$select id from posts where id = '31000000-0000-0000-0000-000000000001'$$,
  'posts on club loops are invisible to non-members'
);

-- Leaving
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
delete from club_members
where club_id = '11000000-0000-0000-0000-000000000001'
  and user_id = '00000000-0000-0000-0000-0000000000b1';
select is_empty(
  $$select id from loops where visibility = 'club'$$,
  'after leaving, the club''s loops are invisible'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
delete from club_members
where club_id = '11000000-0000-0000-0000-000000000001'
  and user_id = '00000000-0000-0000-0000-0000000000a1';
select results_eq(
  'select my_role::text from my_clubs()',
  $$values ('owner')$$,
  'the owner cannot leave their own club'
);

-- Resetting the link
select isnt(
  reset_club_invite('11000000-0000-0000-0000-000000000001'),
  current_setting('test.invite'),
  'the owner can reset the invite link'
);
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  format('select join_club(%L)', current_setting('test.invite')),
  'P0002',
  'invite_not_found',
  'an old invite link stops working after a reset'
);

-- Follows and the Following feed ----------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c1');
insert into follows (followee_id) values ('00000000-0000-0000-0000-0000000000a1');
select throws_ok(
  $$insert into follows (follower_id, followee_id)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1')$$,
  '42501',
  null,
  'riders cannot follow on someone else''s behalf'
);
select throws_ok(
  $$insert into follows (followee_id) values ('00000000-0000-0000-0000-0000000000c1')$$,
  '23514',
  null,
  'riders cannot follow themselves'
);
select results_eq(
  $$select follower_count, following_count, followed_by_me
    from rider_profile('00000000-0000-0000-0000-0000000000a1')$$,
  $$values (1::bigint, 0::bigint, true)$$,
  'rider_profile() shows follow counts and whether I follow them'
);
select results_eq(
  $$select id from feed_page('following')$$,
  $$values ('31000000-0000-0000-0000-000000000003'::uuid)$$,
  'Following: public posts of riders I follow (not their club or private loops)'
);
delete from follows where followee_id = '00000000-0000-0000-0000-0000000000a1';
select is_empty(
  $$select id from feed_page('following')$$,
  'after unfollowing, their posts leave the Following feed'
);

select * from finish();
rollback;
