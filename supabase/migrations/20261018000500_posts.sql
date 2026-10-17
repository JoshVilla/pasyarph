-- A post can be seen exactly when its loop can be seen (public, your club,
-- or your own), so posts have no visibility column of their own.
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  loop_id uuid not null references public.loops (id) on delete cascade,
  caption text check (char_length(caption) <= 2000),
  -- GPS-verified location at the main stop (not the rider's start).
  stop_location extensions.geography(Point, 4326) not null,
  created_at timestamptz not null default now()
);

create index posts_created_at_idx on public.posts (created_at desc, id desc);
create index posts_author_id_idx on public.posts (author_id);
create index posts_loop_id_idx on public.posts (loop_id);
create index posts_stop_location_idx on public.posts using gist (stop_location);

-- At most 10 photos per post: position must be 0-9 and unique per post.
create table public.post_photos (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  -- Path inside the post-photos bucket: <user_id>/<post_id>/<n>.jpg
  storage_path text not null,
  position smallint not null check (position between 0 and 9),
  width integer check (width > 0),
  height integer check (height > 0),
  unique (post_id, position)
);

create table public.likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index likes_user_id_idx on public.likes (user_id);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index comments_post_id_idx on public.comments (post_id, created_at);
create index comments_author_id_idx on public.comments (author_id);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_type public.report_target not null,
  target_id uuid not null,
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index reports_target_idx on public.reports (target_type, target_id);

-- Visibility helper: RLS on loops applies inside, so this is true only when
-- the caller can see the post's loop.
create function public.can_see_post(p_post_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.posts p
    join public.loops l on l.id = p.loop_id
    where p.id = p_post_id
  );
$$;

alter table public.posts enable row level security;
alter table public.post_photos enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;

-- posts
create policy "posts: read when the loop is visible"
  on public.posts for select to authenticated
  using (
    author_id = (select auth.uid())
    or exists (select 1 from public.loops l where l.id = loop_id)
  );

create policy "posts: users post on loops they can see"
  on public.posts for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (select 1 from public.loops l where l.id = loop_id)
  );

create policy "posts: authors update"
  on public.posts for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

create policy "posts: authors delete"
  on public.posts for delete to authenticated
  using (author_id = (select auth.uid()));

-- Only the caption can change after posting.
revoke update on public.posts from anon, authenticated;
grant update (caption) on public.posts to authenticated;

-- post_photos
create policy "post_photos: read with the post"
  on public.post_photos for select to authenticated
  using (public.can_see_post(post_id));

create policy "post_photos: authors add to their posts"
  on public.post_photos for insert to authenticated
  with check (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = (select auth.uid())
    )
    and storage_path like (select auth.uid())::text || '/%'
  );

create policy "post_photos: authors delete"
  on public.post_photos for delete to authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = (select auth.uid())
    )
  );

-- likes
create policy "likes: read with the post"
  on public.likes for select to authenticated
  using (public.can_see_post(post_id));

create policy "likes: users like posts they can see"
  on public.likes for insert to authenticated
  with check (user_id = (select auth.uid()) and public.can_see_post(post_id));

create policy "likes: users remove their likes"
  on public.likes for delete to authenticated
  using (user_id = (select auth.uid()));

-- comments
create policy "comments: read with the post"
  on public.comments for select to authenticated
  using (public.can_see_post(post_id));

create policy "comments: users comment on posts they can see"
  on public.comments for insert to authenticated
  with check (author_id = (select auth.uid()) and public.can_see_post(post_id));

create policy "comments: authors update"
  on public.comments for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

create policy "comments: authors delete"
  on public.comments for delete to authenticated
  using (author_id = (select auth.uid()));

revoke update on public.comments from anon, authenticated;
grant update (body) on public.comments to authenticated;

-- reports: write-only for users; admins review them in the dashboard.
create policy "reports: users file reports"
  on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));

create policy "reports: users see their own reports"
  on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));
