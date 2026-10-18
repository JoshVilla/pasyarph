-- Prompt 15: what generate-loop needs to build "Ride this loop" for someone
-- else's loop: the trimmed route only (never loops.route, which starts at
-- the owner's home) and the loop's stats. Runs as the caller, so it returns
-- null for loops they can't see (private, or a club they're not in).

create function public.loop_for_riding(p_loop_id uuid)
returns jsonb
language sql
stable
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'id', l.id,
    'name', l.name,
    'shared_route', st_asgeojson(l.shared_route)::jsonb,
    'distance_m', l.distance_m,
    'duration_s', l.duration_s,
    'curviness_score', l.curviness_score,
    'main_stop', l.main_stop
  )
  from public.loops l
  where l.id = p_loop_id
    and l.shared_route is not null;
$$;

revoke execute on function public.loop_for_riding(uuid) from public, anon;
grant execute on function public.loop_for_riding(uuid) to authenticated;
