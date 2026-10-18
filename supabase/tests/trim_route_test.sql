-- Checks public.trim_route (Prompt 12). Run in the Supabase SQL editor after
-- 20261019000200_trim_route.sql; it changes nothing. Prints
-- "trim_route: all checks passed" or fails on the first broken check.
--
-- The test loop is a 4.4 km x 4.4 km square from Cordon, Isabela: north,
-- east, south, then west back to the start. The first leg runs north and
-- the last one west, so both the latitude and longitude directions are
-- checked.
do $$
declare
  v_route extensions.geography := extensions.st_geogfromtext(
    'SRID=4326;LINESTRING(121.457 16.672, 121.457 16.712, 121.4986 16.712, '
    '121.4986 16.672, 121.457 16.672)'
  );
  v_trimmed extensions.geography := public.trim_route(v_route);
  v_start extensions.geography :=
    extensions.st_startpoint(v_route::extensions.geometry)::extensions.geography;
  v_from_start double precision;
  v_from_end double precision;
  v_lost double precision;
begin
  assert v_trimmed is not null, 'a 17 km loop should be trimmed, not dropped';

  v_from_start := extensions.st_distance(
    v_start,
    extensions.st_startpoint(v_trimmed::extensions.geometry)::extensions.geography
  );
  v_from_end := extensions.st_distance(
    v_start,
    extensions.st_endpoint(v_trimmed::extensions.geometry)::extensions.geography
  );
  v_lost := extensions.st_length(v_route) - extensions.st_length(v_trimmed);

  assert v_from_start between 780 and 820,
    format('trimmed route should start ~800 m from home, starts %s m away', round(v_from_start));
  assert v_from_end between 780 and 820,
    format('trimmed route should end ~800 m from home, ends %s m away', round(v_from_end));
  assert v_lost between 1560 and 1640,
    format('trimming should remove ~1600 m, removed %s m', round(v_lost));

  -- Nothing left to share safely: null instead of a stub near home.
  assert public.trim_route(extensions.st_geogfromtext(
    'SRID=4326;LINESTRING(121.457 16.672, 121.457 16.680, 121.457 16.672)'
  )) is null, 'a 1.8 km out-and-back should not be shared';
  assert public.trim_route(null) is null, 'null in, null out';

  -- A custom trim distance.
  assert extensions.st_distance(
    v_start,
    extensions.st_startpoint(public.trim_route(v_route, 1500)::extensions.geometry)::extensions.geography
  ) between 1470 and 1530, 'trim_m = 1500 should start ~1500 m from home';

  raise notice 'trim_route: all checks passed (starts % m, ends % m from home)',
    round(v_from_start), round(v_from_end);
end;
$$;
