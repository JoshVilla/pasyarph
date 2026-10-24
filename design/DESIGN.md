# Pasyar — Design Spec

This folder is the source of truth for how Pasyar looks. **Match it. Don't redesign it.**

- `screenshots/` — PNG of every screen at 390 × 844 (2× scale). Open these before building a screen.
- `mockups/` — the same screens as HTML. Open in a browser, or read the markup for exact sizes, colors, radii, and spacing.

| # | Screen | Screenshot | Mockup |
|---|---|---|---|
| 1 | Home — pick a ride | `screenshots/01-home.png` | `mockups/01-home.html` |
| 2 | Loop preview + Shuffle | `screenshots/02-loop-preview.png` | `mockups/02-loop-preview.html` |
| 3 | Riding (navigation) | `screenshots/03-riding.png` | `mockups/03-riding.html` |
| 4 | Post the loop (after the ride; copy changes in Prompt 11) | `screenshots/04-post-at-stop.png` | `mockups/04-post-at-stop.html` |
| 5 | Newsfeed (tall, scrolling) | `screenshots/05-newsfeed.png` | `mockups/05-newsfeed.html` |
| 6 | Create + share a loop | `screenshots/06-create-loop.png` | `mockups/06-create-loop.html` |
| 7 | Welcome | `screenshots/07-welcome.png` | `mockups/07-welcome.html` |
| 8 | Log in | `screenshots/08-login.png` | `mockups/08-login.html` |
| 9 | Register | `screenshots/09-register.png` | `mockups/09-register.html` |
| 10 | Onboarding — rider profile | `screenshots/10-onboarding-profile.png` | `mockups/10-onboarding-profile.html` |
| 11 | Onboarding — location + safety | `screenshots/11-onboarding-location.png` | `mockups/11-onboarding-location.html` |

**The maps in the mockups are illustrations.** In the app, a real `flutter_map` fills the whole screen behind the floating controls and bottom sheets. Keep the route style (blue `accent` line with white casing), markers, and controls exactly as drawn.

Text in `[brackets]` and the sample numbers are placeholders for real data.

---

## Colors

The theme moved from orange to deep blue (October 2026). The screenshots and HTML mockups still show the old orange: match their layout, but take every color from this table.

| Token | Hex | Used for |
|---|---|---|
| `ink` | `#15171C` | Main text, dark buttons, nav banner background, selected filter chip |
| `muted` | `#5A5F69` | Secondary text, labels, inactive tab icons |
| `ground` | `#F3F2EE` | Soft panels inside sheets, toggle pills, input backgrounds |
| `card` | `#FFFFFF` | Sheets, cards, floating controls |
| `line` | `#E2E0DA` | Borders, dividers, feed separators |
| `lineStrong` | `#D3D5CC` | Drag handles, chip borders, empty photo slots (dashed) |
| `accent` | `#1D4ED8` | Primary buttons, route line, active tab, selected states |
| `accentDark` | `#1E3A8A` | Text on accent tint, overlines like "MAIN STOP · 52 KM IN" |
| `accentTint` | `#EAF0FE` | Selected choice card background, camera slot |
| `rider` | `#0F172A` | Rider location dot and heading arrow, location icon, start point "S" (dark so it stands out on the blue route) |
| `verifiedTint` / `verifiedText` | `#E6EEFB` / `#1E3A8A` | "GPS confirmed at stop" badge |
| `mapGround` | `#F7F7F7` | Map placeholder / loading background; matches the land of the MapTiler `streets-v2-pastel` style |
| `riddenRoute` | `#9CA0A8` | Part of the loop already ridden |
| `coverRoad` | `#2B4BA6` | Roads on the default profile cover (on `accentDark`, with a `taglineOnInk` loop at 80%) |
| `coverChip` | `#0F172A` at 55% | "Edit cover" chip over a cover photo |

```dart
// lib/core/theme/pasyar_colors.dart
import 'package:flutter/material.dart';

class PasyarColors {
  static const ink = Color(0xFF15171C);
  static const muted = Color(0xFF5A5F69);
  static const ground = Color(0xFFF3F2EE);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E0DA);
  static const lineStrong = Color(0xFFD3D5CC);
  static const accent = Color(0xFF1D4ED8);
  static const accentDark = Color(0xFF1E3A8A);
  static const accentTint = Color(0xFFEAF0FE);
  static const rider = Color(0xFF0F172A);
  static const verifiedTint = Color(0xFFE6EEFB);
  static const verifiedText = Color(0xFF1E3A8A);
  static const mapGround = Color(0xFFF7F7F7);
  static const riddenRoute = Color(0xFF9CA0A8);
  static const coverRoad = Color(0xFF2B4BA6);
  static const coverChip = Color(0x8C0F172A);
}
```

---

## Typography

Two families from Google Fonts: **Barlow Condensed** (display) and **Barlow** (body).

| Style | Font | Size / weight | Notes |
|---|---|---|---|
| `wordmark` | Barlow Condensed | 72 / 700 | "PASYAR" on Welcome only, letter-spacing 1, line-height 0.95 |
| `tagline` | Barlow Condensed | 26 / 600 | Welcome tagline, color `taglineOnInk` `#93B4FB` on ink |
| `screenTitle` | Barlow Condensed | 30–36 / 700 | UPPERCASE, letter-spacing 0.5. Home 30, Feed 32, Onboarding 34, Post / Log in / Register 36 |
| `navDistance` | Barlow Condensed | 40 / 700 | Riding banner, line-height 1.0 |
| `statValue` | Barlow Condensed | 28 / 700 | Distance, ride time; 22 inside feed cards |
| `buttonPrimary` | Barlow Condensed | 22 / 700 | UPPERCASE, letter-spacing 1 |
| `buttonSecondary` | Barlow Condensed | 20 / 700 | UPPERCASE, letter-spacing 1 |
| `choiceTitle` | Barlow Condensed | 20 / 700 | QUICK / HALF-DAY / FULL DAY |
| `pillTitle` | Barlow Condensed | 18 / 700 | Floating "HALF-DAY LOOP" pill |
| `bodyLarge` | Barlow | 17 / 600 | Stop names |
| `body` | Barlow | 15 / 400–600 | Default text, captions in feed (line-height 1.4) |
| `bodySmall` | Barlow | 14 / 500 | Toggles, secondary lines |
| `label` | Barlow | 13 / 400 | Stat labels, meta lines ("2 h ago · …") in `muted` |
| `overline` | Barlow | 12 / 600 | UPPERCASE, letter-spacing 0.5, `accentDark` |
| `tabLabel` | Barlow | 12 / 500 (600 active) | Bottom tabs |

---

## Spacing, radius, elevation

- **Safe-area top:** floating controls sit 56 px from the top of the screen (use the real safe area + ~12 px in Flutter).
- **Screen padding:** 20 px inside bottom sheets, 16 px for floating controls and feed content.
- **Gaps:** 16 px between groups in a sheet, 10 px between buttons in a row, 8 px between chips.
- **Radius:** sheets 24 (top corners only); primary/secondary buttons 16; choice cards 14; feed cards 20; panels 16; inputs 12; photo slots 10; pills and chips fully rounded.
- **Shadows:** floating controls `0 2 8 rgba(21,23,28,0.12)`; bottom sheets `0 -4 16 rgba(21,23,28,0.10)`.
- **Drag handle:** 40 × 4, radius 2, `lineStrong`, centered, 12 px from sheet top.

---

## Components

| Component | Spec |
|---|---|
| **PrimaryButton** | Height 56, radius 16, `accent` fill, white `buttonPrimary` label, optional 20–22 px white icon left of label |
| **SecondaryButton** | Height 56, radius 16, 2 px `ink` border, white fill, `ink` `buttonSecondary` label |
| **ChoiceCard** | Height 72, radius 14, 1.5 px `line` border. Selected: 2 px `accent` border, `accentTint` fill, text in `accentDark` |
| **PillToggle** | Height 44, fully rounded, `ground` fill, 18 px checkbox tinted `accent`, `bodySmall` label |
| **FloatingPill / FloatingIconButton** | Height 48, white, fully rounded, floating shadow; icon buttons 48 × 48 |
| **BottomSheetPanel** | White, top radius 24, sheet shadow, drag handle |
| **StatBlock** | `label` on top (muted), `statValue` below; three per row in a grid |
| **StopCard** | `ground` panel radius 16, padding 14, 56 × 56 thumbnail radius 12, overline + name + muted detail |
| **FilterChip** | Height 36, fully rounded. Selected: `ink` fill, white text. Unselected: white, 1.5 px `lineStrong` border |
| **BottomTabs** | Height 76 incl. bottom padding, white, top border `line`; 22 px stroke icons; active = `accent` |
| **Route line** | 6 px `accent`, round joins, on an 11 px white casing. Ridden part `riddenRoute`. Unconfirmed closing segment: 4 px dashed `accent` (8 on, 7 off) |
| **Markers** | Rider: 10 px radius `rider` dot, 3 px white ring, 24 px halo at 15% opacity. Main stop: 16 px radius `ink` circle with white flag icon. Custom loop points: 13 px radius `accent` circles with white numbers; start point "S" in `rider` |
| **PasyarTextField** | Label above (13 / 600 `muted`), 6 px gap, field height 52, radius 12, 1.5 px `line` border, 14 px side padding, 16 px text; password fields have a 44 × 44 eye toggle on the right; helper text 13 `muted` |
| **SocialButton** | Height 52, radius 14, 16 / 600 label, 26 px circle with the provider mark. Apple: `ink` fill, white text, shown first. Google: white, 1.5 px `line` border. Full width on Log in, half width side by side on Register. In the real app use the official Apple and Google logos and follow their button guidelines. No other providers |
| **OrDivider** | 1 px `line` rules either side of 14 px `muted` text |
| **StepProgress** | Overline "STEP X OF N" in `accentDark`, then N equal segments, 6 px tall, radius 3, 6 px gap; done = `accent`, todo = `line` |
| **SafetyRow** | `ground` panel, radius 16, padding 12 × 14, 24 px `accentDark` stroke icon, 15 px text with a bold lead phrase |
| **Welcome (dark)** | Full `ink` background; roads in `#262930` / `#30343C`; loop in `accent`; secondary button = 2 px white outline with white label |
| **Profile cover** | Full width, 150 tall below the status bar. Photo (BoxFit.cover) with a soft dark gradient at the top, or the default: `accentDark` ground, `coverRoad` roads, a `taglineOnInk` loop at 80%. White 44 px round icon buttons at the top (back / share / settings / ⋯). Own profile: "Edit cover" chip bottom-right, 32 tall, fully rounded, `coverChip`, white camera icon + 13 / 600 text. A 3 px white progress bar while uploading |
| **Profile header** | 84 px rounded-square avatar (radius 24, 4 px white border, floating shadow) overlapping the cover by 40 px on the left; on the right a 38 px pill: Edit profile / Follow (`accent`, white 14 / 700) or Following (white, 1.5 px `line` border). Then name 20 / 700, "@username · bike · town" 14 `muted`, bio 14, "n followers · n following" with bold numbers (tappable) |
| **Stat tiles** | Three in a row, 8 px gap, radius 14, padding 10 × 12; value 18 / 700, label 12. km ridden: `accentTint` with `accentDark` text; the others `ground` |
| **Profile tabs** | Pills 36 tall (44 tap area), fully rounded. Active: `ink` fill, white text. Inactive: white with 1.5 px `line` border |
| **Ride card** | 2-column grid, 132 tall, radius 16, 8 px gap: the post's first photo (or route), dark bottom gradient, loop name 13 / 700 and km 12 in white |
| **Icons** | Simple 2–2.2 px stroke icons (Lucide-style). Use `lucide_icons` or similar. No emoji |

---

## Rules for building screens

1. Before building a screen, open its screenshot and mockup. List the elements you see, top to bottom, then build them in that order.
2. Use only the tokens and components above. No new colors, fonts, or radii without asking.
3. Keep every touch target at least 44 × 44 (riders may wear gloves).
4. After building a screen, add a golden test at 390 × 844 (use `alchemist` or `golden_toolkit`), then compare it side by side with the screenshot and fix differences in spacing, sizes, and colors.
5. Navigation and riding screens must stay glanceable: big text, few elements, nothing that requires reading while moving.
