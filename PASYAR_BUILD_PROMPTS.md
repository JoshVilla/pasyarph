# Pasyar — Build Prompts (feature by feature)

Paste these into Claude Code (or Windsurf) **one at a time, in order**.

**First, copy the `design/` folder from this package into your repo root.** It holds the approved screens (`design/screenshots/*.png`, `design/mockups/*.html`) and the design spec (`design/DESIGN.md`). Every UI prompt points the agent at these files so the app matches the mockups.

After each prompt:

1. Run the app on a real Android device (GPS features don't test well on the emulator).
2. Check the **Done when** list. For UI prompts, put your phone next to the screenshot and compare.
3. Commit (`git commit -m "feat: <prompt number + name>"`) before moving to the next prompt.

If something breaks, fix it in the same step before continuing. Don't stack prompts on top of a broken build.

---

## Stack decisions (edit before you start)

| Area | Choice | Why |
|---|---|---|
| App | Flutter, Provider for state | What you already know |
| Backend | Supabase (Postgres + PostGIS, Auth, Storage, Edge Functions) | PostGIS handles route lines, "loops near you", and distance queries natively |
| Routing | GraphHopper (round trip, directions) via a Supabase Edge Function; places from the Overpass API (OSM) | Keeps the API key off the phone; lets you cache and rate-limit |
| Map | `flutter_map` + a tile provider (MapTiler or Stadia free tier) | OSM's own tile servers can't be used for apps |
| Navigation | Custom: GraphHopper step instructions + `geolocator` + `flutter_tts` | Keeps riders inside the app |

> If you'd rather use Firebase, tell the agent in Prompt 00 and replace PostGIS queries with geohash queries (`geoflutterfire_plus`). Everything else stays the same.

---

## Prompt 00 — Project context (save as `CLAUDE.md` in the repo root)

```
Create a file CLAUDE.md in the repo root with this project context, and read it at the start of every task:

# Pasyar (display name) / PasyarPH (handles)
Motorcycle loop-route app for Filipino riders. A rider picks how long they want to ride, taps Generate, and gets a loop that starts and ends at their location. Shuffle gives a new loop. Each loop has a main stop (viewpoint, falls, food spot). At the stop, the rider can post up to 10 photos (GPS-verified) with the route attached. Other riders see posts in a newsfeed and tap "Ride this loop". Riders can also create custom loops by tapping points on the map and share them publicly, to a club, or privately.

## Stack
- Flutter (latest stable), Provider for state, go_router for navigation
- Supabase: Auth, Postgres + PostGIS, Storage, Edge Functions (Deno/TypeScript)
- GraphHopper routing API called ONLY from Edge Functions, never from the app (OpenRouteService was dropped: its public API timed out)
- flutter_map with vector/raster tiles from [TILE PROVIDER], key in --dart-define
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
```

**Done when:** `CLAUDE.md` exists and you've replaced `[TILE PROVIDER]`.

---

## Prompt 01 — Project setup and flavors

```
Set up the Flutter project for Pasyar:
- App flavors: dev and prod, with separate app IDs ([BUNDLE ID].dev and [BUNDLE ID]) and app names ("Pasyar Dev", "Pasyar").
- Env config read from --dart-define: SUPABASE_URL, SUPABASE_ANON_KEY, MAP_TILE_URL, MAP_TILE_KEY. Add an Env class in lib/core/env.dart that fails loudly if a value is missing.
- Add go_router with placeholder screens for the four tabs (Ride, Feed, Create, Me) inside a bottom navigation shell.
- Add the packages listed in CLAUDE.md.
- Add run configurations for VS Code (.vscode/launch.json) for dev and prod.
- Document the run commands in README.md.
```

**Done when:** both flavors install side by side on your phone and the four tabs switch.

---

## Prompt 02 — Theme and shared widgets

```
Read design/DESIGN.md fully and look at every PNG in design/screenshots/ before writing code.
Build the design system exactly as specified there:
- lib/core/theme/: pasyar_colors.dart (copy the Dart block from DESIGN.md), text styles for every row of the Typography table (Barlow + Barlow Condensed via google_fonts), spacing/radius constants, ThemeData.
- Shared widgets in lib/core/widgets/, matching the Components table exactly: PrimaryButton (orange, 56px), SecondaryButton (outlined ink, 56px), ChoiceCard (selectable card used for Quick / Half-day / Full day), StatBlock (small label + big condensed number), BottomSheetPanel (white, 24px top radius, drag handle), PillToggle (checkbox pill like "Avoid highways"), Avatar (initials fallback), PasyarTextField (label above, 52px, show/hide for passwords, helper and error text), SocialButton (Apple dark variant and Google light variant, full width and half width), StepProgress ("STEP X OF N" overline + segmented bar), SafetyRow (icon + bold lead + text on a ground panel).
- Route line and marker painters for flutter_map (route with white casing, ridden segment, dashed closing segment, rider dot, main stop flag, numbered points) as specified in DESIGN.md.
- A /dev/widgets screen (dev flavor only) that shows every widget in all states.
- Golden tests for each widget.
```

**Done when:** the widget gallery looks like the components in the screenshots, side by side.

---

## Prompt 03 — Supabase schema, RLS, and storage

```
Create Supabase migrations in supabase/migrations for:
- Enable PostGIS.
- profiles (id = auth.users.id, full_name, display_name, avatar_url, bike_type enum ['scooter','underbone','big_bike','dual_sport'] nullable, home_area text nullable (town only), onboarding_completed bool default false, terms_accepted_at, created_at). Create the row automatically with a trigger on auth.users insert, copying full_name from user metadata.
- loops (id, owner_id, name, source enum ['generated','custom'], route geography(LineString,4326), shared_route geography(LineString,4326) — the privacy-trimmed version, distance_m, duration_s, curviness_score, main_stop jsonb {name, type, lat, lng}, visibility enum ['public','club','private'], club_id nullable, created_at)
- posts (id, author_id, loop_id, caption, stop_location geography(Point), created_at)
- post_photos (id, post_id, storage_path, position 0-9, width, height)
- likes (post_id, user_id, created_at, PK both)
- comments (id, post_id, author_id, body, created_at)
- clubs (id, name, owner_id, created_at) and club_members (club_id, user_id, role enum ['owner','member'])
- reports (id, reporter_id, target_type, target_id, reason, created_at)
Add a check that a post has at most 10 photos.
Write RLS policies:
- Anyone signed in can read public loops/posts; club loops only by club members; private only by owner.
- Users can only insert/update/delete their own rows.
- Never expose loops.route to anyone but the owner; others read shared_route only (use a view or column-level grant).
Create a Storage bucket avatars (users write only avatars/<user_id>/*, public read).
Create a Storage bucket post-photos with policies: authenticated users upload to their own folder (user_id/...), public read.
Add Postgres functions (RPC):
- loops_near(lat, lng, radius_m, limit, offset) returning public loops ordered by distance
- feed_near(lat, lng, radius_m, limit, cursor) returning posts with author, photos, loop stats, like_count, comment_count, liked_by_me
Generate Dart models for every table in lib/data/models.
```

**Done when:** migrations apply cleanly on a fresh project and you can query `feed_near` from the SQL editor.

---

## Prompt 04 — Welcome, log in, and register

```
Build the signed-out screens with Supabase Auth. Sign-in options are ONLY: Apple, Google, and simple email + password.
Match these exactly (layout, sizes, colors, copy). Open each screenshot AND mockup before coding, and add a 390x844 golden test for each when done:
- Welcome: design/screenshots/07-welcome.png and design/mockups/07-welcome.html
- Log in: design/screenshots/08-login.png and design/mockups/08-login.html
- Register: design/screenshots/09-register.png and design/mockups/09-register.html

Welcome
- Shown whenever the user is signed out. Dark ink background, loop illustration (draw it with CustomPainter, same shapes and colors as the mockup), "PASYAR" wordmark, tagline, description.
- CREATE ACCOUNT -> Register. I ALREADY HAVE AN ACCOUNT -> Log in.

Log in
- Continue with Google: native google_sign_in, then supabase.auth.signInWithIdToken.
- Continue with Apple (black button, shown first): on iOS use sign_in_with_apple, then supabase.auth.signInWithIdToken(provider: apple) with a hashed nonce. On Android use supabase.auth.signInWithOAuth(OAuthProvider.apple) with a deep-link redirect back to the app. Apple only shares the user's name on the FIRST sign-in, so save it to the profile immediately.
- No Facebook or any other social login.
- Email + password with show/hide toggle, inline validation, loading state on LOG IN, friendly error messages (wrong password, unconfirmed email, no internet).
- Forgot password: screen built from DESIGN.md components (email field + SEND RESET LINK). Use supabase.auth.resetPasswordForEmail with a deep link that opens a Set new password screen.
- Footer link to Register.

Register
- Apple and Google buttons side by side, Apple first (same flows as Log in).
- Full name, email, password (min 8 characters, show the rule as placeholder and as an inline error), terms checkbox that must be checked before CREATE ACCOUNT is enabled. Terms and Privacy Policy links open [DOMAIN]/terms and [DOMAIN]/privacy.
- Sign up with supabase.auth.signUp, passing full_name in user metadata; save terms_accepted_at on the profile.
- If email confirmation is on in Supabase, show a "Check your email" screen (DESIGN.md components, mail icon, RESEND EMAIL button with a 60-second cooldown, "Back to log in").
- Footer link to Log in.

Routing and state
- AuthProvider exposes session, user, and profile (including onboarding_completed).
- go_router redirect rules: signed out -> /welcome (allow /login, /register, /forgot-password); signed in but onboarding_completed is false -> /onboarding/profile; otherwise /ride.
- Keyboard must never cover the focused field or the main button (scroll the form; keep the button visible).
- Sign-out lives in the Me tab (placeholder button for now).
```

**Done when:** you can register with email, Apple, and Google, log out, log back in, and reset a password, and all three screens match their screenshots.

---

## Prompt 05 — Onboarding (rider profile + location)

```
Build first-time onboarding, shown once after registration (and after the first social sign-in) until profiles.onboarding_completed is true.
Match these exactly (layout, sizes, colors, copy). Open each screenshot AND mockup before coding, and add a 390x844 golden test for each when done:
- Step 1, rider profile: design/screenshots/10-onboarding-profile.png and design/mockups/10-onboarding-profile.html
- Step 2, location + safety: design/screenshots/11-onboarding-location.png and design/mockups/11-onboarding-location.html

Shared
- "STEP X OF 2" overline with a two-segment progress bar. Back button on step 2 returns to step 1 with entered data kept.
- OnboardingProvider holds the draft until it is saved.

Step 1 — Rider profile
- Profile photo (optional): tap the circle to pick from camera or gallery, crop square, compress to 512 px, upload to avatars/<user_id>/avatar.jpg, show it in the circle.
- Rider name (required, 2–30 characters), prefilled from full_name or the Apple/Google account's first name.
- "What do you ride?" — single-select cards: Scooter, Underbone, Big bike, Dual-sport (optional; tap again to clear). Saves to profiles.bike_type.
- Home area (optional, town only — e.g. "Cordon, Isabela"). Helper text: "Town only. Helps show loops near you." Never store a street address here.
- NEXT saves the profile fields and goes to step 2. Disable NEXT until the name is valid.

Step 2 — Location + safety
- Loop illustration in a circle (CustomPainter, same as mockup), "TURN ON LOCATION", explanation, and three safety rows exactly as in the mockup (start stays private, mount your phone, typing locks while moving).
- ALLOW LOCATION requests "while using the app" permission with geolocator. Granted -> finish. Denied -> finish anyway and let Home show a location banner. Permanently denied -> finish and Home shows an OPEN SETTINGS banner.
- "Not now" finishes without asking.
- Finishing sets profiles.onboarding_completed = true and goes to /ride.
- Do not ask for background location here; that is requested only when a ride starts (Prompt 10).
```

**Done when:** a brand-new account goes Welcome -> Register -> Step 1 -> Step 2 -> Home, never sees onboarding again, and both steps match their screenshots.

---

## Prompt 06 — Map and location (Home screen shell)

```
Build the Home (Ride tab) screen base:
Match design/screenshots/01-home.png and design/mockups/01-home.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- Full-screen flutter_map with the tile provider from Env, centered on the user's location with a blue location dot.
- Location permission is asked during onboarding (Prompt 05). Here, if permission is missing, show a banner over the map: "Location is off — Pasyar needs it to build loops" with ALLOW LOCATION (or OPEN SETTINGS when permanently denied).
- LocationProvider that streams position (geolocator) and exposes current speed.
- Top floating pill "Starting from: Current location" and a profile button, as in the mockup.
- Bottom sheet with title "WHERE TO TODAY?", subtitle, three ChoiceCards (Quick ~1 hr, Half-day ~4 hr, Full day 6 hr+), two PillToggles (Avoid highways, Avoid unpaved), and a GENERATE LOOP button (disabled until location is known). The button doesn't call anything yet.
- Map attribution visible as required by the tile provider and OpenStreetMap.
```

**Done when:** the Home screen matches the mockup on your phone and shows your real location.

---

## Prompt 07 — Edge Function: generate-loop

> Done. Built with GraphHopper round trips instead of ORS (ORS timed out); see README → Edge Functions.

```
Create a Supabase Edge Function generate-loop (TypeScript):
Input: { lat, lng, duration: 'quick'|'half'|'full', avoidHighways: bool, avoidUnpaved: bool, seed: int }
Logic:
- Map duration to a target length in meters (quick 50 km, half 120 km, full 220 km — make these constants easy to tune).
- Call OpenRouteService directions (profile driving-car, geojson) with options.round_trip { length, points: 5, seed } and avoid_features including "highways" when avoidHighways is true. Check the ORS docs for whether unpaved avoidance is supported on driving-car; if it isn't, ignore the flag and return a warning field.
- Return: route GeoJSON LineString, distance_m, duration_s, ORS step instructions, and the seed used.
- Compute a backtracking ratio (share of route length that overlaps itself within ~30 m) and a curviness score (sum of heading changes per km). Put these helpers in a separate module with unit tests.
- Store ORS_API_KEY as a Supabase secret.
- Rate limit per user: max 30 generate calls per hour (store counts in a small table).
- Return friendly errors (ORS down, limit reached, no route found).
Add a Dart RouteRepository.generateLoop(...) that calls this function.
```

**Done when:** calling the function from the app returns a real loop near you, and the unit tests pass.

---

## Prompt 08 — Generate, Shuffle, and Loop Preview

```
Wire up Generate and build the Loop Preview screen (mockup screen 2):
Match design/screenshots/02-loop-preview.png and design/mockups/02-loop-preview.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- GENERATE LOOP calls RouteRepository.generateLoop with a random seed and shows a loading state on the map.
- Preview screen: route drawn as an orange line with a white casing, start dot, main stop marker.
- Bottom sheet: Distance, Ride time, Curvy roads (Low/Medium/High from curviness score), main stop card, SHUFFLE (new seed) and START RIDE buttons.
- Shuffle keeps the previous loop visible until the new one arrives.
- If backtracking ratio > 0.25, automatically try up to 3 more seeds and show the best one (lowest backtracking, then highest curviness).
- Main stop for now: the point on the route farthest from the start, labeled "Main stop". (Prompt 09 makes it a real place.)
```

**Done when:** you can generate, shuffle several times, and each loop looks reasonable on the map.

---

## Prompt 09 — Real main stops (POIs)

```
Improve main stop selection in generate-loop:
- After getting the route, query the Overpass API (OpenStreetMap) within 1.5 km of the route for: viewpoints, waterfalls, tourist attractions, restaurants/cafés, fuel stations.
- Pick the main stop: prefer viewpoint/waterfall/attraction located 35–65% along the route; fall back to a food spot; fall back to the farthest point.
- Return main_stop {name, type, lat, lng, km_into_route} and nearby fuel stations along the loop.
- Show them in the Preview: main stop card "MAIN STOP · 52 KM IN" with name and type, small fuel icons on the map.
Add unit tests for the stop-picking logic.
```

**Done when:** most generated loops near you show a real named stop.

---

## Prompt 10a — Ride with Google Maps (done)

> Built instead of in-app navigation for now. START RIDE opens Google Maps with the loop as up to 9 ordered stops (the main stop is one of them) and back home. Pasyar keeps a ride session running in the background (Android location foreground service with a notification): it tracks the ridden route, alerts "You made it to …" after the rider stops within 150 m of the main stop for 20 s, ends the ride when they stop near home after half the loop, and saves a ride summary on the phone. The ride screen shows the ridden part grey, km and time, distance to the main stop, GOOGLE MAPS (back to navigation) and END RIDE. Google routes between the stops itself, so it may not follow the loop exactly.

---

## Prompt 10b — In-app turn-by-turn navigation (later, after rider feedback)

Offer this next to "Open in Google Maps" for riders who want the exact loop. Reuse the 10a ride session (tracking, arrival, summary) and add:

```
Build the Riding screen (mockup screen 3):
Match design/screenshots/03-riding.png and design/mockups/03-riding.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- Dark top banner with the next maneuver icon, distance to it (big condensed number), and instruction text from the GraphHopper steps.
- Map follows the rider with heading-up rotation; ridden part of the loop turns grey.
- "Main stop in X km" chip, bottom panel with km left, ETA back home, current speed, progress bar, mute voice, END RIDE.
- Voice prompts with flutter_tts at ~500 m and ~100 m before each maneuver (English first; structure strings so Filipino can be added later).
- Off-route detection: if > 50 m from the route for > 10 seconds, request a new route from the current position back onto the loop (new Edge Function route-to-loop using GraphHopper directions) and resume.
- Keep the screen on (wakelock_plus) while riding. Save a ride summary (distance ridden, time) locally when the ride ends.
- Handle the app going to background: keep location updates running with a foreground service notification on Android ("Pasyar is guiding your ride").
- Big text and controls; nothing that needs reading while moving.
```

**Done when:** you complete a short real loop with correct voice prompts and a reroute when you deliberately take a wrong turn.

---

## Prompt 11 — Arrival at stop and posting photos

```
Build the post-at-stop flow (mockup screen 4):
Match design/screenshots/04-post-at-stop.png and design/mockups/04-post-at-stop.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- During a ride, when the rider is within 150 m of the main stop AND speed < 5 km/h for 20 seconds, show "You made it — take photos?".
- Post screen: "GPS confirmed at stop" badge, 10-slot photo grid (camera capture in-app; allow picking from gallery only photos taken in the last 2 hours and within 300 m of the stop, using EXIF if present), counter "x / 10", caption field, "Route attached" card, POST TO FEED, "Skip and keep riding".
- Re-check GPS on submit; if the rider has left the stop radius, keep the draft and explain why posting is blocked.
- Compress photos to max 1600 px long edge, ~80% JPEG, upload to post-photos/<user_id>/<post_id>/<n>.jpg with progress; create posts + post_photos rows in one transaction (RPC).
- Save the loop first if it's a generated loop that isn't saved yet (visibility public by default, editable later).
- Lock the caption field and Post button while speed > 10 km/h.
- Failed uploads retry; drafts survive an app restart.
```

**Done when:** you can post 3 photos at a real stop and the post appears in the database with photos in storage.

---

## Prompt 12 — Home privacy trimming

```
Implement privacy trimming for shared routes:
- Postgres function trim_route(route geography, trim_m int default 800) that removes the first and last trim_m meters of a LineString.
- Trigger on loops insert/update to fill shared_route = trim_route(route).
- Everywhere other users see a loop (feed, preview of someone else's loop, share links) use shared_route only.
- "Ride this loop" routes the rider to the nearest point of shared_route, never to the owner's start.
Add a SQL test showing the trimmed route starts ~800 m from the original start.
```

**Done when:** viewing your own post from a second account never shows your start point.

---

## Prompt 13 — Newsfeed

```
Build the Feed tab as a newsfeed (mockup screen 5):
Match design/screenshots/05-newsfeed.png and design/mockups/05-newsfeed.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- Header "FEED" with search and notifications buttons, composer row "Share a ride or a loop…" (opens Create), filter chips: Near you / Following / My clubs (Following and My clubs can show an empty state until Prompt 17).
- Infinite scroll using feed_near with cursor pagination; pull to refresh.
- Post card variants:
  a) Ride post: "<name> rode <loop name>", time + stop + visibility, caption, photo collage (1, 2, 3, or 3 + "+N" layout), loop card with mini map, stats and RIDE IT button, counts row, Like / Comment / Share, first comment preview.
  b) Shared loop post (no photos): big route map with stat chips and RIDE THIS LOOP button.
- Tapping photos opens a full-screen swipeable gallery.
- Cache images; show skeleton loaders while loading.
```

**Done when:** the feed scrolls smoothly with 30+ test posts and both card types render correctly.

---

## Prompt 14 — Likes and comments

```
Add likes and comments:
There is no mockup for this screen: build it only from the components and tokens in design/DESIGN.md so it matches the rest of the app.
- Optimistic like toggle with rollback on error; counts update instantly.
- Comments screen (bottom sheet or full screen): list with pagination, input box, post comment, delete own comment.
- Show "View all N comments" on the card.
- Basic profanity filter list for Filipino and English (configurable table), and block posting identical comments repeatedly.
```

**Done when:** two accounts can like and comment on each other's posts and see updates after refresh.

---

## Prompt 15 — Ride this loop

```
Implement "Ride this loop" from a feed post or loop link:
- Load the loop's shared_route.
- Route from the rider's current location to the nearest point on the loop (GraphHopper directions via an Edge Function), then follow the loop all the way around, then route back to the rider's start.
- Show a preview first: total distance including approach and return, ride time, main stop.
- START RIDE uses the same navigation screen (Prompt 10).
```

**Done when:** you can ride a loop posted by another account starting from your own location.

---

## Prompt 16 — Create a custom loop

```
Build the Create tab (mockup screen 6):
Match design/screenshots/06-create-loop.png and design/mockups/06-create-loop.html exactly (layout, sizes, colors, copy). Open both before coding, and add a 390x844 golden test to compare when done.
- Map starts at the rider's location as point S. Tapping the map adds numbered points; long-press a point to remove; drag to move.
- After each change, call an Edge Function route-through-points that snaps to roads via GraphHopper directions through S → 1 → … → n → S, debounced 600 ms. (The free plan allows 5 points per request: split longer loops into chunks, or require the paid plan.)
- Show the closing segment back to S as a dashed line until the route returns.
- Bottom sheet: loop name, live distance and ride time, "N points · closes back to start", choose which point is the main stop, visibility segmented control (Public / Club / Private), SAVE and SHARE LINK.
- Limit to 15 points. Undo last point.
```

**Done when:** you can build a 4-point loop, save it, and see it in your profile.

---

## Prompt 16b — Multi-day trips

```
Add multi-day trips (3+ days, e.g. Cordon → Baguio → Sagada → Pagudpud → home), planned by the rider.
There is no mockup for these screens: build them only from the components and tokens in design/DESIGN.md (reuse the Create map, route line, markers, StatBlock, StopCard, ChoiceCard, BottomSheetPanel) so they match the rest of the app.

Data
- Migrations: trips (id, owner_id, name, visibility, club_id, created_at) and trip_days (id, trip_id, day_number, start_point, end_point geography(Point), stops jsonb, route, shared_route geography(LineString), distance_m, duration_s, main_stop jsonb). RLS like loops: owners read route; others read shared_route only, by visibility.
- Home privacy: trim the first 800 m of day 1 and the last 800 m of the final day in shared_route (overnight towns are not trimmed).
- Dart models for both tables.

Planning (Create tab → "Multi-day trip")
- Start is the rider's location (S). Tap the map or search a town to add each overnight stop; the final day returns to S automatically.
- Each day can have up to 3 optional stops between its start and its overnight town (GraphHopper free plan allows 5 points per request).
- Route each day separately through an Edge Function route-day (GraphHopper, car profile, one call per day; only re-route days that changed, debounced 600 ms).
- Day list in the sheet: "DAY 1 · Cordon → Baguio", km, ride time per day, and totals for the trip. Warn on a day over 400 km or 9 h of riding ("Long day — consider an extra overnight stop").
- Reorder, insert or remove overnight stops; undo last change. Limit 10 days.
- Name, visibility (Public / Club / Private), SAVE and SHARE LINK.

Riding
- Trip preview: all days on the map in the route style (current day in accent, other days in riddenRoute grey), day list, START DAY N.
- START DAY N opens the normal navigation screen (Prompt 10) for that day's route only; finishing a day marks it done and the trip shows the next day.
- Posts at a stop (Prompt 11) attach the trip and day.

Sharing
- Feed card for a trip: name, "5 days · 1,240 km", day list, map of all days. "Ride this trip" copies it as the viewer's own trip, starting from their location (approach and return legs added to day 1 and the final day).

Add unit tests for day splitting, day warnings, the trip privacy trim, and trip totals.
```

**Done when:** you can plan a 4-day trip, see per-day distance and time, save it, ride day 1 with navigation, and another account can see it in the feed and copy it.

---

## Prompt 17 — Clubs and visibility

```
Add riding clubs:
There is no mockup for this screen: build it only from the components and tokens in design/DESIGN.md so it matches the rest of the app.
- Create a club (name, optional photo); owner can invite by share link; members can leave.
- Club page: members list and the club's loops/posts.
- Visibility "Club" requires picking one of the user's clubs; RLS already restricts reads.
- Feed "My clubs" filter shows posts and loops from the user's clubs.
- Feed "Following": add a follows table (follower_id, followee_id) with RLS and a follow button on profiles.
```

**Done when:** a club loop is visible to a member account and invisible to a non-member account.

---

## Prompt 18 — Share links and deep links

```
Add shareable loop and post links:
- URL format: https://[DOMAIN]/l/<loop_id> and https://[DOMAIN]/p/<post_id>.
- Android App Links and iOS Universal Links (assetlinks.json and apple-app-site-association hosted on the domain).
- Opening a link in the app goes to the loop preview / post; if not installed, a simple web page shows the loop name, stats, a static map image, and store buttons.
- Respect visibility: private loops can't be opened by others; club loops ask the user to join the club.
- Share sheet uses share_plus with a short message: "Pasyar tayo! <loop name> · <km> km".
```

**Done when:** tapping a shared link in Messenger opens the right loop in the app.

---

## Prompt 19 — Me tab (profile)

```
Build the Me tab:
There is no mockup for this screen: build it only from the components and tokens in design/DESIGN.md so it matches the rest of the app.
- Header: avatar, name, totals (km ridden, loops ridden, posts).
- Tabs: Posts (grid), My loops (list with visibility badges, edit/delete), Saved loops.
- Edit profile, settings (voice prompts on/off, units fixed to km, privacy trim distance info), sign out, delete account (deletes data and storage files via an Edge Function).
```

**Done when:** totals update after a ride and account deletion removes all user data.

---

## Prompt 20 — Safety, moderation, and reporting

```
Add safety and moderation:
- Report post / comment / loop / user with reasons; block user (hides their content for the blocker).
- Simple admin view (Supabase dashboard queries or a small admin-only screen) to review reports and hide content (add is_hidden columns respected by RLS and feed functions).
- First-ride safety screen: reminders to mount the phone, not interact while moving, and ride within limits.
- Confirm the moving-lock rule (speed > 10 km/h disables typing/posting) is applied everywhere.
```

**Done when:** reported content can be hidden by an admin and disappears from feeds.

---

## Prompt 21 — Launch prep

```
Prepare Pasyar for store release:
- Crash reporting (Sentry or Firebase Crashlytics) and basic analytics events: generate, shuffle, start_ride, end_ride, post_created, ride_this_loop, loop_created.
- App icon and splash screen (orange background, "PASYAR" wordmark — placeholder until final logo).
- Permission strings for location (when in use + background for active navigation), camera, photos — explain exactly why.
- Sign in with Apple setup: App ID capability, Services ID and private key for the Android web flow, configured in Supabase Auth. Google OAuth consent screen verification (needs the privacy policy URL and app icon).
- Privacy policy and terms pages on [DOMAIN] covering location, photos, home privacy trimming, data deletion.
- Android release signing for prod flavor; iOS signing notes for the Mac build machine.
- Store listing text (title "Pasyar – Moto Loop Routes PH"), screenshots checklist, and a closed beta track.
- Review: remove dev-only screens from prod builds, verify no API keys in the app bundle.
- Routing plan: GraphHopper's free plan is non-commercial with a per-minute limit; move to a paid plan (or a self-hosted router) before release.
```

**Done when:** a signed prod build is uploaded to Google Play closed testing.

---

## Later (after real rider feedback)

- Custom waypoint-circle loop generation for areas where GraphHopper round trips backtrack too much.
- Multi-day "Surprise me": pick the number of days and the app chooses overnight towns about a day's ride apart around a loop (builds on Prompt 16b).
- An "EPIC · 300 km +" option on Home for long single-day loops (check round-trip quality at 300–500 km first).
- AI natural-language input ("chill 2-hour loop with a waterfall") that maps to generate-loop parameters.
- Self-hosting a router (GraphHopper or OpenRouteService with Philippines data) once traffic outgrows the hosted plan.
- Offline maps for areas with weak signal.
- Filipino and Ilocano voice prompts and UI.
