-- pgTAP tests for the profile redesign: username, bio, cover, rider stats,
-- and the covers bucket. Run with `npx supabase test db`. Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(13);

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
  ('00000000-0000-0000-0000-0000000000a6', 'a6@test.ph', '{"full_name": "Ana Profile"}'),
  ('00000000-0000-0000-0000-0000000000b6', 'b6@test.ph', '{"full_name": "Ben Viewer"}');

-- Username and bio -----------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a6');
select lives_ok(
  $$update profiles set username = 'ana.rides_1', bio = 'Weekend loops in Rizal.',
      cover_url = 'https://x.supabase.co/storage/v1/object/public/covers/a/cover_1.jpg'
    where id = '00000000-0000-0000-0000-0000000000a6'$$,
  'a rider sets a username, bio and cover'
);
select throws_ok(
  $$update profiles set username = 'Ana Rides' where id = '00000000-0000-0000-0000-0000000000a6'$$,
  '23514',
  null,
  'usernames are lowercase letters, numbers, dots and underscores'
);
select throws_ok(
  $$update profiles set username = 'ab' where id = '00000000-0000-0000-0000-0000000000a6'$$,
  '23514',
  null,
  'usernames have at least 3 characters'
);
select throws_ok(
  format('update profiles set bio = %L where id = %L', repeat('x', 151), '00000000-0000-0000-0000-0000000000a6'),
  '23514',
  null,
  'bios have at most 150 characters'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b6');
select throws_ok(
  $$update profiles set username = 'ana.rides_1' where id = '00000000-0000-0000-0000-0000000000b6'$$,
  '23505',
  null,
  'usernames are unique'
);
update profiles set username = 'hacked' where id = '00000000-0000-0000-0000-0000000000a6';
select is(
  (select username from profiles where id = '00000000-0000-0000-0000-0000000000a6'),
  'ana.rides_1',
  'riders cannot change someone else''s username'
);

-- rider_profile ----------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a6');
insert into rides (id, started_at, ended_at, ridden_m, route, loop_distance_m, loop_duration_s)
values ('46000000-0000-0000-0000-000000000001', now() - interval '3 hours', now(),
        41000, 'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.30 14.50)', 40000, 5000);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b6');
select results_eq(
  $$select username, bio, cover_url is not null, ridden_m, loops_ridden, posts
    from rider_profile('00000000-0000-0000-0000-0000000000a6')$$,
  $$values ('ana.rides_1', 'Weekend loops in Rizal.', true, 41000::bigint, 1::bigint, 0::bigint)$$,
  'other riders see the username, bio, cover and ride totals'
);
select is_empty(
  'select * from rides',
  'but still can''t read the rides themselves'
);

-- Covers bucket ------------------------------------------------------------------------------

set local role postgres;
select is(
  (select public from storage.buckets where id = 'covers'),
  true,
  'the covers bucket is public to read'
);
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b6');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('covers', '00000000-0000-0000-0000-0000000000b6/cover_1.jpg', '00000000-0000-0000-0000-0000000000b6')$$,
  'riders upload to their own covers folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('covers', '00000000-0000-0000-0000-0000000000a6/cover_2.jpg', '00000000-0000-0000-0000-0000000000b6')$$,
  '42501',
  null,
  'riders cannot upload to someone else''s covers folder'
);
-- Storage refuses deletes through SQL (only its API), so check the policy.
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'covers: users delete their own files'
      and cmd = 'DELETE'
  ),
  'riders can delete their own covers'
);

-- A hidden rider looks gone.
set local role postgres;
update profiles set is_hidden = true where id = '00000000-0000-0000-0000-0000000000a6';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b6');
select is_empty(
  $$select * from rider_profile('00000000-0000-0000-0000-0000000000a6')$$,
  'a hidden rider''s profile is gone for others'
);

select * from finish();
rollback;
