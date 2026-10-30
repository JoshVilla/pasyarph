# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Android and iOS are equal targets (confirmed). It is one Flutter app with one shared, custom Pasyar design on both: follow each OS's conventions for system behavior (back navigation, permission prompts, system bars, share sheet), not its visual language.

## Users

The core rider is the everyday Filipino motorcycle rider: scooter and underbone owners who want a weekend or after-work ride and don't know where to go. Big-bike and dual-sport riders are welcome but are not the core (confirmed).

They use Pasyar on their phone before and during a ride, often outdoors, on the bike, possibly wearing gloves.

## Product Purpose

Pasyar turns "I want to ride but have no plan" into a ride. The rider picks how long they want to ride, taps Generate, and gets a loop that starts and ends where they are, with a worthwhile main stop (viewpoint, falls, food spot). Shuffle gives a different loop. After riding, they can post photos with the route attached, and other riders can ride that same loop with one tap.

Success: riders actually go out and ride the loops, come back to post them, and ride loops other riders posted.

## Positioning

Loops first, community second (confirmed). The loop generator is what brings riders in: say how long you want to ride and get a loop from your door with a stop worth stopping at, which navigation apps (point A to B) and fitness apps (record what you did) don't do. The feed and clubs keep riders coming back: real rides by Filipino riders and clubs that anyone can ride from their own location.

## Operating Context

- Rides start from the rider's current location, usually home, in the Philippines.
- Navigation during a ride currently hands off to Google Maps; in-app turn-by-turn is planned for later.
- Every post is tied to a ride Pasyar tracked; the rider chooses which photos (up to 10) to post.
- Riders can also build custom loops by tapping points on the map, and share loops publicly, to a club, or privately.
- Clubs are invite-link only; riders can follow other riders. Feed filters: Near you, Global, Following, My clubs.

## Capabilities and Constraints

- Flutter app; Supabase (Auth, Postgres + PostGIS, Storage, Edge Functions); GraphHopper routing called only from Edge Functions; flutter_map with MapTiler tiles.
- Home privacy: shared routes have the first and last 800 m trimmed so a loop never reveals where a rider lives.
- Typing and posting are disabled while the phone is moving faster than 10 km/h.
- Every database table has row level security.
- GraphHopper's free plan is non-commercial; a paid plan or self-hosted router is needed before launch.
- Undecided / later: in-app turn-by-turn navigation, offline maps, Filipino and Ilocano UI and voice prompts, final logo.

## Brand Commitments

- Name: **Pasyar** (display name); **PasyarPH** for handles.
- Tagline: "Walang plano? Pasyar na." (welcome screen).
- UI copy is English today, with Filipino in the brand voice; Filipino and Ilocano UI are planned, not built.
- The approved screens and design spec in `design/` (DESIGN.md, screenshots, mockups) are the visual authority for existing screens.

## Evidence on Hand

- Approved screen designs: `design/screenshots/` and `design/mockups/` (11 screens).
- Bike-type illustrations: `assets/motorcycles/`.
- No real riders, testimonials, ride counts, store listing, or final logo exist yet; don't invent them. Sample names and numbers in mockups and tests are placeholders.

## Product Principles

1. **Get them riding.** The shortest path from opening the app to a loop worth riding wins; deciding where to go is the product's job, not the rider's.
2. **Safe on the bike.** Big glanceable text, large touch targets for gloved hands, and no typing or posting while moving.
3. **Home stays private.** Nothing shared ever shows where a rider starts.
4. **Real rides only.** Posts come from rides Pasyar tracked; the feed shows loops people actually rode.
5. **Ride it yourself.** Anything another rider shares should be one tap away from being your own ride, from where you are.

## Accessibility & Inclusion

- Touch targets at least 44 px (riders may wear gloves).
- Navigation screens use big, glanceable text.
- No typing or posting above 10 km/h.
