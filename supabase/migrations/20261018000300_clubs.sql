create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 60),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.club_members (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.club_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create index club_members_user_id_idx on public.club_members (user_id);

-- Membership check used by RLS. Security definer so policies on
-- club_members don't recurse into themselves.
create function public.is_club_member(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.club_members
    where club_id = p_club_id and user_id = (select auth.uid())
  );
$$;

create function public.is_club_owner(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.clubs
    where id = p_club_id and owner_id = (select auth.uid())
  );
$$;

-- The creator becomes the club's owner member.
create function public.add_club_owner_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.club_members (club_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

create trigger on_club_created
  after insert on public.clubs
  for each row execute function public.add_club_owner_member();

alter table public.clubs enable row level security;
alter table public.club_members enable row level security;

-- Club names are visible to signed-in riders so an invite link can show
-- which club it is for.
create policy "clubs: signed-in users can read"
  on public.clubs for select to authenticated
  using (true);

create policy "clubs: users create clubs they own"
  on public.clubs for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "clubs: owners update"
  on public.clubs for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "clubs: owners delete"
  on public.clubs for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy "club_members: members see their club's members"
  on public.club_members for select to authenticated
  using (user_id = (select auth.uid()) or public.is_club_member(club_id));

-- Joining = adding yourself as a member (via the club's invite link).
-- Owner rows are only created by the trigger above.
create policy "club_members: users join as member"
  on public.club_members for insert to authenticated
  with check (user_id = (select auth.uid()) and role = 'member');

-- Members can leave; owners can remove members.
create policy "club_members: leave or owner removes"
  on public.club_members for delete to authenticated
  using (
    (user_id = (select auth.uid()) and role = 'member')
    or (public.is_club_owner(club_id) and role = 'member')
  );
