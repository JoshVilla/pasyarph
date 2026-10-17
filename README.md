# Pasyar

Motorcycle loop-route app for Filipino riders. Project context and rules live in [CLAUDE.md](CLAUDE.md); the approved design is in [design/](design/).

## Flavors

| Flavor | Android app ID       | App name   |
|--------|----------------------|------------|
| dev    | `com.pasyarph.app.dev` | Pasyar Dev |
| prod   | `com.pasyarph.app`     | Pasyar     |

The two flavors have different app IDs, so you can install both on one phone.

## Environment

The app reads its config from `--dart-define` values at build time:

| Key                 | Example |
|---------------------|---------|
| `SUPABASE_URL`      | `https://YOUR-PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon (public) key |
| `MAP_TILE_URL`      | `https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key={key}` |
| `MAP_TILE_KEY`      | MapTiler key |

If any value is missing, the app stops at startup with a `MissingEnvError` that lists the missing keys (see `lib/core/env.dart`).

Create one file per flavor from the template. These files are gitignored, so never commit real keys:

```sh
cp env/example.json env/dev.json
cp env/example.json env/prod.json
# then fill in the real values
```

Server-side secrets (like the OpenRouteService key) go in Supabase secrets, never in these files.

## Run

```sh
flutter pub get

# dev
flutter run --flavor dev --dart-define-from-file=env/dev.json

# prod
flutter run --flavor prod --dart-define-from-file=env/prod.json
```

In VS Code, pick **Pasyar Dev**, **Pasyar Prod** or **Pasyar Prod (release)** in the Run and Debug panel (`.vscode/launch.json`).

You can also pass the values one by one instead of using a file: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## Build

```sh
flutter build apk --flavor dev --dart-define-from-file=env/dev.json
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json
```

## Test

```sh
flutter test

# after an intended visual change, regenerate the golden images
flutter test --update-goldens
```

Golden images live next to the tests in `goldens/windows/` and use the real bundled fonts. Compare them with `design/screenshots/` before accepting a change.

## Database (Supabase)

Migrations are in `supabase/migrations/`, and pgTAP tests are in `supabase/tests/`.

Apply them to the hosted project (asks for the database password):

```sh
npx supabase login
npx supabase link --project-ref cxrbgnbwwqgojegcqlcl
npx supabase db push
```

Run the database tests against a local stack (needs Docker):

```sh
npx supabase start
npx supabase test db
```

Notes for app code:

- `loops.route` (the full loop, which starts at the rider's home) is not readable through the API. Select `Loop.columns` instead of `*`; owners get their full route from `rpc('loop_route', {'p_loop_id': id})`.
- Geography columns come back as hex EWKB. RPCs return GeoJSON. `GeoCodec` reads both and writes EWKT.
- Storage paths: `avatars/<user_id>/...` and `post-photos/<user_id>/<post_id>/<n>.jpg`.

## Design system

- Tokens and text styles: `lib/core/theme/`
- Shared widgets: `lib/core/widgets/` (import `widgets.dart`)
- Route line and map markers for flutter_map: `lib/core/map/`
- Widget gallery (dev flavor only): Me tab → **WIDGET GALLERY**, or `/dev/widgets`

## iOS

Only Android flavors are set up so far. The iOS bundle ID is `com.pasyarph.app` (prod). To add iOS flavors, use a Mac: create `Debug-dev`/`Release-dev`/`Debug-prod`/`Release-prod` build configurations and `dev`/`prod` schemes in Xcode. Then set the bundle ID suffix and the display name for each configuration.
