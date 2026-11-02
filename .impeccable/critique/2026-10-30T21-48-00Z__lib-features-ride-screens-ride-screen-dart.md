---
target: Ride tab (Home)
total_score: 26
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:/Users/admin/pasyarph/lib/features/ride/screens/ride_screen.dart"
target_fingerprint: "sha256:1b169d6d6cc7486169efe029ddcc556a0fa04b039f959b12ee915a8c0a44fbbe"
target_path: /Users/admin/pasyarph/lib/features/ride/screens/ride_screen.dart
timestamp: 2026-10-30T21-48-00Z
slug: lib-features-ride-screens-ride-screen-dart
---
Method: design review only (detector not applicable, native platform)

# Critique: Ride tab (Home), lib/features/ride/screens/ride_screen.dart

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Loading/disabled states clear; "Starting from your location" never names a place |
| 2 | Match System / Real World | 3 | "1 hr · ~50 km" concrete; return time unused (and hard-coded fake) |
| 3 | User Control and Freedom | 3 | Can't start anywhere but current location; pill looks tappable, isn't |
| 4 | Consistency and Standards | 2 | Only sentence-case screen title; refresh icon for Generate; profile button duplicates Me tab |
| 5 | Error Prevention | 3 | No fix → disabled; 220 km Full-day offered to scooters with no hint |
| 6 | Recognition Rather Than Recall | 3 | All choices visible with time and distance |
| 7 | Flexibility and Efficiency | 2 | Resets each launch; no "same as last time" |
| 8 | Aesthetic and Minimalist Design | 2 | Sheet ~70% of screen; map a 200 px sliver; four heavy cards |
| 9 | Error Recovery | 3 | Error notice far from the button; retry works |
| 10 | Help and Documentation | 2 | "Pick how long. We'll make the loop." removed; Multi-day unexplained |
| Total | | 26/40 | Acceptable |

## Design Specificity Verdict
Drifted from the mockup's map-first, three-across QUICK/HALF-DAY/FULL DAY composition to a generic vertical list of plan-style cards. Map (the product's world) squeezed behind the pill. Deterministic scan: not applicable (native platform).

## Priority Issues
- [P1] Map squeezed to a sliver (sheet ~590 of 844 px). Fix: compact three-across durations, move Multi-day out, drop profile button. → /impeccable layout
- [P1] Multi-day is a different job (plan a trip) mixed into the loop lengths. Fix: three loop lengths; Multi-day as secondary link or in Create. → /impeccable distill
- [P2] Unselected duration cards have ~1.1:1 border (#EAF0FE on white). Fix: lineStrong/line borders. → /impeccable polish
- [P2] Location-off banner overlaps the sheet; disabled Generate gives no reason. → /impeccable harden
- [P2] Lost voice: sentence-case title, subtitle removed, long button label with refresh icon. → /impeccable clarify

## Persona Red Flags
- Rhea (everyday scooter rider): no map context, Multi-day unclear, 220 km Full-day with no hint, refresh icon reads as reload.
- Jun (gloves, sunlight): unselected cards indistinguishable outdoors.
- Marco (weekly regular): resets every launch; no ride-it-again.

## Minor Observations
- LoopDuration.rightLabel fake return times unused; LoopDurationCard doc comment wrong.
- _CrosshairPainter unused; avoidUnpaved sent with no UI.
- post_card_head_backup.txt and bash.exe.stackdump committed in "new".

## Questions to Consider
- Map-first Home with a hint of loop reach before tapping?
- Bike-aware lengths (scooter Full day 150 km)?
- One-tap Generate from the map, sheet only for changing length?
- Does Multi-day belong in Create?
