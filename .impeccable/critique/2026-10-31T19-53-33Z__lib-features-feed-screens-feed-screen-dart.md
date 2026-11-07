---
target: feed
total_score: 30
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
target_identity: "file:C:\\Users\\ASUS TUF\\pasyarph\\lib\\features\\feed\\screens\\feed_screen.dart"
target_fingerprint: "sha256:a04db9027541ce920e0f757e5aaea8994560a8ac11abdc40f915846c03c0f825"
target_path: "C:\\Users\\ASUS TUF\\pasyarph\\lib\\features\\feed\\screens\\feed_screen.dart"
timestamp: 2026-10-31T19-53-33Z
slug: lib-features-feed-screens-feed-screen-dart
---
Method: design review only (detector not applicable, native platform)

Target: lib/features/feed/screens/feed_screen.dart (Feed tab, source + 390 px renders). Mode: Operate. Second run, after onboard, clarify, text posts, harden and polish.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Loading, refresh, paging and errors all visible; nothing tells a rider about new activity (no notifications yet) |
| 2 | Match System / Real World | 3 | "rode a 25 km loop", "Loop in Rizal", "No rides near you yet"; English only for now |
| 3 | User Control and Freedom | 3 | TRY AGAIN, tap Feed to top, See more; text posts can't be edited after posting |
| 4 | Consistency and Standards | 3 | DESIGN.md tokens throughout; header now differs from the mockup (no Search or bell) |
| 5 | Error Prevention | 3 | Posting blocked while moving, empty text can't be posted, 10-photo limit enforced |
| 6 | Recognition Rather Than Recall | 3 | The image button is icon-only and now means "post a ride", next to a row that also takes photos |
| 7 | Flexibility and Efficiency | 3 | Tap-to-top, one-tap RIDE IT, Global fallback; no search |
| 8 | Aesthetic and Minimalist Design | 3 | Clean; distance said twice at most; long posts clamp |
| 9 | Error Recovery | 3 | Errors say what happened and offer TRY AGAIN in place |
| 10 | Help and Documentation | 3 | Every empty state names a next step |
| **Total** | | **30/40** | **Good** |

## Design Specificity Verdict

Still a familiar social-feed frame, but now more of it is Pasyar's own: the home feed always offers a ride (Global fallback, GENERATE A LOOP), loops read as places, and text posts are kept honest (no route, never in Near you). The remaining generic part is the composer row, which now looks exactly like Facebook's.

Deterministic scan: not applicable (native platform).

## Priority Issues

1. [P2] Two ways to post, one unlabeled. The image button (icon only, "Post photos from a ride") sits beside "Write a post…", which also takes photos. A rider wanting a photo post will tap the photo icon and land in the ride picker or the "No rides to post yet" message. Fix: make the icon open the write screen with the photo picker, and move "Post a ride" into the write screen (or the ride summary) as an explicit choice; or give the button a visible "Ride" label. Command: /impeccable clarify
2. [P2] No way to find riders or posts. Search is hidden; Following only fills by tapping names on posts you happen to see. Fix: build search (riders, clubs, places), or add "Riders near you to follow" to the empty Following state. Command: /impeccable shape

## Minor Observations

- Text posts can't be edited (only the caption of ride posts is updatable via RLS); add Edit to the ⋯ menu for one's own posts.
- The Write a post screen has no character counter until the 2000 limit stops typing.
- Feed is English only; PRODUCT.md plans Filipino.

## Questions to Consider

- Should the image button simply start a post with photos, and ride posting move to where the ride ends?
- What should Search find first: riders, clubs, or places?
