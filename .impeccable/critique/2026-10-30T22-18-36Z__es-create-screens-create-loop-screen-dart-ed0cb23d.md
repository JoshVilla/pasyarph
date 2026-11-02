---
target: Create loop screen
total_score: 25
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:/Users/admin/pasyarph/lib/features/create/screens/create_loop_screen.dart"
target_fingerprint: "sha256:3930a2f850f2ec1ba12d2e4946313a262576b2a011a652f0af40ab2f2bd06ba9"
target_path: /Users/admin/pasyarph/lib/features/create/screens/create_loop_screen.dart
timestamp: 2026-10-30T22-18-36Z
slug: es-create-screens-create-loop-screen-dart-ed0cb23d
---
Method: design review only (detector not applicable, native platform)

# Critique: Create loop screen, lib/features/create/screens/create_loop_screen.dart

| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Live km/time buried at 13 px inside the form |
| 2 | Match System / Real World | 3 | "Group" vs "club" |
| 3 | User Control and Freedom | 3 | Undo, drag, hold-to-remove, leave guard |
| 4 | Consistency and Standards | 2 | Group vs My clubs; Caption not in mockup |
| 5 | Error Prevention | 3 | 15-point limit, leave guard, moving locks |
| 6 | Recognition Rather Than Recall | 2 | Main stop / remove gestures taught once, then hidden |
| 7 | Flexibility and Efficiency | 2 | Start only at S; no search; no ride-it-now |
| 8 | Aesthetic and Minimalist Design | 2 | 472 px form sheet over the map during building |
| 9 | Error Recovery | 3 | Retry in hint pill |
| 10 | Help and Documentation | 2 | Hints vanish by point 3; main stop unexplained |
| Total | | 25/40 | Acceptable |

Specificity: map half distinctly Pasyar (numbered points, arrows, dashed closing segment, flag); sheet half a generic form shown at full weight from point zero.

## Priority Issues
- [P1] Form takes over the map while building. Two-phase: compact live bar + DONE while building; form after. → /impeccable layout
- [P1] Main stop / remove are hidden gestures taught once; long-press hard with gloves. Tap point → action row (MAKE MAIN STOP · REMOVE). → /impeccable harden
- [P2] Live numbers buried. StatBlock-size km/time at the top of the sheet or bar. → /impeccable layout
- [P2] "Group" vs "club". Rename to Club; link to create a club when none. → /impeccable clarify
- [P2] Caption box makes the sheet a long form. Collapse to "Add a caption". → /impeccable distill

## Personas
- Rhea: form before map; misses main-stop hint.
- Jun (gloves): small markers, long-press drags.
- Marco: looks for Club, sees Group; no ride-it-now after save.

## Minor
- "0 km · 0 min" before points; SAVE disabled with no reason; "Change" club link has no 44 px target.

## Questions
- Full-screen map first, form after DONE?
- RIDE IT as primary after save?
- Pick main stop from places along the route?
- Caption at creation, or at posting?
