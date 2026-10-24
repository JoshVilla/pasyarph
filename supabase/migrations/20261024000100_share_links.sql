-- Prompt 18: share links (https://pasyar.pages.dev/l/<loop>, /p/<post>).
--
-- link_preview() says whether a link can be opened, and what the "not
-- installed" web page and the app show for it. It runs as the owner so it
-- can tell "private" and "club" apart from "missing", but only hands out
-- details of what the caller could read anyway:
--   ok       public, your own, or a club loop you're in: name, stats and the
--            trimmed route (never loops.route), plus the post's author,
--            caption and first photo for a post
--   club     a club loop and you're not a member: just the club's name, so
--            the app can ask you to join
--   private  someone else's private loop: nothing
--   missing  no such loop or post
-- Signed-out callers (the web page) only get 'ok' for public loops.

create function public.link_preview(p_kind text, p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_loop_id uuid;
  v_post public.posts%rowtype;
  v_loop public.loops%rowtype;
  v_status text;
  v_result jsonb;
begin
  if p_kind = 'post' then
    select * into v_post from public.posts where id = p_id;
    if not found then
      return jsonb_build_object('status', 'missing');
    end if;
    v_loop_id := v_post.loop_id;
  elsif p_kind = 'loop' then
    v_loop_id := p_id;
  else
    raise exception 'unknown link kind %', p_kind using errcode = '22023';
  end if;

  select * into v_loop from public.loops where id = v_loop_id;
  if not found then
    return jsonb_build_object('status', 'missing');
  end if;

  v_status := case
    when v_uid is not null and v_loop.owner_id = v_uid then 'ok'
    when v_loop.visibility = 'public' then 'ok'
    when v_loop.visibility = 'club'
      and v_uid is not null
      and public.is_club_member(v_loop.club_id) then 'ok'
    when v_loop.visibility = 'club' then 'club'
    else 'private'
  end;

  if v_status = 'club' then
    return jsonb_build_object(
      'status', 'club',
      'club_id', v_loop.club_id,
      'club_name', (select c.name from public.clubs c where c.id = v_loop.club_id)
    );
  elsif v_status <> 'ok' then
    return jsonb_build_object('status', v_status);
  end if;

  v_result := jsonb_build_object(
    'status', 'ok',
    'kind', p_kind,
    'id', p_id,
    'loop_id', v_loop.id,
    'name', v_loop.name,
    'distance_m', v_loop.distance_m,
    'duration_s', v_loop.duration_s,
    'main_stop', v_loop.main_stop->>'name',
    -- About 10 m detail is plenty for a 640 px map and keeps the URL short.
    'route', extensions.st_asgeojson(
      extensions.st_simplify(v_loop.shared_route::extensions.geometry, 0.0001),
      5
    )::jsonb,
    'author', (
      select a.display_name from public.profiles a
      where a.id = coalesce(v_post.author_id, v_loop.owner_id)
    )
  );

  if p_kind = 'post' then
    v_result := v_result || jsonb_build_object(
      'caption', v_post.caption,
      'photo', (
        select ph.storage_path from public.post_photos ph
        where ph.post_id = v_post.id
        order by ph.position
        limit 1
      )
    );
  end if;
  return v_result;
end;
$$;

revoke execute on function public.link_preview(text, uuid) from public;
grant execute on function public.link_preview(text, uuid) to anon, authenticated;

-- feed_page gains scope 'post' (p_target = a post id): that one post, for
-- the post screen a /p/ link opens. RLS still decides whether it shows.
-- Everything else is as in 20261020000100_clubs_and_follows.sql.
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
      'loop'::text, l.id, null::text, l.created_at, l.owner_id, l.id,
      -- The main stop, or the middle of the shared route: never the start.
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
      and not exists (select 1 from public.posts p where p.loop_id = l.id)
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
    -- A loop item's id is a loop id, so it matches no photos, likes or
    -- comments below.
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
      'source', l.source,
      'shared_route', st_asgeojson(l.shared_route)::jsonb,
      'distance_m', l.distance_m,
      'duration_s', l.duration_s,
      'curviness_score', l.curviness_score,
      'main_stop', l.main_stop,
      'province', l.province,
      'visibility', l.visibility,
      'club_id', l.club_id,
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
  join public.profiles a on a.id = i.author_id
  order by i.created_at desc, i.id desc;
$$;
