# Places (main stops and fuel)

generate-loop picks each loop's main stop (viewpoint, waterfall, attraction, food) and the fuel stations along it from the `places` table (migration `20261018000900_places.sql`). The table is built from OpenStreetMap, not queried live: the public Overpass servers were too slow and too often down to call while a rider waits.

Data © OpenStreetMap contributors, available under the ODbL. The map already credits OpenStreetMap.

## Refresh (every month or two)

1. Download the Philippines extract (about 600 MB) from Geofabrik:
   <https://download.geofabrik.de/asia/philippines-latest.osm.pbf>

2. Extract the places to `tools/places/out/places.csv` (gitignored). Takes a few minutes:

   ```sh
   npx deno run --allow-read --allow-write --allow-env --allow-sys tools/places/extract_places.ts path/to/philippines-latest.osm.pbf
   ```

3. In Supabase → SQL Editor, empty the table:

   ```sql
   truncate public.places;
   ```

4. In Supabase → Table Editor → `places` → **Insert → Import data from CSV**, choose `tools/places/out/places.csv`, and import. The columns are `osm_id, name, type, lat, lng`; `location` is computed from `lat`/`lng`.

5. Check it:

   ```sql
   select type, count(*) from public.places group by type order by 2 desc;
   ```

Which OSM tags count as places is in `supabase/functions/generate-loop/osm_places.ts`. Stop-picking rules (35–65% around the loop, 1.5 km from the road) are in `stops.ts`.
