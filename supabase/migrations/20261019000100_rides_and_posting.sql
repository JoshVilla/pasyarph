-- Prompt 11: riders post a loop after riding it. Every post comes from a
-- ride Pasyar tracked, so posts and their photos are only created through
-- create_post_from_ride(), which checks the ride.

-- Finished rides. The id is picked on the phone so a ride saved offline
-- syncs exactly once.
create table public.rides (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null check (ended_at >= started_at),
  ridden_m integer not null check (ridden_m >= 0),
  -- The planned loop, full (starts at the rider's start point). Owner only.
  route extensions.geography(LineString, 4326) not null,
  loop_distance_m integer not null check (loop_distance_m >= 0),
  loop_duration_s integer not null check (loop_duration_s >= 0),
  curviness_score real check (curviness_score >= 0),
  -- {name, type, lat, lng}
  main_stop jsonb check (
    main_stop is null
    or (jsonb_typeof(main_stop) = 'object' and main_stop ? 'lat' and main_stop ? 'lng')
  ),
  reached_stop boolean not null default false,
  -- Set when the ride is posted (the loop saved for it).
  loop_id uuid references public.loops (id) on delete set null,
  created_at timestamptz not null default now()
);

create index rides_owner_ended_idx on public.rides (owner_id, ended_at desc);

alter table public.rides enable row level security;

create policy "rides: owners read"
  on public.rides for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "rides: owners add"
  on public.rides for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "rides: owners delete"
  on public.rides for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Rides don't change after they're saved; loop_id is set by the RPC.
revoke insert, update on public.rides from anon, authenticated;
grant insert (
  id, started_at, ended_at, ridden_m, route, loop_distance_m, loop_duration_s,
  curviness_score, main_stop, reached_stop
) on public.rides to authenticated;

-- One post per ride.
alter table public.posts
  add column ride_id uuid unique references public.rides (id) on delete set null;

-- Posts and photos only through create_post_from_ride().
revoke insert on public.posts from anon, authenticated;
revoke insert on public.post_photos from anon, authenticated;

-- Posts a ride: saves its loop (public) unless already saved, then the post
-- and its photos, in one transaction. Photos must already be uploaded to
-- post-photos/<user_id>/<post_id>/. p_photos: [{storage_path, position,
-- width, height}], 1-10 items. Raises:
--   ride_not_found      not the caller's ride
--   ride_too_old        finished more than 7 days ago
--   ride_too_short      ridden less than a quarter of the loop
--   ride_already_posted
--   bad_photos          wrong count, positions or paths
create function public.create_post_from_ride(
  p_post_id uuid,
  p_ride_id uuid,
  p_loop_name text,
  p_caption text,
  p_photos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ride public.rides;
  v_loop_id uuid;
  v_stop extensions.geography;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select * into v_ride
  from public.rides
  where id = p_ride_id and owner_id = v_uid
  for update;
  if not found then
    raise exception 'ride_not_found' using errcode = 'P0002';
  end if;
  if v_ride.ended_at < now() - interval '7 days' then
    raise exception 'ride_too_old';
  end if;
  if v_ride.ridden_m * 4 < v_ride.loop_distance_m then
    raise exception 'ride_too_short';
  end if;
  if exists (select 1 from public.posts where ride_id = p_ride_id) then
    raise exception 'ride_already_posted';
  end if;

  v_count := jsonb_array_length(coalesce(p_photos, '[]'::jsonb));
  if v_count < 1 or v_count > 10 or exists (
    select 1 from jsonb_array_elements(p_photos) e
    where e->>'storage_path' not like v_uid::text || '/' || p_post_id::text || '/%'
      or (e->>'position')::integer not between 0 and 9
  ) then
    raise exception 'bad_photos';
  end if;

  v_loop_id := v_ride.loop_id;
  if v_loop_id is null then
    insert into public.loops (
      owner_id, name, source, route, distance_m, duration_s,
      curviness_score, main_stop, visibility
    )
    values (
      v_uid,
      left(coalesce(nullif(trim(p_loop_name), ''), 'Loop'), 80),
      'generated',
      v_ride.route,
      v_ride.loop_distance_m,
      v_ride.loop_duration_s,
      v_ride.curviness_score,
      v_ride.main_stop,
      'public'
    )
    returning id into v_loop_id;
    update public.rides set loop_id = v_loop_id where id = v_ride.id;
  end if;

  -- The main stop, or the middle of the loop: never the start (home).
  v_stop := case
    when v_ride.main_stop is not null then extensions.st_setsrid(
      extensions.st_makepoint(
        (v_ride.main_stop->>'lng')::double precision,
        (v_ride.main_stop->>'lat')::double precision
      ),
      4326
    )::extensions.geography
    else extensions.st_lineinterpolatepoint(
      v_ride.route::extensions.geometry, 0.5
    )::extensions.geography
  end;

  insert into public.posts (id, author_id, loop_id, caption, stop_location, ride_id)
  values (p_post_id, v_uid, v_loop_id, nullif(trim(p_caption), ''), v_stop, p_ride_id);

  insert into public.post_photos (post_id, storage_path, position, width, height)
  select
    p_post_id,
    e->>'storage_path',
    (e->>'position')::smallint,
    (e->>'width')::integer,
    (e->>'height')::integer
  from jsonb_array_elements(p_photos) e;

  return p_post_id;
end;
$$;

revoke execute on function public.create_post_from_ride(uuid, uuid, text, text, jsonb)
  from public, anon;
grant execute on function public.create_post_from_ride(uuid, uuid, text, text, jsonb)
  to authenticated;
