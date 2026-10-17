create table public.loops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  source public.loop_source not null,
  -- Full route, starting and ending at the owner's start point (often home).
  -- Only the owner can read it; see the column grants below.
  route extensions.geography(LineString, 4326) not null,
  -- Route with the first and last 800 m trimmed. What everyone else sees.
  -- Filled by a trigger (Prompt 12); null until then.
  shared_route extensions.geography(LineString, 4326),
  distance_m integer not null check (distance_m >= 0),
  duration_s integer not null check (duration_s >= 0),
  curviness_score real check (curviness_score >= 0),
  -- {name, type, lat, lng}
  main_stop jsonb check (
    main_stop is null
    or (jsonb_typeof(main_stop) = 'object' and main_stop ? 'lat' and main_stop ? 'lng')
  ),
  visibility public.loop_visibility not null default 'public',
  club_id uuid references public.clubs (id),
  created_at timestamptz not null default now(),
  constraint loops_club_visibility check ((visibility = 'club') = (club_id is not null))
);

create index loops_owner_id_idx on public.loops (owner_id);
create index loops_club_id_idx on public.loops (club_id) where club_id is not null;
create index loops_shared_route_idx on public.loops using gist (shared_route);

-- When a club is deleted, its loops become private to their owners instead
-- of disappearing.
create function public.privatize_club_loops()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.loops
  set visibility = 'private', club_id = null
  where club_id = old.id;
  return old;
end;
$$;

create trigger on_club_deleted
  before delete on public.clubs
  for each row execute function public.privatize_club_loops();

alter table public.loops enable row level security;

create policy "loops: read public, own, or your clubs'"
  on public.loops for select to authenticated
  using (
    owner_id = (select auth.uid())
    or visibility = 'public'
    or (visibility = 'club' and public.is_club_member(club_id))
  );

create policy "loops: users create their own"
  on public.loops for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and (visibility <> 'club' or public.is_club_member(club_id))
  );

create policy "loops: owners update"
  on public.loops for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and (visibility <> 'club' or public.is_club_member(club_id))
  );

create policy "loops: owners delete"
  on public.loops for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Home privacy: nobody reads loops.route through the API, not even the
-- owner (column grants can't depend on the row). Owners get their full
-- route from public.loop_route(). Clients must list columns explicitly;
-- `select *` on loops is denied.
revoke select, insert, update on public.loops from anon, authenticated;

grant select (
  id, owner_id, name, source, shared_route, distance_m, duration_s,
  curviness_score, main_stop, visibility, club_id, created_at
) on public.loops to authenticated;

-- id is insertable so offline drafts can pick their id before upload.
grant insert (
  id, name, source, route, distance_m, duration_s, curviness_score, main_stop,
  visibility, club_id
) on public.loops to authenticated;

grant update (
  name, route, distance_m, duration_s, curviness_score, main_stop,
  visibility, club_id
) on public.loops to authenticated;

-- The owner's full route as GeoJSON, or null for anyone else.
create function public.loop_route(p_loop_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select extensions.st_asgeojson(l.route)::jsonb
  from public.loops l
  where l.id = p_loop_id and l.owner_id = (select auth.uid());
$$;

revoke execute on function public.loop_route(uuid) from public, anon;
grant execute on function public.loop_route(uuid) to authenticated;
