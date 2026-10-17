-- One profile per auth user, created by a trigger on sign-up.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  display_name text check (char_length(display_name) between 2 and 30),
  avatar_url text,
  bike_type public.bike_type,
  -- Town only (e.g. "Cordon, Isabela"). Never a street address.
  home_area text check (char_length(home_area) <= 80),
  onboarding_completed boolean not null default false,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Profiles hold only public-facing rider info (name, photo, bike, town),
-- so any signed-in rider can read them (feed authors, commenters).
create policy "profiles: signed-in users can read"
  on public.profiles for select to authenticated
  using (true);

create policy "profiles: users update their own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No insert/delete policies: rows are created by the trigger below and
-- removed with the auth user.

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    nullif(trim(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    )), '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
