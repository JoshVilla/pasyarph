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

Server-side secrets (like the GraphHopper key) go in Supabase secrets, never in these files.

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

## Edge Functions

`supabase/functions/generate-loop` builds loops with GraphHopper round trips (car profile). The key lives only in Supabase secrets:

```sh
npx supabase secrets set GRAPHHOPPER_API_KEY=your-key
npx supabase functions deploy generate-loop --use-api
```

GraphHopper's free plan is for non-commercial use, about 500 credits a day, plus a per-minute limit (each round trip costs 2 credits; one Generate makes 1–3 calls). It offers no custom models, so highways and unpaved roads can't be avoided while routing. The function asks for road class and surface details instead, tries other seeds when a loop uses an expressway (or known unpaved road), and returns a warning when it can't find a clean one. A paid plan is needed before launch.

OpenRouteService was tried first and dropped: its public API timed out on round trips and waypoint loops from Isabela.

Unit tests (Deno, no install needed):

```sh
cd supabase/functions/generate-loop
npx deno test
```

Loop lengths and the expressway/unpaved thresholds are in `plan.ts`. A loop more than 25% off its target is retried with a rescaled distance. Each user can generate 30 loops per rolling hour (`consume_generate_quota`).

Notes for app code:

- `loops.route` (the full loop, which starts at the rider's home) is not readable through the API. Select `Loop.columns` instead of `*`; owners get their full route from `rpc('loop_route', {'p_loop_id': id})`.
- Geography columns come back as hex EWKB. RPCs return GeoJSON. `GeoCodec` reads both and writes EWKT.
- Storage paths: `avatars/<user_id>/...` and `post-photos/<user_id>/<post_id>/<n>.jpg`.

## Sign-in setup

Only email + password is on for now. Apple and Google are built but hidden; turn them on with `Features.socialSignIn` in `lib/core/features.dart` after steps 2 and 3.

Email + password works once the migrations are pushed. The other pieces are set in dashboards:

1. **Redirect URLs** (Supabase → Authentication → URL Configuration): add `com.pasyarph.app.dev://auth-callback` and `com.pasyarph.app://auth-callback`. Email confirmation links, password reset links and Apple sign-in on Android return to the app through these.
2. **Google:** in Google Cloud, create a *Web* OAuth client. Put its ID and secret in Supabase → Auth → Providers → Google, and its ID in `GOOGLE_WEB_CLIENT_ID` in `env/*.json`. Also create one *Android* OAuth client per flavor, with package `com.pasyarph.app.dev` / `com.pasyarph.app` and your signing SHA-1 (`cd android && ./gradlew signingReport`). Until `GOOGLE_WEB_CLIENT_ID` is set, the Google button says sign-in isn't set up.
3. **Apple:** needs an Apple Developer account. Create a Services ID and key, then enable Apple in Supabase → Auth → Providers. On Android it opens Apple's web sign-in in the browser.

## Design system

- Tokens and text styles: `lib/core/theme/`
- Shared widgets: `lib/core/widgets/` (import `widgets.dart`)
- Route line and map markers for flutter_map: `lib/core/map/`
- Widget gallery (dev flavor only): Me tab → **WIDGET GALLERY**, or `/dev/widgets`

## iOS

Only Android flavors are set up so far. The iOS bundle ID is `com.pasyarph.app` (prod). To add iOS flavors, use a Mac: create `Debug-dev`/`Release-dev`/`Debug-prod`/`Release-prod` build configurations and `dev`/`prod` schemes in Xcode. Then set the bundle ID suffix and the display name for each configuration.
