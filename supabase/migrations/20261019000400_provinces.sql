-- Feed cards say which province a loop is in ("Ifugao"), so riders know
-- where it is before tapping RIDE IT. Provinces come from geoBoundaries
-- (NAMRIA / PSA, CC BY 3.0 IGO), loaded by tools/provinces (see its
-- README); the API never writes them.

create table public.provinces (
  id serial primary key,
  name text not null,
  area extensions.geography(MultiPolygon, 4326) not null
);

create index provinces_area_idx on public.provinces using gist (area);

alter table public.provinces enable row level security;

create policy "provinces: signed-in users can read"
  on public.provinces for select to authenticated
  using (true);

-- The province a point is in; near a coast or border (boundaries are
-- simplified to ~250 m), the closest one within 5 km. Null offshore.
create function public.province_at(p_point extensions.geography)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select pr.name from public.provinces pr
      where extensions.st_covers(pr.area, p_point)
      limit 1
    ),
    (
      select pr.name from public.provinces pr
      where extensions.st_dwithin(pr.area, p_point, 5000)
      order by extensions.st_distance(pr.area, p_point)
      limit 1
    )
  );
$$;

-- A loop's province: where its main stop is, or the middle of the route.
-- Never the start (the owner's home).
create function public.loop_province(
  p_route extensions.geography,
  p_main_stop jsonb
)
returns text
language sql
stable
set search_path = ''
as $$
  select public.province_at(
    case
      when p_main_stop ? 'lat' and p_main_stop ? 'lng' then extensions.st_setsrid(
        extensions.st_makepoint(
          (p_main_stop->>'lng')::double precision,
          (p_main_stop->>'lat')::double precision
        ),
        4326
      )::extensions.geography
      else extensions.st_lineinterpolatepoint(
        p_route::extensions.geometry, 0.5
      )::extensions.geography
    end
  );
$$;

alter table public.loops add column province text;
grant select (province) on public.loops to authenticated;

create function public.loops_fill_province()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.province := public.loop_province(new.route, new.main_stop);
  return new;
end;
$$;

create trigger loops_fill_province
  before insert or update of route, main_stop on public.loops
  for each row execute function public.loops_fill_province();

-- feed_near with the loop's province (same signature and columns).
create or replace function public.feed_near(
  lat double precision,
  lng double precision,
  radius_m double precision default 50000,
  page_limit integer default 20,
  page_cursor timestamptz default null
)
returns table (
  id uuid,
  caption text,
  created_at timestamptz,
  stop_location jsonb,
  distance_away_m double precision,
  author jsonb,
  photos jsonb,
  loop jsonb,
  like_count bigint,
  comment_count bigint,
  liked_by_me boolean,
  first_comment jsonb
)
language sql
stable
set search_path = public, extensions
as $$
  with origin as (
    select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g
  )
  select
    p.id,
    p.caption,
    p.created_at,
    st_asgeojson(p.stop_location)::jsonb,
    st_distance(p.stop_location, o.g),
    jsonb_build_object(
      'id', a.id,
      'display_name', a.display_name,
      'avatar_url', a.avatar_url
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ph.id,
            'post_id', ph.post_id,
            'storage_path', ph.storage_path,
            'position', ph.position,
            'width', ph.width,
            'height', ph.height
          )
          order by ph.position
        )
        from public.post_photos ph
        where ph.post_id = p.id
      ),
      '[]'::jsonb
    ),
    jsonb_build_object(
      'id', l.id,
      'owner_id', l.owner_id,
      'name', l.name,
      'source', l.source,
      'shared_route', st_asgeojson(l.shared_route)::jsonb,
      'distance_m', l.distance_m,
      'duration_s', l.duration_s,
      'curviness_score', l.curviness_score,
      'main_stop', l.main_stop,
      'province', l.province,
      'visibility', l.visibility,
      'club_id', l.club_id,
      'created_at', l.created_at
    ),
    (select count(*) from public.likes lk where lk.post_id = p.id),
    (select count(*) from public.comments c where c.post_id = p.id),
    exists (
      select 1 from public.likes lk
      where lk.post_id = p.id and lk.user_id = (select auth.uid())
    ),
    (
      select jsonb_build_object(
        'body', c.body,
        'author', jsonb_build_object(
          'id', ca.id,
          'display_name', ca.display_name,
          'avatar_url', ca.avatar_url
        )
      )
      from public.comments c
      join public.profiles ca on ca.id = c.author_id
      where c.post_id = p.id
      order by c.created_at, c.id
      limit 1
    )
  from public.posts p
  cross join origin o
  join public.loops l on l.id = p.loop_id
  join public.profiles a on a.id = p.author_id
  where st_dwithin(p.stop_location, o.g, radius_m)
    and (page_cursor is null or p.created_at < page_cursor)
  order by p.created_at desc, p.id desc
  limit least(greatest(page_limit, 1), 50);
$$;
