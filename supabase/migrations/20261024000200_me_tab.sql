-- Prompt 19: the Me tab. Saved loops, and the totals on the profile header.
-- Deleting an account is done by the delete-account Edge Function: every
-- table cascades from auth.users → profiles, so it only has to remove the
-- user's storage files and then the user.

-- Loops a rider saved to ride later (from a post's ⋯ menu).
create table public.saved_loops (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  loop_id uuid not null references public.loops (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, loop_id)
);

create index saved_loops_user_created_idx on public.saved_loops (user_id, created_at desc);
create index saved_loops_loop_id_idx on public.saved_loops (loop_id);

alter table public.saved_loops enable row level security;

create policy "saved_loops: users read their own"
  on public.saved_loops for select to authenticated
  using (user_id = (select auth.uid()));

-- Only loops the rider can see (loops RLS applies inside the exists).
create policy "saved_loops: users save loops they can see"
  on public.saved_loops for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.loops l where l.id = loop_id)
  );

create policy "saved_loops: users remove their own"
  on public.saved_loops for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.saved_loops from anon;
revoke update on public.saved_loops from authenticated;

-- The profile header: km ridden and loops ridden (rides that covered at
-- least a quarter of the loop, as for posting), and posts.
create function public.my_totals()
returns table (ridden_m bigint, loops_ridden bigint, posts bigint)
language sql
stable
set search_path = ''
as $$
  select
    coalesce((
      select sum(r.ridden_m) from public.rides r
      where r.owner_id = (select auth.uid())
    ), 0)::bigint,
    (
      select count(*) from public.rides r
      where r.owner_id = (select auth.uid())
        and r.ridden_m >= r.loop_distance_m * 0.25
    ),
    (
      select count(*) from public.posts p
      where p.author_id = (select auth.uid())
    );
$$;

revoke execute on function public.my_totals() from public, anon;
grant execute on function public.my_totals() to authenticated;
