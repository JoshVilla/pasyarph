---
version: 1
slug: "es-create-screens-create-loop-screen-dart-ed0cb23d"
primary_target: "lib/features/create/screens/create_loop_screen.dart"
related_targets: ["lib/features/create/widgets/create_loop_sheet.dart","lib/features/create/widgets/create_loop_map.dart"]
---

# Create a loop

Scope: lib/features/create/screens/create_loop_screen.dart with widgets/create_loop_sheet.dart, widgets/create_loop_map.dart, loop_builder.dart (hints), core/widgets/collapsible_sheet.dart. Mode: Operate.

Audience and task: a rider builds a custom loop by tapping points on the map (routed S → 1 → … → S), picks a main stop, then names it, chooses who can see it, and saves or shares. Outdoors, sometimes with gloves; no typing or saving above 10 km/h.

Constraints (user-pinned): tapping a point shows an action row (MAKE MAIN STOP · REMOVE); fix all five critique issues (form over the map while building, hidden point gestures, buried live stats, "Group" vs club wording, long caption box). Keep the Pasyar visual system.

## Direction contract

THESIS: Build on the map, publish from the sheet. The sheet starts lowered to a peek bar so the map owns the screen while you shape the loop; it refuses the always-open form that covered half the work surface.

OWN-WORLD: Pasyar map with blue numbered points, direction arrows and the dashed closing segment; white sheet with 24 px top corners; Barlow Condensed capitals for the live totals and buttons; deep blue accent for DONE, selection and the main-stop action; ground-tinted secondary actions.

STORY: The rider taps points and watches the live distance and time change in the peek bar; taps a point to make it the main stop or remove it; taps DONE to bring up name, caption (folded away), Club/Public/Private, SAVE and SHARE LINK.

FIRST VIEWPORT: Back, hint pill and undo on top; the map nearly full screen; a peek bar at the bottom with "96 KM · 3 H 10" at stat size, "3 points · closes back to start", and DONE on the right. A tapped point shows a floating card above it: MAIN STOP · REMOVE.

FORM: Peek sheet; position 2 of 7 on the ranked list; seed: 92ef4132a90e7a9d. Signature move: the point action card that floats above the tapped point.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
