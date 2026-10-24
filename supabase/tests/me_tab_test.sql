-- pgTAP tests for the Me tab: saved loops and my_totals() (Prompt 19).
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(11);

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

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a3', 'a3@test.ph', '{"full_name": "Ana Saver"}'),
  ('00000000-0000-0000-0000-0000000000b3', 'b3@test.ph', '{"full_name": "Ben Other"}');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b3');
insert into loops (id, name, source, route, distance_m, duration_s, visibility)
values
  ('23000000-0000-0000-0000-000000000001', 'Ben public', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.40 14.50,121.30 14.50)',
   30000, 3000, 'public'),
  ('23000000-0000-0000-0000-000000000002', 'Ben private', 'custom',
   'SRID=4326;LINESTRING(121.30 14.50,121.35 14.45,121.40 14.50,121.30 14.50)',
   30000, 3000, 'private');

-- Saved loops ---------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select lives_ok(
  $$insert into saved_loops (loop_id) values ('23000000-0000-0000-0000-000000000001')$$,
  'a rider can save a public loop'
);
select throws_ok(
  $$insert into saved_loops (loop_id) values ('23000000-0000-0000-0000-000000000002')$$,
  '42501',
  null,
  'a rider cannot save a loop they cannot see'
);
select throws_ok(
  $$insert into saved_loops (user_id, loop_id)
    values ('00000000-0000-0000-0000-0000000000b3', '23000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'a rider cannot save loops for someone else'
);
select results_eq(
  'select loop_id from saved_loops',
  $$values ('23000000-0000-0000-0000-000000000001'::uuid)$$,
  'a rider sees their saved loops'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b3');
select is_empty('select * from saved_loops', 'riders don''t see others'' saved loops');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
delete from saved_loops where loop_id = '23000000-0000-0000-0000-000000000001';
select is_empty('select * from saved_loops', 'a rider can unsave a loop');

insert into saved_loops (loop_id) values ('23000000-0000-0000-0000-000000000001');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b3');
delete from loops where id = '23000000-0000-0000-0000-000000000001';
select pg_temp.act_as_postgres();
select is(
  (select count(*) from saved_loops where user_id = '00000000-0000-0000-0000-0000000000a3'),
  0::bigint,
  'a deleted loop leaves everyone''s saved loops'
);

-- Totals ---------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select results_eq(
  'select ridden_m, loops_ridden, posts from my_totals()',
  $$values (0::bigint, 0::bigint, 0::bigint)$$,
  'a new rider has zero totals'
);

insert into rides (id, started_at, ended_at, ridden_m, route, loop_distance_m, loop_duration_s)
values
  ('43000000-0000-0000-0000-000000000001', now() - interval '3 hours', now() - interval '1 hour',
   41000, 'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.30 14.50)', 40000, 5000),
  -- Turned back early: counts toward km, not toward loops ridden.
  ('43000000-0000-0000-0000-000000000002', now() - interval '2 hours', now() - interval '90 minutes',
   5000, 'SRID=4326;LINESTRING(121.30 14.50,121.35 14.55,121.30 14.50)', 40000, 5000);
select results_eq(
  'select ridden_m, loops_ridden, posts from my_totals()',
  $$values (46000::bigint, 1::bigint, 0::bigint)$$,
  'totals add up km ridden and loops ridden at least a quarter of the way'
);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b3');
select results_eq(
  'select ridden_m, loops_ridden from my_totals()',
  $$values (0::bigint, 0::bigint)$$,
  'totals only count the caller''s own rides'
);

set local role anon;
select throws_ok(
  'select * from my_totals()',
  '42501',
  null,
  'signed-out callers cannot read totals'
);

select * from finish();
rollback;
