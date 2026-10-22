-- Prompt 17: riding clubs (photo, invite links, join, leave) and follows,
-- plus feed_page() for the Following and My clubs feeds, a club's page and
-- a rider's profile.

-- Clubs: photo and invite link ------------------------------------------------

-- 16 hex characters (~60 random bits): short enough for a link, too many to
-- guess.
create function public.new_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select left(replace(gen_random_uuid()::text, '-', ''), 16);
$$;

alter table public.clubs
  add column photo_url text check (char_length(photo_url) <= 500),
  add column invite_code text not null unique default public.new_invite_code();

-- Joining used to be "insert yourself into club_members", and every club id
-- is readable, so anyone could join any club. Now you join only with the
-- invite code (join_club), and only the owner can read it.
drop policy "club_members: users join as member" on public.club_members;
revoke insert on public.club_members from anon, authenticated;

revoke select, insert, update on public.clubs from anon, authenticated;
grant select (id, name, owner_id, photo_url, created_at) on public.clubs to authenticated;
grant insert (id, name, photo_url) on public.clubs to authenticated;
grant update (name, photo_url) on public.clubs to authenticated;

-- A club with the caller's role in it (null when not a member) and its
-- member count.
create function public.club_info(p_club_id uuid)
returns table (
  id uuid,
  name text,
  owner_id uuid,
  photo_url text,
  created_at timestamptz,
  my_role public.club_role,
  member_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id, c.name, c.owner_id, c.photo_url, c.created_at,
    (
      select m.role from public.club_members m
      where m.club_id = c.id and m.user_id = (select auth.uid())
    ),
    (select count(*) from public.club_members m where m.club_id = c.id)
  from public.clubs c
  where c.id = p_club_id;
$$;

-- The club an invite code is for, to show before joining. No rows for an
-- unknown (or reset) code.
create function public.club_by_invite(p_code text)
returns table (
  id uuid,
  name text,
  owner_id uuid,
  photo_url text,
  created_at timestamptz,
  my_role public.club_role,
  member_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select i.*
  from public.clubs c
  cross join lateral public.club_info(c.id) i
  where c.invite_code = p_code;
$$;

-- The caller's clubs, by name.
create function public.my_clubs()
returns table (
  id uuid,
  name text,
  owner_id uuid,
  photo_url text,
  created_at timestamptz,
  my_role public.club_role,
  member_count bigint
)
language sql
stable
set search_path = ''
as $$
  select
    c.id, c.name, c.owner_id, c.photo_url, c.created_at, m.role,
    (select count(*) from public.club_members cm where cm.club_id = c.id)
  from public.club_members m
  join public.clubs c on c.id = m.club_id
  where m.user_id = (select auth.uid())
  order by lower(c.name), c.id;
$$;

-- Joins the club with this invite code as a member; returns its id.
-- Joining twice is fine. Raises invite_not_found.
create function public.join_club(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_club_id uuid;
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  select c.id into v_club_id from public.clubs c where c.invite_code = p_code;
  if v_club_id is null then
    raise exception 'invite_not_found' using errcode = 'P0002';
  end if;
  insert into public.club_members (club_id, user_id, role)
  values (v_club_id, v_uid, 'member')
  on conflict do nothing;
  return v_club_id;
end;
$$;

-- The invite code, for the club's owner only (null for anyone else).
create function public.club_invite_code(p_club_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.invite_code from public.clubs c
  where c.id = p_club_id and c.owner_id = (select auth.uid());
$$;

-- A new invite code, so old links stop working. Owner only (null for
-- anyone else).
create function public.reset_club_invite(p_club_id uuid)
returns text
language sql
volatile
security definer
set search_path = ''
as $$
  update public.clubs
  set invite_code = public.new_invite_code()
  where id = p_club_id and owner_id = (select auth.uid())
  returning invite_code;
$$;

-- new_invite_code() stays executable: it's the column default, which runs
-- as the inserting user.
revoke execute on function public.club_info(uuid) from public, anon;
revoke execute on function public.club_by_invite(text) from public, anon;
revoke execute on function public.my_clubs() from public, anon;
revoke execute on function public.join_club(text) from public, anon;
revoke execute on function public.club_invite_code(uuid) from public, anon;
revoke execute on function public.reset_club_invite(uuid) from public, anon;
grant execute on function public.club_info(uuid) to authenticated;
grant execute on function public.club_by_invite(text) to authenticated;
grant execute on function public.my_clubs() to authenticated;
grant execute on function public.join_club(text) to authenticated;
grant execute on function public.club_invite_code(uuid) to authenticated;
grant execute on function public.reset_club_invite(uuid) to authenticated;

-- Follows -------------------------------------------------------------------------

create table public.follows (
  follower_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint follows_not_self check (follower_id <> followee_id)
);

create index follows_followee_id_idx on public.follows (followee_id);

alter table public.follows enable row level security;

-- Who follows whom is public to signed-in riders (follower counts).
create policy "follows: signed-in users can read"
  on public.follows for select to authenticated
  using (true);

create policy "follows: users follow as themselves"
  on public.follows for insert to authenticated
  with check (follower_id = (select auth.uid()));

create policy "follows: users unfollow"
  on public.follows for delete to authenticated
  using (follower_id = (select auth.uid()));

revoke update on public.follows from anon, authenticated;

-- A rider's public profile with follow counts.
create function public.rider_profile(p_user_id uuid)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  bike_type public.bike_type,
  home_area text,
  follower_count bigint,
  following_count bigint,
  followed_by_me boolean
)
language sql
stable
set search_path = ''
as $$
  select
    pr.id, pr.display_name, pr.avatar_url, pr.bike_type, pr.home_area,
    (select count(*) from public.follows f where f.followee_id = pr.id),
    (select count(*) from public.follows f where f.follower_id = pr.id),
    exists (
      select 1 from public.follows f
      where f.followee_id = pr.id and f.follower_id = (select auth.uid())
    )
  from public.profiles pr
  where pr.id = p_user_id;
$$;

revoke execute on function public.rider_profile(uuid) from public, anon;
grant execute on function public.rider_profile(uuid) to authenticated;

-- Feeds besides "Near you" ---------------------------------------------------------

-- Whether a feed item by p_author on a loop with this visibility and club
-- belongs in the scope:
--   following  riders the caller follows
--   clubs      club loops of the caller's clubs
--   club       loops of club p_target
--   rider      rider p_target
create function public.feed_scope_match(
  p_scope text,
  p_target uuid,
  p_author uuid,
  p_visibility public.loop_visibility,
  p_club_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case p_scope
    when 'following' then exists (
      select 1 from public.follows f
      where f.follower_id = (select auth.uid()) and f.followee_id = p_author
    )
    when 'clubs' then p_visibility = 'club' and public.is_club_member(p_club_id)
    when 'club' then p_visibility = 'club' and p_club_id = p_target
    when 'rider' then p_author = p_target
    else false
  end;
$$;

-- Posts, plus loops shared without a post (kind 'loop'), in a scope (see
-- feed_scope_match), newest first. Same columns as feed_near plus kind; a
-- loop item has the loop's id, no photos and no likes or comments.
-- distance_away_m is null without lat/lng. Security invoker: RLS decides
-- what the caller can see, and only loops.shared_route is ever read.
-- Private loops never show here, not even to their owner.
create function public.feed_page(
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
    where l.visibility <> 'private'
      and public.feed_scope_match(p_scope, p_target, p.author_id, l.visibility, l.club_id)
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

revoke execute on function public.feed_scope_match(text, uuid, uuid, public.loop_visibility, uuid) from public, anon;
grant execute on function public.feed_scope_match(text, uuid, uuid, public.loop_visibility, uuid) to authenticated;
revoke execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) to authenticated;
