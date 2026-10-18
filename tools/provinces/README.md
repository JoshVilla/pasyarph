# Provinces

Feed cards show which province a loop is in ("Ifugao"). Postgres looks it up from the `provinces` table (migration `20261019000400_provinces.sql`): the province around the loop's main stop, or around the middle of the route when there's no stop. Never the start, which is often the rider's home.

Boundaries: geoBoundaries, Philippines ADM2 (provinces), from NAMRIA, PSA and OCHA Philippines, licensed CC BY 3.0 IGO. Credit them wherever the app lists data sources.

## Load (once, and when provinces change)

1. Download the simplified boundaries (about 3 MB):
   <https://github.com/wmgeolab/geoBoundaries/raw/41af8f1/releaseData/gbOpen/PHL/ADM2/geoBoundaries-PHL-ADM2_simplified.geojson>

2. Build the SQL (`tools/provinces/out/provinces.sql`, gitignored, about 730 KB):

   ```sh
   npx deno run --allow-read --allow-write tools/provinces/build_provinces.ts path/to/geoBoundaries-PHL-ADM2_simplified.geojson
   ```

   Boundaries are simplified to about 250 m, and names are tidied: the four Metro Manila districts become "Metro Manila", Compostela Valley becomes "Davao de Oro", and Isabela City and Cotabato City go with Basilan and Maguindanao.

3. In Supabase → SQL Editor, open `provinces.sql`, paste it all and run it. It replaces the table's rows and fills the province of loops saved before.

4. Check it:

   ```sql
   select count(*) from public.provinces;  -- 82
   select public.province_at(extensions.st_geogfromtext('SRID=4326;POINT(121.08 16.92)'));  -- Ifugao
   ```
