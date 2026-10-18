-- Prompt 12: home privacy. Everyone but the owner sees loops.shared_route:
-- the route with its first and last 800 m cut off, so a loop that starts
-- at home doesn't show where home is. loops.route stays owner-only (see the
-- column grants in 20261018000400_loops.sql).

-- The route without its first and last p_trim_m meters, or null when it's
-- too short to share safely (nothing meaningful would be left).
--
-- Cut points are found on a copy with longitude scaled by cos(latitude),
-- where planar length is close to true length for a loop-sized line
-- (no spatial_ref_sys lookups needed), then scaled back.
create function public.trim_route(
  p_route extensions.geography,
  p_trim_m integer default 800
)
returns extensions.geography
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_length double precision;
  v_geom extensions.geometry;
  v_k double precision;
  v_cut double precision;
begin
  if p_route is null then
    return null;
  end if;
  v_length := extensions.st_length(p_route);
  if v_length <= 2 * p_trim_m + 200 then
    return null;
  end if;

  v_geom := p_route::extensions.geometry;
  v_k := cos(radians(extensions.st_y(extensions.st_startpoint(v_geom))));
  v_cut := p_trim_m / v_length;

  return extensions.st_scale(
    extensions.st_linesubstring(
      extensions.st_scale(v_geom, v_k, 1),
      v_cut,
      1 - v_cut
    ),
    1 / v_k,
    1
  )::extensions.geography;
end;
$$;

-- shared_route always follows route; clients can't write it (no grant).
create function public.loops_fill_shared_route()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.shared_route := public.trim_route(new.route);
  return new;
end;
$$;

create trigger loops_fill_shared_route
  before insert or update of route on public.loops
  for each row execute function public.loops_fill_shared_route();

-- Loops saved before this migration.
update public.loops set shared_route = public.trim_route(route);
