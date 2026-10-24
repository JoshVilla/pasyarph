-- pgTAP tests for blocking single posts and loops from the feed.
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(10);

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

-- A posts two rides and shares a loop; B blocks things; C is someone else.
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a5', 'a5@test.ph', '{"full_name": "Ana Poster"}'),
  ('00000000-0000-0000-0000-0000000000b5', 'b5@test.ph', '{"full_name": "Ben Blocker"}'),
  ('00000000-0000-0000-0000-0000000000c5', 'c5@test.ph', '{"full_name": "Cara Other"}');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a5');
insert into loops (id, name, source, route, distance_m, duration_s, visibility)
values
  ('25000000-0000-0000-0000-000000000001', 'Posted loop', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.40 14.50,121.30 14.50)',
   30000, 3000, 'public'),
  ('25000000-0000-0000-0000-000000000002', 'Other posted loop', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.45,121.40 14.50,121.30 14.50)',
   30000, 3000, 'public'),
  ('25000000-0000-0000-0000-000000000003', 'Shared loop', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.25 14.55,121.20 14.50,121.30 14.50)',
   30000, 3000, 'public');

select pg_temp.act_as_postgres();
insert into posts (id, author_id, loop_id, caption, stop_location, created_at)
values
  ('35000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a5',
   '25000000-0000-0000-0000-000000000001', 'Not for me', 'SRID=4326;POINT(121.35 14.55)',
   now() - interval '1 hour'),
  ('35000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a5',
   '25000000-0000-0000-0000-000000000002', 'Nice one', 'SRID=4326;POINT(121.35 14.45)',
   now() - interval '2 hours');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b5');
insert into blocked_items (target_type, target_id)
values
  ('post', '35000000-0000-0000-0000-000000000001'),
  ('loop', '25000000-0000-0000-0000-000000000003');

select results_eq(
  $$select kind, id from feed_page('rider', '00000000-0000-0000-0000-0000000000a5')$$,
  $$values ('post', '35000000-0000-0000-0000-000000000002'::uuid)$$,
  'blocked post and loop are gone; the rest of the rider''s feed stays'
);
select is_empty(
  $$select id from feed_near(14.5, 121.35) where id = '35000000-0000-0000-0000-000000000001'$$,
  'a blocked post leaves Near you'
);
select is_empty(
  $$select id from posts where id = '35000000-0000-0000-0000-000000000001'$$,
  'a blocked post can''t be read'
);
select results_eq(
  'select target_type, target_id from blocked_items order by target_type',
  $$values ('loop', '25000000-0000-0000-0000-000000000003'::uuid),
           ('post', '35000000-0000-0000-0000-000000000001'::uuid)$$,
  'a rider sees what they blocked'
);
select throws_ok(
  $$insert into blocked_items (user_id, target_type, target_id)
    values ('00000000-0000-0000-0000-0000000000c5', 'post', '35000000-0000-0000-0000-000000000002')$$,
  '42501',
  null,
  'riders cannot block things for someone else'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c5');
select results_eq(
  $$select count(*) from feed_page('rider', '00000000-0000-0000-0000-0000000000a5')$$,
  $$values (3::bigint)$$,
  'blocking only affects the rider who blocked'
);
select is_empty('select * from blocked_items', 'riders don''t see others'' blocked items');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a5');
select isnt_empty(
  $$select id from posts where id = '35000000-0000-0000-0000-000000000001'$$,
  'the author still sees a post someone blocked'
);

-- An admin-hidden post doesn't come back as "shared a new loop" either.
select pg_temp.act_as_postgres();
update posts set is_hidden = true where id = '35000000-0000-0000-0000-000000000002';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c5');
select is_empty(
  $$select id from feed_page('rider', '00000000-0000-0000-0000-0000000000a5')
    where id = '25000000-0000-0000-0000-000000000002'$$,
  'a hidden post''s loop stays out of the feed'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b5');
delete from blocked_items where target_type = 'post';
select isnt_empty(
  $$select id from posts where id = '35000000-0000-0000-0000-000000000001'$$,
  'unblocking brings the post back'
);

select * from finish();
rollback;
