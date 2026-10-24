-- pgTAP tests for reports, blocking and hiding (Prompt 20).
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(24);

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

-- A posts, B reports and blocks, M moderates.
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a4', 'a4@test.ph', '{"full_name": "Ana Poster"}'),
  ('00000000-0000-0000-0000-0000000000b4', 'b4@test.ph', '{"full_name": "Ben Reporter"}'),
  ('00000000-0000-0000-0000-0000000000d4', 'm4@test.ph', '{"full_name": "Mod Erator"}');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a4');
insert into loops (id, name, source, route, distance_m, duration_s, visibility)
values
  ('24000000-0000-0000-0000-000000000001', 'Ana loop', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.40 14.50,121.30 14.50)',
   30000, 3000, 'public'),
  ('24000000-0000-0000-0000-000000000002', 'Ana other loop', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.45,121.40 14.50,121.30 14.50)',
   30000, 3000, 'public');

select pg_temp.act_as_postgres();
insert into posts (id, author_id, loop_id, caption, stop_location)
values ('34000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a4',
        '24000000-0000-0000-0000-000000000001', 'Spammy', 'SRID=4326;POINT(121.35 14.55)');
insert into comments (id, post_id, author_id, body)
values ('44000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-0000000000a4', 'Buy my parts');
insert into admins (user_id) values ('00000000-0000-0000-0000-0000000000d4');

-- Reports ---------------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b4');
select lives_ok(
  $$insert into reports (target_type, target_id, reason)
    values ('post', '34000000-0000-0000-0000-000000000001', 'Spam')$$,
  'a rider can report a post'
);
select throws_ok(
  $$insert into reports (target_type, target_id, reason)
    values ('post', '34000000-0000-0000-0000-000000000001', 'Spam again')$$,
  '23505',
  null,
  'one report per rider per thing'
);
insert into reports (target_type, target_id, reason)
values ('comment', '44000000-0000-0000-0000-000000000001', 'Spam');
select throws_ok(
  $$update reports set status = 'dismissed'$$,
  '42501',
  null,
  'reporters cannot resolve their own reports'
);
select is(is_admin(), false, 'riders are not admins');
select throws_ok(
  'select * from admin_report_queue()',
  '42501',
  'admins only',
  'riders cannot read the report queue'
);
select throws_ok(
  $$select admin_moderate('post', '34000000-0000-0000-0000-000000000001', 'hide')$$,
  '42501',
  'admins only',
  'riders cannot hide content'
);
select throws_ok(
  'select * from admins',
  '42501',
  null,
  'riders cannot read the admins table'
);

-- Hiding ---------------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000d4');
select is(is_admin(), true, 'admins are admins');
select results_eq(
  'select target_type::text, report_count, preview, author_name, is_hidden from admin_report_queue() order by target_type',
  $$values
    ('comment', 1::bigint, 'Buy my parts', 'Ana Poster', false),
    ('post', 1::bigint, 'Spammy', 'Ana Poster', false)$$,
  'the queue lists what was reported, whose it is, and its reports'
);

select lives_ok(
  $$select admin_moderate('post', '34000000-0000-0000-0000-000000000001', 'hide')$$,
  'an admin hides a post'
);
select lives_ok(
  $$select admin_moderate('comment', '44000000-0000-0000-0000-000000000001', 'dismiss')$$,
  'an admin dismisses a comment report'
);
select is_empty('select * from admin_report_queue()', 'resolved reports leave the queue');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b4');
select is_empty(
  $$select id from posts where id = '34000000-0000-0000-0000-000000000001'$$,
  'a hidden post is gone for other riders'
);
select is_empty(
  $$select id from feed_near(14.5, 121.35) where id = '34000000-0000-0000-0000-000000000001'$$,
  'a hidden post disappears from the Near you feed'
);
select is_empty(
  $$select id from feed_page('rider', '00000000-0000-0000-0000-0000000000a4') where kind = 'post'$$,
  'a hidden post disappears from the rider''s page'
);
select is(
  link_preview('post', '34000000-0000-0000-0000-000000000001')->>'status',
  'missing',
  'a hidden post''s share link looks deleted'
);
select results_eq(
  'select status from reports where target_type = ''post''',
  $$values ('hidden')$$,
  'the reporter sees their report was acted on'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a4');
select isnt_empty(
  $$select id from posts where id = '34000000-0000-0000-0000-000000000001'$$,
  'the author still sees their own hidden post'
);
update profiles set is_hidden = true where id = '00000000-0000-0000-0000-0000000000a4';
select pg_temp.act_as_postgres();
select is(
  (select is_hidden from profiles where id = '00000000-0000-0000-0000-0000000000a4'),
  false,
  'riders cannot hide (or unhide) their own profile'
);

-- Blocking -------------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b4');
insert into follows (followee_id) values ('00000000-0000-0000-0000-0000000000a4');
insert into blocks (blocked_id) values ('00000000-0000-0000-0000-0000000000a4');
select is_empty(
  $$select id from loops where owner_id = '00000000-0000-0000-0000-0000000000a4'$$,
  'a blocked rider''s loops are gone for the blocker'
);
select is_empty(
  $$select * from follows where follower_id = '00000000-0000-0000-0000-0000000000b4'$$,
  'blocking unfollows'
);
select throws_ok(
  $$insert into follows (followee_id) values ('00000000-0000-0000-0000-0000000000a4')$$,
  '42501',
  null,
  'riders cannot follow someone they blocked'
);

select pg_temp.act_as_anon();
select is(
  link_preview('loop', '24000000-0000-0000-0000-000000000002')->>'status',
  'ok',
  'blocking only hides content from the blocker'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b4');
delete from blocks where blocked_id = '00000000-0000-0000-0000-0000000000a4';
select isnt_empty(
  $$select id from loops where id = '24000000-0000-0000-0000-000000000002'$$,
  'unblocking shows their loops again'
);

select * from finish();
rollback;
