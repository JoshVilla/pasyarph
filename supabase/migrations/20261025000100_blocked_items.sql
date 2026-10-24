-- Block a single post (or a loop shared without a post) from the feed: it
-- disappears for that rider only, without blocking its author. Enforced in
-- the posts and loops RLS policies like blocks and is_hidden (see
-- 20261024000300_moderation.sql), so every feed follows.

create table public.blocked_items (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('post', 'loop')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, target_type, target_id)
);

alter table public.blocked_items enable row level security;

create policy "blocked_items: users see their own"
  on public.blocked_items for select to authenticated
  using (user_id = (select auth.uid()));

create policy "blocked_items: users block as themselves"
  on public.blocked_items for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "blocked_items: users unblock"
  on public.blocked_items for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.blocked_items from anon;
revoke update on public.blocked_items from authenticated;

-- The caller blocked this post or loop.
create function public.item_blocked(p_type text, p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocked_items b
    where b.user_id = (select auth.uid())
      and b.target_type = p_type
      and b.target_id = p_id
  );
$$;

revoke execute on function public.item_blocked(text, uuid) from public, anon;
grant execute on function public.item_blocked(text, uuid) to authenticated;

-- Same as in 20261024000300_moderation.sql, plus item_blocked().
drop policy "loops: read public, own, or your clubs'" on public.loops;
create policy "loops: read public, own, or your clubs'"
  on public.loops for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (
      not is_hidden
      and public.author_visible(owner_id)
      and not public.item_blocked('loop', id)
      and (
        visibility = 'public'
        or (visibility = 'club' and public.is_club_member(club_id))
      )
    )
  );

drop policy "posts: read when the loop is visible" on public.posts;
create policy "posts: read when the loop is visible"
  on public.posts for select to authenticated
  using (
    author_id = (select auth.uid())
    or (
      not is_hidden
      and public.author_visible(author_id)
      and not public.item_blocked('post', id)
      and exists (select 1 from public.loops l where l.id = loop_id)
    )
  );

-- A loop "shared without a post" is one with no post at all, whether or
-- not the caller can see that post. Otherwise blocking or hiding a post
-- would bring its loop back into the feed as "shared a new loop".
create function public.loop_has_post(p_loop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.posts p where p.loop_id = p_loop_id);
$$;

revoke execute on function public.loop_has_post(uuid) from public, anon;
grant execute on function public.loop_has_post(uuid) to authenticated;

-- As in 20261024000100_share_links.sql, with loop_has_post().
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
