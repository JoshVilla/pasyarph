---
target: feed
total_score: 27
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:C:\\Users\\ASUS TUF\\pasyarph\\lib\\features\\feed\\screens\\feed_screen.dart"
target_fingerprint: "sha256:7f5180641058c8b4e92bbe5944727b785089011c39d0e0bbb2d66c97ca51fedf"
target_path: "C:\\Users\\ASUS TUF\\pasyarph\\lib\\features\\feed\\screens\\feed_screen.dart"
timestamp: 2026-10-31T18-42-03Z
slug: lib-features-feed-screens-feed-screen-dart
---
Method: design review only (detector not applicable, native platform)

Target: lib/features/feed/screens/feed_screen.dart (Feed tab, Android emulator 412dp + source). Mode: Operate.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Skeletons, paging spinner, active chip/tab all present; paging errors surface only as text at the list bottom |
| 2 | Match System / Real World | 3 | "rode", "10 km from you" read naturally; auto loop names ("25 km loop") say nothing about place |
| 3 | User Control and Freedom | 3 | Pull to refresh, sheets dismiss; no tap-Feed-tab-to-top, filters scroll away |
| 4 | Consistency and Standards | 3 | Matches DESIGN.md tokens; Search/bell look live but only show "coming soon" |
| 5 | Error Prevention | 3 | Low-risk surface; nothing destructive without the ⋯ menu |
| 6 | Recognition Rather Than Recall | 3 | Labeled actions and tabs; "Post a ride" button goes to Me, not posting |
| 7 | Flexibility and Efficiency | 2 | One-tap RIDE IT is great; no scroll-to-top, no way to jump back to filters |
| 8 | Aesthetic and Minimalist Design | 3 | Clean; "25 km" repeated three times per ride post |
| 9 | Error Recovery | 2 | Load errors replace the list with text only, no TRY AGAIN button |
| 10 | Help and Documentation | 2 | Following/My clubs empty states teach well; Near you/Global empty states give no next step |
| **Total** | | **27/40** | **Acceptable** |

## Design Specificity Verdict

LLM assessment: partly specific. The skeleton (composer row, filter chips, Like/Comment/Share bar, comment bubble) is the generic social-feed template. What makes it Pasyar is the loop card: route thumbnail, distance from you, one-tap RIDE IT, which carries principle 5. The missed opportunity: on a ride post, the route is the product but it's a 64x50 thumbnail under the photos, and auto-generated names repeat the distance instead of naming a place.

Deterministic scan: not applicable (native platform).

## Overall Impression

A tidy, on-spec feed with good state coverage. The single biggest opportunity: the Feed is the home screen, and before riders exist near you it's an empty white band with no path to the Ride tab, which contradicts "Get them riding."

## What's Working

- Loop card + RIDE IT: one tap from someone else's ride to your own loop from where you are.
- State coverage: skeletons, per-filter empty copy, location prompt, paging spinner, block via ⋯.
- Glove-safe hit areas (44px) while keeping mockup visual sizes; status bar now has a white strip.

## Priority Issues

1. [P1] Empty Near you / Global is a dead end on the home screen. Fix: primary GENERATE A LOOP button to the Ride tab; when Near you is empty but Global isn't, offer "See rides from all of the Philippines". Command: /impeccable onboard
2. [P1] Both posting entry points miss the posting flow: "Post a ride" image button opens Me; "Share a ride or a loop…" opens the custom loop builder. Fix: image button opens a "pick a recent ride" sheet leading to photos; keep the composer for loops or relabel it. Command: /impeccable clarify
3. [P2] Auto loop names: "rode 25 km loop" / "25 km loop" / "25 km · 27 min" repeat the distance three times and give no sense of place. Fix: name generated loops after the main stop or town ("Daranak Falls loop"), fall back to "25 km loop" only without a stop. Command: /impeccable clarify
4. [P2] Load errors are text-only. Fix: TRY AGAIN SecondaryButton in FeedEmpty for errors, and on the paging error band. Command: /impeccable harden
5. [P2] No way back to top after scrolling deep. Fix: tapping the active Feed tab scrolls to top (platform convention on both OSes). Command: /impeccable polish

## Persona Red Flags

Jordan (first-timer, just signed up): lands on Feed, Near you shows "No rides near you yet. Finish a loop and post it to be the first." No button; must guess that Ride is where loops come from.

Casey (one-handed, interrupted): after scrolling 20 posts, filters and composer are gone; no tab-reselect-to-top, so it's a long swipe back.

Weekend scooter rider at a gas stop, gloves on (project persona): RIDE IT is reachable and big enough; the ⋯ icon (20px glyph, 44px area at the right edge) is fine; Search/bell look tappable but only toast "coming soon", a wasted glove tap.

## Minor Observations

- Own avatar is upscaled from a tiny image and looks pixelated; request a larger size or use the initials avatar.
- Hide Search and the bell until they work, or show them disabled.
- Chips row: 4 chips fit at 412dp and scroll on narrow phones (verified in code).
- lib/features/feed/widgets/post_card_head_backup.txt is a stray file in lib/.
- 10 golden tests fail on main independent of this screen.

## Questions to Consider

- What if a ride post led with the route (a map strip under the header) and the photos second?
- Should an empty Near you quietly fall back to Global so the home screen is never empty at launch?
- What would make "25 km loop" a place a rider wants to go?
