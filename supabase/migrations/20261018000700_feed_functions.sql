-- Both functions run as the caller (security invoker), so RLS decides what
-- they return, and only loops.shared_route is ever read, never loops.route.
-- Geometries come back as GeoJSON.

-- Public loops whose shared route passes within radius_m of (lat, lng),
-- nearest first.
create function public.loops_near(
  lat double precision,
  lng double precision,
  radius_m double precision default 50000,
  page_limit integer default 20,
  page_offset integer default 0
)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  source public.loop_source,
  shared_route jsonb,
  distance_m integer,
  duration_s integer,
  curviness_score real,
  main_stop jsonb,
  created_at timestamptz,
  distance_away_m double precision
)
language sql
stable
set search_path = public, extensions
as $$
  with origin as (
    select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g
  )
  select
    l.id,
    l.owner_id,
    l.name,
    l.source,
    st_asgeojson(l.shared_route)::jsonb,
    l.distance_m,
    l.duration_s,
    l.curviness_score,
    l.main_stop,
    l.created_at,
    st_distance(l.shared_route, o.g)
  from public.loops l
  cross join origin o
  where l.visibility = 'public'
    and l.shared_route is not null
    and st_dwithin(l.shared_route, o.g, radius_m)
  order by st_distance(l.shared_route, o.g), l.id
  limit least(greatest(page_limit, 1), 50)
  offset greatest(page_offset, 0);
$$;

-- Posts whose stop is within radius_m of (lat, lng), newest first.
-- Pass the last row's created_at as page_cursor to load the next page.
create function public.feed_near(
  lat double precision,
  lng double precision,
  radius_m double precision default 50000,
  page_limit integer default 20,
  page_cursor timestamptz default null
)
returns table (
  id uuid,
  caption text,
  created_at timestamptz,
  stop_location jsonb,
  distance_away_m double precision,
  author jsonb,
  photos jsonb,
  loop jsonb,
  like_count bigint,
  comment_count bigint,
  liked_by_me boolean
)
language sql
stable
set search_path = public, extensions
as $$
  with origin as (
    select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g
  )
  select
    p.id,
    p.caption,
    p.created_at,
    st_asgeojson(p.stop_location)::jsonb,
    st_distance(p.stop_location, o.g),
    jsonb_build_object(
      'id', a.id,
      'display_name', a.display_name,
      'avatar_url', a.avatar_url
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ph.id,
            'post_id', ph.post_id,
            'storage_path', ph.storage_path,
            'position', ph.position,
            'width', ph.width,
            'height', ph.height
          )
          order by ph.position
        )
        from public.post_photos ph
        where ph.post_id = p.id
      ),
      '[]'::jsonb
    ),
    jsonb_build_object(
      'id', l.id,
      'owner_id', l.owner_id,
      'name', l.name,
      'source', l.source,
      'shared_route', st_asgeojson(l.shared_route)::jsonb,
      'distance_m', l.distance_m,
      'duration_s', l.duration_s,
      'curviness_score', l.curviness_score,
      'main_stop', l.main_stop,
      'visibility', l.visibility,
      'club_id', l.club_id,
      'created_at', l.created_at
    ),
    (select count(*) from public.likes lk where lk.post_id = p.id),
    (select count(*) from public.comments c where c.post_id = p.id),
    exists (
      select 1 from public.likes lk
      where lk.post_id = p.id and lk.user_id = (select auth.uid())
    )
  from public.posts p
  cross join origin o
  join public.loops l on l.id = p.loop_id
  join public.profiles a on a.id = p.author_id
  where st_dwithin(p.stop_location, o.g, radius_m)
    and (page_cursor is null or p.created_at < page_cursor)
  order by p.created_at desc, p.id desc
  limit least(greatest(page_limit, 1), 50);
$$;

revoke execute on function public.loops_near(double precision, double precision, double precision, integer, integer) from public, anon;
revoke execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.loops_near(double precision, double precision, double precision, integer, integer) to authenticated;
grant execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) to authenticated;
