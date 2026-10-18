-- Places from OpenStreetMap (© OpenStreetMap contributors, ODbL) used to
-- pick a loop's main stop and the fuel stations along it. Filled from
-- tools/places/out/places.csv (see tools/places/README.md); the API never
-- writes here.

create table public.places (
  -- "n123" / "w456" / "r789": OSM element type + id.
  osm_id text primary key,
  name text,
  type text not null
    check (type in ('viewpoint', 'waterfall', 'attraction', 'food', 'fuel')),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
    ) stored
);

create index places_location_idx on public.places using gist (location);

alter table public.places enable row level security;

-- Public map data: any signed-in rider may read it. No write policies.
create policy "Signed-in users can read places"
  on public.places for select
  to authenticated
  using (true);

-- Places within radius_m (max 5 km) of a GeoJSON LineString, e.g. a loop.
-- Runs as the caller, so RLS applies.
create function public.places_along(
  route jsonb,
  radius_m double precision default 1500
)
returns table (
  name text,
  type text,
  lat double precision,
  lng double precision
)
language sql
stable
set search_path = public, extensions
as $$
  with line as (
    select st_setsrid(st_geomfromgeojson(route::text), 4326)::geography as g
  )
  select p.name, p.type, p.lat, p.lng
  from public.places p, line
  where st_dwithin(p.location, line.g, least(radius_m, 5000))
  limit 3000;
$$;

revoke all on function public.places_along(jsonb, double precision) from public, anon;
grant execute on function public.places_along(jsonb, double precision) to authenticated;
