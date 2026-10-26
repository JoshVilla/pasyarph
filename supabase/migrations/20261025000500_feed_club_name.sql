-- Expose loops.caption in the feed RPCs' loop jsonb so the feed can show a
-- loop's description/caption (e.g. for custom loops shared to a club).
create or replace function public.feed_near(
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
      'caption', l.caption,
      'source', l.source,
      'shared_route', st_asgeojson(l.shared_route)::jsonb,
      'distance_m', l.distance_m,
      'duration_s', l.duration_s,
      'curviness_score', l.curviness_score,
      'main_stop', l.main_stop,
      'province', l.province,
      'visibility', l.visibility,
      'club_id', l.club_id,
      'club_name', c.name,
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
  left join public.clubs c on c.id = l.club_id
  join public.profiles a on a.id = p.author_id
  where st_dwithin(p.stop_location, o.g, radius_m)
    and (page_cursor is null or p.created_at < page_cursor)
  order by p.created_at desc, p.id desc
  limit least(greatest(page_limit, 1), 50);
$$;
create or replace function public.feed_page(
  p_scope text,
  p_target uuid default null,
  lat double precision default null,
  lng double precision default null,
  page_limit integer default 20,
  page_cursor timestamptz default null
)
returns table (
  kind text,
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
    select case
      when lat is null or lng is null then null
      else st_setsrid(st_makepoint(lng, lat), 4326)::geography
    end as g
  ),
  items as (
    select
      'post'::text as kind, p.id, p.caption, p.created_at, p.author_id,
      p.loop_id, p.stop_location as stop
    from public.posts p
    join public.loops l on l.id = p.loop_id
    where (
        (p_scope = 'post' and p.id = p_target)
        or (
          l.visibility <> 'private'
          and public.feed_scope_match(p_scope, p_target, p.author_id, l.visibility, l.club_id)
        )
      )
      and (page_cursor is null or p.created_at < page_cursor)
    union all
select
      'loop'::text, l.id, l.caption, l.created_at, l.owner_id, l.id,
      case
        when l.main_stop ? 'lat' and l.main_stop ? 'lng' then st_setsrid(
          st_makepoint(
            (l.main_stop->>'lng')::double precision,
            (l.main_stop->>'lat')::double precision
          ),
          4326
        )::geography
        else st_lineinterpolatepoint(l.shared_route::geometry, 0.5)::geography
      end
    from public.loops l
    where l.visibility <> 'private'
      and l.shared_route is not null
      and not public.loop_has_post(l.id)
      and public.feed_scope_match(p_scope, p_target, l.owner_id, l.visibility, l.club_id)
      and (page_cursor is null or l.created_at < page_cursor)
  ),
  page as (
    select * from items
    order by created_at desc, id desc
    limit least(greatest(page_limit, 1), 50)
  )
  select
    i.kind,
    i.id,
    i.caption,
    i.created_at,
    st_asgeojson(i.stop)::jsonb,
    case when o.g is null then null else st_distance(i.stop, o.g) end,
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
        where ph.post_id = i.id
      ),
      '[]'::jsonb
    ),
    jsonb_build_object(
      'id', l.id,
      'owner_id', l.owner_id,
      'name', l.name,
      'caption', l.caption,
      'source', l.source,
      'shared_route', st_asgeojson(l.shared_route)::jsonb,
      'distance_m', l.distance_m,
      'duration_s', l.duration_s,
      'curviness_score', l.curviness_score,
      'main_stop', l.main_stop,
      'province', l.province,
      'visibility', l.visibility,
      'club_id', l.club_id,
      'club_name', c.name,
      'created_at', l.created_at
    ),
    (select count(*) from public.likes lk where lk.post_id = i.id),
    (select count(*) from public.comments c where c.post_id = i.id),
    exists (
      select 1 from public.likes lk
      where lk.post_id = i.id and lk.user_id = (select auth.uid())
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
      where c.post_id = i.id
      order by c.created_at, c.id
      limit 1
    )
  from page i
  cross join origin o
  join public.loops l on l.id = i.loop_id
  left join public.clubs c on c.id = l.club_id
  join public.profiles a on a.id = i.author_id
  order by i.created_at desc, i.id desc;
$$;

revoke execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.feed_near(double precision, double precision, double precision, integer, timestamptz) to authenticated;
revoke execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) to authenticated;

