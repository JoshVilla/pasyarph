# Pasyar (display name) / PasyarPH (handles)
Motorcycle loop-route app for Filipino riders. A rider picks how long they want to ride, taps Generate, and gets a loop that starts and ends at their location. Shuffle gives a new loop. Each loop has a main stop (viewpoint, falls, food spot). At the stop, the rider can post up to 10 photos (GPS-verified) with the route attached. Other riders see posts in a newsfeed and tap "Ride this loop". Riders can also create custom loops by tapping points on the map and share them publicly, to a club, or privately.

## Stack
- Flutter (latest stable), Provider for state, go_router for navigation
- Supabase: Auth, Postgres + PostGIS, Storage, Edge Functions (Deno/TypeScript)
- GraphHopper routing API called ONLY from Edge Functions, never from the app (OpenRouteService was dropped: its public API timed out)
- flutter_map with vector/raster tiles from maptiler, key in --dart-define
- geolocator, flutter_tts, camera/image_picker, wakelock_plus

## Design (source of truth: design/)
- design/DESIGN.md has the exact colors, typography, spacing, radii, shadows, and component specs. Use ONLY those tokens.
- design/screenshots/ has every approved screen as a PNG; design/mockups/ has the same screens as HTML with exact measurements.
- Before building any screen that has a mockup, open its screenshot AND its HTML, list the elements top to bottom, and build exactly that. Do not redesign, restyle, or "improve" it.
- Screens without a mockup (forgot/reset password, check-your-email, comments, clubs, profile, settings) must reuse the DESIGN.md components and look like they belong to the same app.
- After building a screen, add a 390x844 golden test and compare it with the screenshot; fix any differences before finishing.
- The maps in the mockups are illustrations: use a real flutter_map full-screen behind the controls, but keep the route line, markers, and controls exactly as drawn.
- Touch targets ≥ 44px (riders may wear gloves); navigation screens use big, glanceable text.
- Bottom tabs: Ride, Feed, Create, Me.

## Rules
- Folder structure: lib/core (theme, router, env), lib/data (models, repositories), lib/features/<feature>/(screens, widgets, providers)
- All secrets via --dart-define or Supabase secrets. Never commit keys.
- Every Supabase table has Row Level Security on.
- Shared routes must have the first and last 800 m trimmed (home privacy).
- Disable typing and posting while the phone is moving faster than 10 km/h.
- Write small, testable commits. Add unit tests for pure logic (geometry, scoring, parsing).
