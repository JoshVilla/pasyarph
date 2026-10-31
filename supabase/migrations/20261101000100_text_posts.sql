-- Text posts: a rider can post words (and up to 10 photos) without a ride,
-- like a Facebook status. They have no loop and no location, so they never
-- show in "Near you" (feed_near joins loops and needs stop_location); they
-- show in Global, Following, My clubs, club pages and profiles. A text post
-- carries its own visibility, chosen like a loop's: public, a club, or only
-- the author.

alter table public.posts
  alter column loop_id drop not null,
  alter column stop_location drop not null,
  add column visibility public.loop_visibility,
  add column club_id uuid references public.clubs (id) on delete set null;

-- A ride post has a loop (and takes its visibility from it); a text post has
-- no loop, its own visibility, and text.
alter table public.posts add constraint posts_ride_or_text check (
  (loop_id is not null and visibility is null and club_id is null)
  or (
    loop_id is null
    and visibility is not null
    and stop_location is null
    and coalesce(char_length(trim(caption)), 0) >= 1
  )
);

alter table public.posts add constraint posts_text_club check (
  visibility is null or (visibility = 'club') = (club_id is not null)
);

create index posts_club_id_idx on public.posts (club_id) where club_id is not null;

-- As loops: when a club is deleted, its text posts become the author's own.
create function public.privatize_club_posts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.posts
  set visibility = 'private', club_id = null
  where club_id = old.id;
  return old;
end;
$$;

create trigger on_club_deleted_posts
  before delete on public.clubs
  for each row execute function public.privatize_club_posts();

-- Ride posts: visible with their loop. Text posts: by their own visibility.
drop policy "posts: read when the loop is visible" on public.posts;
create policy "posts: read when the loop is visible"
  on public.posts for select to authenticated
  using (
    author_id = (select auth.uid())
    or (
      not is_hidden
      and public.author_visible(author_id)
      and not public.item_blocked('post', id)
      and (
        (loop_id is not null and exists (select 1 from public.loops l where l.id = loop_id))
        or (
          loop_id is null
          and (
            visibility = 'public'
            or (visibility = 'club' and public.is_club_member(club_id))
          )
        )
      )
    )
  );

-- RLS on posts already checks the loop (or the text post's visibility).
create or replace function public.can_see_post(p_post_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.posts p where p.id = p_post_id);
$$;

-- Posts a text post, with 0-10 photos already uploaded to
-- post-photos/<user_id>/<post_id>/. Calling again with the same id after a
-- lost reply returns it. Raises:
--   bad_text          empty, or over 2000 characters
--   not_club_member   visibility 'club' for a club the caller isn't in
--   bad_photos        over 10, or wrong positions or paths
--   too_many_posts    10 text posts in the last hour
create function public.create_text_post(
  p_post_id uuid,
  p_caption text,
  p_visibility public.loop_visibility,
  p_club_id uuid,
  p_photos jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_caption text := nullif(trim(p_caption), '');
  v_count integer;
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  if exists (select 1 from public.posts where id = p_post_id and author_id = v_uid) then
    return p_post_id;
  end if;

  if v_caption is null or char_length(v_caption) > 2000 then
    raise exception 'bad_text';
  end if;
  if p_visibility is null then
    raise exception 'bad_text';
  end if;
  if p_visibility = 'club'
    and (p_club_id is null or not public.is_club_member(p_club_id)) then
    raise exception 'not_club_member';
  end if;

  v_count := jsonb_array_length(coalesce(p_photos, '[]'::jsonb));
  if v_count > 10 or exists (
    select 1 from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) e
    where e->>'storage_path' not like v_uid::text || '/' || p_post_id::text || '/%'
      or (e->>'position')::integer not between 0 and 9
  ) then
    raise exception 'bad_photos';
  end if;

  if (
    select count(*) from public.posts
    where author_id = v_uid
      and loop_id is null
      and created_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'too_many_posts';
  end if;

  insert into public.posts (id, author_id, caption, visibility, club_id)
  values (
    p_post_id,
    v_uid,
    v_caption,
    p_visibility,
    case when p_visibility = 'club' then p_club_id end
  );

  insert into public.post_photos (post_id, storage_path, position, width, height)
  select
    p_post_id,
    e->>'storage_path',
    (e->>'position')::smallint,
    (e->>'width')::integer,
    (e->>'height')::integer
  from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) e;

  return p_post_id;
end;
$$;

revoke execute on function public.create_text_post(uuid, text, public.loop_visibility, uuid, jsonb)
  from public, anon;
grant execute on function public.create_text_post(uuid, text, public.loop_visibility, uuid, jsonb)
  to authenticated;

-- As in 20261025000500_feed_club_name.sql, plus text posts (kind 'text',
-- loop null) and two new columns, visibility and club_name, for every kind.
-- The return type changes, so it's dropped first.
drop function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz);

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
  first_comment jsonb,
  visibility public.loop_visibility,
  club_name text
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
      case when p.loop_id is null then 'text' else 'post' end::text as kind,
      p.id, p.caption, p.created_at, p.author_id,
      p.loop_id, p.stop_location as stop,
      coalesce(l.visibility, p.visibility) as vis,
      coalesce(l.club_id, p.club_id) as club
    from public.posts p
    left join public.loops l on l.id = p.loop_id
    -- A ride post whose loop the caller can't see stays out.
    where (p.loop_id is null or l.id is not null)
      and (
        (p_scope = 'post' and p.id = p_target)
        or (
          coalesce(l.visibility, p.visibility) <> 'private'
          and public.feed_scope_match(
            p_scope, p_target, p.author_id,
            coalesce(l.visibility, p.visibility), coalesce(l.club_id, p.club_id)
          )
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
      end,
      l.visibility,
      l.club_id
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
    case when o.g is null or i.stop is null then null else st_distance(i.stop, o.g) end,
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
    case when l.id is null then null else jsonb_build_object(
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
    ) end,
    (select count(*) from public.likes lk where lk.post_id = i.id),
    (select count(*) from public.comments cm where cm.post_id = i.id),
    exists (
      select 1 from public.likes lk
      where lk.post_id = i.id and lk.user_id = (select auth.uid())
    ),
    (
      select jsonb_build_object(
        'body', cm.body,
        'author', jsonb_build_object(
          'id', ca.id,
          'display_name', ca.display_name,
          'avatar_url', ca.avatar_url
        )
      )
      from public.comments cm
      join public.profiles ca on ca.id = cm.author_id
      where cm.post_id = i.id
      order by cm.created_at, cm.id
      limit 1
    ),
    i.vis,
    c.name
  from page i
  cross join origin o
  left join public.loops l on l.id = i.loop_id
  left join public.clubs c on c.id = i.club
  join public.profiles a on a.id = i.author_id
  order by i.created_at desc, i.id desc;
$$;

revoke execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) from public, anon;
grant execute on function public.feed_page(text, uuid, double precision, double precision, integer, timestamptz) to authenticated;

-- As in 20261025000600_link_preview_club_name.sql, plus text posts: their
-- own visibility, the author, caption and first photo; no loop or route.
create or replace function public.link_preview(p_kind text, p_id uuid)
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

  if p_kind = 'post' and v_loop_id is null then
    v_status := case
      when v_uid is not null and v_post.author_id = v_uid then 'ok'
      when v_post.visibility = 'public' then 'ok'
      when v_post.visibility = 'club'
        and v_uid is not null
        and public.is_club_member(v_post.club_id) then 'ok'
      when v_post.visibility = 'club' then 'club'
      else 'private'
    end;
    if v_status = 'club' then
      return jsonb_build_object(
        'status', 'club',
        'club_id', v_post.club_id,
        'club_name', (select c.name from public.clubs c where c.id = v_post.club_id)
      );
    elsif v_status <> 'ok' then
      return jsonb_build_object('status', v_status);
    end if;
    return jsonb_build_object(
      'status', 'ok',
      'kind', p_kind,
      'id', p_id,
      'club_name', (select c.name from public.clubs c where c.id = v_post.club_id),
      'author', (
        select a.display_name from public.profiles a where a.id = v_post.author_id
      ),
      'caption', v_post.caption,
      'photo', (
        select ph.storage_path from public.post_photos ph
        where ph.post_id = v_post.id
        order by ph.position
        limit 1
      )
    );
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
    'club_name', (select c.name from public.clubs c where c.id = v_loop.club_id),
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

-- As in 20261024000300_moderation.sql, with a left join so a reported text
-- post shows its text instead of looking deleted.
create or replace function public.admin_report_queue()
returns table (
  target_type public.report_target,
  target_id uuid,
  report_count bigint,
  reasons text[],
  last_reported_at timestamptz,
  preview text,
  author_id uuid,
  author_name text,
  is_hidden boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  return query
  with open as (
    select
      r.target_type, r.target_id, count(*) as n,
      array_agg(r.reason order by r.created_at desc) as reasons,
      max(r.created_at) as last_at
    from public.reports r
    where r.status = 'open'
    group by r.target_type, r.target_id
  ),
  described as (
    select
      o.*,
      case o.target_type
        when 'post' then (
          select coalesce(nullif(p.caption, ''), 'Ride on ' || l.name)
          from public.posts p left join public.loops l on l.id = p.loop_id
          where p.id = o.target_id
        )
        when 'comment' then (select c.body from public.comments c where c.id = o.target_id)
        when 'loop' then (select l.name from public.loops l where l.id = o.target_id)
        when 'user' then (select u.display_name from public.profiles u where u.id = o.target_id)
      end as preview,
      case o.target_type
        when 'post' then (select p.author_id from public.posts p where p.id = o.target_id)
        when 'comment' then (select c.author_id from public.comments c where c.id = o.target_id)
        when 'loop' then (select l.owner_id from public.loops l where l.id = o.target_id)
        when 'user' then o.target_id
      end as author_id,
      case o.target_type
        when 'post' then (select p.is_hidden from public.posts p where p.id = o.target_id)
        when 'comment' then (select c.is_hidden from public.comments c where c.id = o.target_id)
        when 'loop' then (select l.is_hidden from public.loops l where l.id = o.target_id)
        when 'user' then (select u.is_hidden from public.profiles u where u.id = o.target_id)
      end as hidden
    from open o
  )
  select
    d.target_type, d.target_id, d.n, d.reasons, d.last_at,
    -- Null preview: it was deleted since.
    d.preview, d.author_id,
    (select a.display_name from public.profiles a where a.id = d.author_id),
    coalesce(d.hidden, false)
  from described d
  order by d.n desc, d.last_at desc
  limit 100;
end;
$$;
