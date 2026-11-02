---
version: 1
slug: "lib-features-ride-screens-ride-screen-dart"
primary_target: "lib/features/ride/screens/ride_screen.dart"
related_targets: ["lib/features/ride/widgets/home_controls.dart","lib/features/ride/widgets/ride_map.dart"]
---

# Ride tab (Home)

Scope: the Ride tab home screen (lib/features/ride/screens/ride_screen.dart, lib/features/ride/widgets/home_controls.dart, lib/features/ride/widgets/ride_map.dart). Mode: Operate.

Audience and task: the everyday scooter/underbone rider with no plan picks how long to ride and gets a loop from where they are. One decision, one action. Used outdoors, often in sunlight, sometimes with gloves.

Constraints: Multi-day stays as a duration card (user-pinned). Keep the existing Pasyar visual system (design/DESIGN.md tokens, ChoiceCard, PillToggle, PrimaryButton, BottomSheetPanel). No town name in the start pill (no reverse geocoding; profile home town would be wrong away from home).

## Direction contract

THESIS: Home is a map you can ride, answered in one sentence. The sheet reads as a line the rider finishes ("I'VE GOT ABOUT 4 HRS"), refusing the settings-list of plan cards the screen had drifted into.

OWN-WORLD: Pasyar's light map ground, white sheet with 24 px top corners, Barlow Condensed capitals for the headline and card titles, Barlow for body, deep blue accent (#1D4ED8) for selection, the reach ring and the one button; ink text; line-bordered ChoiceCards with accentTint selected fill.

STORY: The rider sees where they are and roughly how far the chosen loop reaches, reads one sentence that states their choice, changes it with one tap if needed, and taps GENERATE LOOP.

FIRST VIEWPORT: Full-screen map with the S start marker at the rider's position (the same S as on Create and Loop Preview) and a solid accent reach ring (radius = loop distance / 2π) labelled "Loop reaches ~19 km out" (solid, not dashed: across the app a dashed blue line means "back to start" on the Create map and its key); MULTI-DAY shows no ring, because a trip runs between overnight towns rather than within one radius, so the headline alone carries the change; "Starting from your location" pill top. Bottom sheet: headline sentence with the duration words in accent, subtitle "Pick how long. We'll make the loop.", 2x2 ChoiceCards (QUICK, HALF-DAY, FULL DAY, MULTI-DAY), Days picker when Multi-day, Avoid highways / Avoid unpaved toggles, then GENERATE LOOP. Location problems and Generate errors show inside the sheet, above the button.

FORM: Say it in one line; position 7 of 7 on the ranked list; seed: 3ae57027acd4d574. Signature move: the reach ring and the headline both change together when a duration is picked.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
