-- Prompt 20: reports, blocking, and hiding content.
--
-- Hidden content (is_hidden, set by an admin) and content of riders you
-- blocked are filtered out by the RLS policies of loops, posts and
-- comments. feed_near, feed_page, loops_near, loop_for_riding and saved
-- loops all run as the caller, so they follow without changes; only
-- link_preview (security definer) checks them itself, below.
--
-- Riders always still see their own content, hidden or not.

-- Hidden by an admin -------------------------------------------------------------------

alter table public.loops add column is_hidden boolean not null default false;
alter table public.posts add column is_hidden boolean not null default false;
alter table public.comments add column is_hidden boolean not null default false;
-- A hidden rider: all their loops, posts and comments are hidden.
alter table public.profiles add column is_hidden boolean not null default false;

-- loops, posts and comments only grant updates on other columns, but
-- profiles let riders update their whole row: keep is_hidden as it was
-- unless an admin function (running as postgres) or the service role
-- changes it.
create function public.profiles_keep_is_hidden()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_hidden is distinct from old.is_hidden
     and current_user not in ('postgres', 'service_role', 'supabase_admin') then
    new.is_hidden := old.is_hidden;
  end if;
  return new;
end;
$$;

create trigger profiles_keep_is_hidden
  before update on public.profiles
  for each row execute function public.profiles_keep_is_hidden();

-- Blocking -------------------------------------------------------------------------------

-- The blocker no longer sees the blocked rider's loops, posts and comments.
create table public.blocks (
  blocker_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

create index blocks_blocked_id_idx on public.blocks (blocked_id);

alter table public.blocks enable row level security;

create policy "blocks: users see who they blocked"
  on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));

create policy "blocks: users block as themselves"
  on public.blocks for insert to authenticated
  with check (blocker_id = (select auth.uid()));

create policy "blocks: users unblock"
  on public.blocks for delete to authenticated
  using (blocker_id = (select auth.uid()));

revoke all on public.blocks from anon;
revoke update on public.blocks from authenticated;

-- Blocking someone ends following in both directions.
create function public.blocks_drop_follows()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and followee_id = new.blocked_id)
     or (follower_id = new.blocked_id and followee_id = new.blocker_id);
  return new;
end;
$$;

create trigger blocks_drop_follows
  after insert on public.blocks
  for each row execute function public.blocks_drop_follows();

-- Content by [p_author] can be shown to the caller: the rider isn't hidden
-- and the caller hasn't blocked them. Works signed out too (no blocks).
create function public.author_visible(p_author uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
      select 1 from public.profiles p where p.id = p_author and p.is_hidden
    )
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = (select auth.uid()) and b.blocked_id = p_author
    );
$$;

revoke execute on function public.author_visible(uuid) from public;
grant execute on function public.author_visible(uuid) to anon, authenticated;

-- Blocked riders can't follow the rider who blocked them (or be followed).
drop policy "follows: users follow as themselves" on public.follows;
create policy "follows: users follow as themselves"
  on public.follows for insert to authenticated
  with check (
    follower_id = (select auth.uid())
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = follower_id and b.blocked_id = followee_id)
         or (b.blocker_id = followee_id and b.blocked_id = follower_id)
    )
  );

-- RLS: hidden and blocked content disappears --------------------------------------------

drop policy "loops: read public, own, or your clubs'" on public.loops;
create policy "loops: read public, own, or your clubs'"
  on public.loops for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (
      not is_hidden
      and public.author_visible(owner_id)
      and (
        visibility = 'public'
        or (visibility = 'club' and public.is_club_member(club_id))
      )
    )
  );

-- The loop check (RLS on loops) also hides posts on hidden loops.
drop policy "posts: read when the loop is visible" on public.posts;
create policy "posts: read when the loop is visible"
  on public.posts for select to authenticated
  using (
    author_id = (select auth.uid())
    or (
      not is_hidden
      and public.author_visible(author_id)
      and exists (select 1 from public.loops l where l.id = loop_id)
    )
  );

drop policy "comments: read with the post" on public.comments;
create policy "comments: read with the post"
  on public.comments for select to authenticated
  using (
    public.can_see_post(post_id)
    and (
      author_id = (select auth.uid())
      or (not is_hidden and public.author_visible(author_id))
    )
  );

-- Reports --------------------------------------------------------------------------------

-- One report per rider per thing (reporting again changes nothing). Users
-- still only insert and read their own; admins resolve them below.
delete from public.reports r
using public.reports newer
where newer.reporter_id = r.reporter_id
  and newer.target_type = r.target_type
  and newer.target_id = r.target_id
  and (newer.created_at, newer.id) > (r.created_at, r.id);

alter table public.reports
  add column status text not null default 'open'
    check (status in ('open', 'hidden', 'dismissed')),
  add column resolved_at timestamptz,
  add column resolved_by uuid references public.profiles (id) on delete set null,
  add constraint reports_once unique (reporter_id, target_type, target_id);

create index reports_open_idx on public.reports (created_at) where status = 'open';

-- Reporters can't mark their own reports resolved.
revoke update on public.reports from anon, authenticated;

-- Admins ---------------------------------------------------------------------------------

-- Who can review reports. Add one in the SQL editor:
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'you@example.com';
create table public.admins (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- RLS on and no policies: only the functions below read it.
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins a where a.user_id = (select auth.uid())
  );
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Open reports grouped by what was reported, most reported first: what it
-- is (caption, comment, loop or rider name), whose it is, and whether it's
-- already hidden. Admins only.
create function public.admin_report_queue()
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
          from public.posts p join public.loops l on l.id = p.loop_id
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

revoke execute on function public.admin_report_queue() from public, anon;
grant execute on function public.admin_report_queue() to authenticated;

-- hide / unhide a loop, post, comment or rider, or dismiss its reports.
-- hide and dismiss close the open reports about it. Admins only.
create function public.admin_moderate(
  p_target_type public.report_target,
  p_target_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hide boolean;
begin
  if not public.is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  if p_action not in ('hide', 'unhide', 'dismiss') then
    raise exception 'unknown action %', p_action using errcode = '22023';
  end if;

  if p_action in ('hide', 'unhide') then
    v_hide := p_action = 'hide';
    case p_target_type
      when 'post' then update public.posts set is_hidden = v_hide where id = p_target_id;
      when 'comment' then update public.comments set is_hidden = v_hide where id = p_target_id;
      when 'loop' then update public.loops set is_hidden = v_hide where id = p_target_id;
      when 'user' then update public.profiles set is_hidden = v_hide where id = p_target_id;
    end case;
  end if;

  if p_action in ('hide', 'dismiss') then
    update public.reports
    set status = case p_action when 'hide' then 'hidden' else 'dismissed' end,
        resolved_at = now(),
        resolved_by = (select auth.uid())
    where target_type = p_target_type
      and target_id = p_target_id
      and status = 'open';
  end if;
end;
$$;

revoke execute on function public.admin_moderate(public.report_target, uuid, text) from public, anon;
grant execute on function public.admin_moderate(public.report_target, uuid, text) to authenticated;

-- Share links: hidden and blocked look like deleted ------------------------------------
-- As in 20261024000100_share_links.sql, plus the is_hidden and
-- author_visible checks.
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
    -- Hidden or blocked, unless it's the caller's own.
    if v_post.author_id is distinct from v_uid
       and (v_post.is_hidden or not public.author_visible(v_post.author_id)) then
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
  if v_loop.owner_id is distinct from v_uid
     and (v_loop.is_hidden or not public.author_visible(v_loop.owner_id)) then
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
