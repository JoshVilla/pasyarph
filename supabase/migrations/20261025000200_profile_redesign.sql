-- Me tab redesign: username, bio and a cover photo on profiles, a covers
-- bucket, and profile stats other riders can see.

-- Profiles --------------------------------------------------------------------------------

alter table public.profiles
  -- Lowercase letters, numbers, dot and underscore, 3-20 characters.
  add column username text
    constraint profiles_username_format check (username ~ '^[a-z0-9._]{3,20}$'),
  add column bio text
    constraint profiles_bio_length check (char_length(bio) <= 150),
  -- Public URL of covers/<user_id>/cover_<timestamp>.jpg.
  add column cover_url text
    constraint profiles_cover_url_length check (char_length(cover_url) <= 1000);

-- Usernames are unique (stored lowercase, see the check above).
create unique index profiles_username_key on public.profiles (username);

-- Riders already update their own row ("profiles: users update their
-- own"); RLS needs nothing new. Signed-in riders can read every profile.

-- Covers bucket ---------------------------------------------------------------------------

-- Public read by URL; riders write only covers/<their id>/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('covers', 'covers', true, 5 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "covers: users read their own folder"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "covers: users upload to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "covers: users replace their own files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "covers: users delete their own files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- A rider's profile -----------------------------------------------------------------------

-- rider_profile() gains username, bio and cover_url, and the profile stats
-- (rides are only readable by their owner, hence security definer; only
-- totals leave it). Its return type changes, so drop and recreate.
drop function public.rider_profile(uuid);

create function public.rider_profile(p_user_id uuid)
returns table (
  id uuid,
  display_name text,
  username text,
  bio text,
  avatar_url text,
  cover_url text,
  bike_type public.bike_type,
  home_area text,
  follower_count bigint,
  following_count bigint,
  followed_by_me boolean,
  ridden_m bigint,
  loops_ridden bigint,
  posts bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    pr.id, pr.display_name, pr.username, pr.bio, pr.avatar_url, pr.cover_url,
    pr.bike_type, pr.home_area,
    (select count(*) from public.follows f where f.followee_id = pr.id),
    (select count(*) from public.follows f where f.follower_id = pr.id),
    exists (
      select 1 from public.follows f
      where f.followee_id = pr.id and f.follower_id = (select auth.uid())
    ),
    coalesce((select sum(r.ridden_m) from public.rides r where r.owner_id = pr.id), 0)::bigint,
    (
      select count(*) from public.rides r
      where r.owner_id = pr.id and r.ridden_m >= r.loop_distance_m * 0.25
    ),
    (
      select count(*) from public.posts p
      where p.author_id = pr.id
        and (p.author_id = (select auth.uid()) or not p.is_hidden)
    )
  from public.profiles pr
  where pr.id = p_user_id
    -- A hidden rider looks gone, except to themselves.
    and (pr.id = (select auth.uid()) or not pr.is_hidden);
$$;

revoke execute on function public.rider_profile(uuid) from public, anon;
grant execute on function public.rider_profile(uuid) to authenticated;
