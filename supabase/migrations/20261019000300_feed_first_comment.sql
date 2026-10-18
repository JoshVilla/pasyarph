-- Prompt 13: feed_near also returns each post's first comment, for the
-- preview under the card. Otherwise unchanged (still security invoker, and
-- only loops.shared_route is ever read). The return type changes, so the
-- function is dropped and created again.

drop function public.feed_near(double precision, double precision, double precision, integer, timestamptz);

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
  liked_by_me boolean,
  first_comment jsonb
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
    ),
    (
      select jsonb_build_object(
        'body', c.body,
        'author', jsonb_build_object(
          'id', ca.id,
          'display_name', ca.display_name,
          'avatar_url', ca.avatar_url
        )
      )
      from public.comments c
      join public.profiles ca on ca.id = c.author_id
      where c.post_id = p.id
      order by c.created_at, c.id
      limit 1
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

revoke execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) to authenticated;
