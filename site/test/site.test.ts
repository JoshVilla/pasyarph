// Unit tests for the share-link site. Run: npm test (see package.json).
import assert from "node:assert/strict";
import { test } from "node:test";

import { linkPage, mapImage } from "../lib/handlers";
import { encodePolyline, routeSvg, staticMapUrl, thin } from "../lib/map";
import { blockedMessage, escape, openInAppUrl } from "../lib/page";
import { formatDistance, formatRideTime } from "../lib/preview";

const env = { SUPABASE_URL: "https://x.supabase.co", SUPABASE_ANON_KEY: "anon", MAPTILER_KEY: "k" };
const noKey = { ...env, MAPTILER_KEY: undefined };
const loopId = "22000000-0000-0000-0000-000000000001";
const route = {
  type: "LineString" as const,
  coordinates: [
    [121.3, 14.5],
    [121.35, 14.55],
    [121.4, 14.5],
  ] as [number, number][],
};

function fakeSupabase(body: unknown, status = 200) {
  const calls: { url: string; init: RequestInit }[] = [];
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(JSON.stringify(body), { status });
  }) as typeof fetch;
  return calls;
}

function ctx(path: string, id: string, ua = "Mozilla/5.0 (Linux; Android 14)", e: typeof env | typeof noKey = env) {
  return {
    request: new Request(`https://pasyar.pages.dev${path}`, {
      headers: { "User-Agent": ua },
    }),
    env: e,
    params: { id },
  };
}

test("encodePolyline matches Google's reference example", () => {
  // developers.google.com/maps/documentation/utilities/polylinealgorithm
  assert.equal(
    encodePolyline([
      [-120.2, 38.5],
      [-120.95, 40.7],
      [-126.453, 43.252],
    ]),
    "_p~iF~ps|U_ulLnnqC_mqNvxq`@",
  );
});

test("thin keeps the ends and at most about max points", () => {
  const coords = Array.from({ length: 1000 }, (_, i) => [i, i] as [number, number]);
  const out = thin(coords, 100);
  assert.ok(out.length <= 101);
  assert.deepEqual(out[0], [0, 0]);
  assert.deepEqual(out[out.length - 1], [999, 999]);
});

test("staticMapUrl draws a cased route with the app's style", () => {
  const url = new URL(staticMapUrl(route.coordinates, "k"));
  assert.match(url.pathname, /\/maps\/streets-v2-pastel\/static\/auto\/600x315@2x\.png$/);
  const paths = url.searchParams.getAll("path");
  assert.equal(paths.length, 2);
  assert.match(paths[0], /^stroke:#FFFFFF\|width:8\|fill:none\|enc:/);
  assert.match(paths[1], /^stroke:#C2410C\|width:4/);
  assert.equal(url.searchParams.get("key"), "k");
});

test("routeSvg draws the route on the map color", () => {
  const svg = routeSvg(route.coordinates);
  assert.match(svg, /<polyline points="[\d., ]+"/);
  assert.match(svg, /fill="#F7F7F7"/);
});

test("formats match the app", () => {
  assert.equal(formatDistance(82000), "82 km");
  assert.equal(formatDistance(8400), "8.4 km");
  assert.equal(formatRideTime(13800), "3 h 50");
  assert.equal(formatRideTime(14400), "4 h");
  assert.equal(formatRideTime(2700), "45 min");
});

test("escape stops HTML injection", () => {
  assert.equal(escape(`<b a="1">'&`), "&lt;b a=&quot;1&quot;&gt;&#39;&amp;");
});

test("openInAppUrl opens the app on Android, else the Play Store", () => {
  const url = openInAppUrl(new URL(`https://pasyar.pages.dev/l/${loopId}`));
  assert.ok(url.startsWith(`intent://pasyar.pages.dev/l/${loopId}#Intent;scheme=https;`));
  assert.match(url, /S\.browser_fallback_url=https%3A%2F%2Fplay\.google\.com/);
});

test("blocked links explain why", () => {
  assert.equal(blockedMessage({ status: "ok" }, "loop"), null);
  assert.match(
    blockedMessage({ status: "club", club_name: "Rizal Riders" }, "loop")!.text,
    /members of Rizal Riders/,
  );
  assert.equal(blockedMessage({ status: "private" }, "loop")!.status, 404);
  assert.equal(blockedMessage({ status: "missing" }, "ride")!.title, "Ride not found");
});

test("a public loop page has its name, stats, map and store buttons", async () => {
  const calls = fakeSupabase({
    status: "ok",
    kind: "loop",
    name: "Tanay <Sunrise>",
    distance_m: 82000,
    duration_s: 13800,
    main_stop: "Daranak Falls",
    route,
    author: "Ana",
  });
  const res = await linkPage(ctx(`/l/${loopId}`, loopId), "loop");
  const html = await res.text();
  assert.equal(res.status, 200);
  assert.equal(calls[0].url, "https://x.supabase.co/rest/v1/rpc/link_preview");
  assert.deepEqual(JSON.parse(calls[0].init.body as string), { p_kind: "loop", p_id: loopId });
  assert.match(html, /<h1>Tanay &lt;Sunrise&gt;<\/h1>/);
  assert.match(html, /<title>Pasyar tayo! Tanay &lt;Sunrise&gt; · 82 km<\/title>/);
  assert.match(html, /3 h 50/);
  assert.match(html, /Main stop: Daranak Falls/);
  assert.match(html, new RegExp(`og:image" content="https://pasyar.pages.dev/map/l/${loopId}.png`));
  assert.match(html, /Open in Pasyar/);
  assert.match(html, /Get it on Google Play/);
});

test("without a static-map key, loop links have no preview image", async () => {
  fakeSupabase({ status: "ok", name: "Loop", route });
  const html = await (await linkPage(ctx(`/l/${loopId}`, loopId, "Android", noKey), "loop")).text();
  assert.doesNotMatch(html, /og:image/);
  assert.match(html, /<img class="map"/, "the page still shows the route");
});

test("the Open in Pasyar button is only shown on Android", async () => {
  fakeSupabase({ status: "ok", name: "Loop", route });
  const res = await linkPage(ctx(`/l/${loopId}`, loopId, "iPhone"), "loop");
  assert.doesNotMatch(await res.text(), /Open in Pasyar/);
});

test("a post page uses its photo as the preview image", async () => {
  fakeSupabase({ status: "ok", kind: "post", name: "Loop", route, photo: "u/p/0.jpg", caption: "Sulit!" });
  const html = await (await linkPage(ctx(`/p/${loopId}`, loopId), "post")).text();
  assert.match(html, /og:image" content="https:\/\/x\.supabase\.co\/storage\/v1\/object\/public\/post-photos\/u\/p\/0\.jpg/);
  assert.match(html, /Sulit!/);
});


test("a text post page shows who wrote it and their words, no map", async () => {
  fakeSupabase({ status: "ok", kind: "post", author: "Ana", caption: "Open ba ang Daranak?" });
  const html = await (await linkPage(ctx(`/p/${loopId}`, loopId), "post")).text();
  assert.match(html, /<h1>Ana on Pasyar<\/h1>/);
  assert.match(html, /Open ba ang Daranak\?/);
  assert.match(html, /class="overline">Post/);
  assert.doesNotMatch(html, /class="map"/);
  assert.doesNotMatch(html, /og:image/);
});
test("private, missing and bad links don't leak anything", async () => {
  fakeSupabase({ status: "private" });
  const res = await linkPage(ctx(`/l/${loopId}`, loopId), "loop");
  assert.equal(res.status, 404);
  assert.match(await res.text(), /Private loop/);

  const calls = fakeSupabase({ status: "ok" });
  const bad = await linkPage(ctx("/l/not-a-uuid", "not-a-uuid"), "loop");
  assert.equal(bad.status, 404);
  assert.equal(calls.length, 0, "no lookup for a malformed id");
});

test("Supabase down shows a try-again page", async () => {
  fakeSupabase({}, 500);
  const res = await linkPage(ctx(`/l/${loopId}`, loopId), "loop");
  assert.equal(res.status, 503);
});

test("the map falls back to SVG without a MapTiler key", async () => {
  fakeSupabase({ status: "ok", route });
  const android = "Android";
  const res = await mapImage(ctx(`/map/l/${loopId}.png`, `${loopId}.png`, android, noKey), "loop");
  assert.equal(res.headers.get("Content-Type"), "image/svg+xml");

  // MapTiler refusing the key (no Static Maps API on the plan) also falls back.
  let n = 0;
  globalThis.fetch = (async () =>
    n++ === 0
      ? new Response(JSON.stringify({ status: "ok", route }))
      : new Response("Invalid key", { status: 403 })) as typeof fetch;
  const refused = await mapImage(ctx(`/map/l/${loopId}.png`, `${loopId}.png`), "loop");
  assert.equal(refused.headers.get("Content-Type"), "image/svg+xml");

  fakeSupabase({ status: "club" });
  const club = await mapImage(ctx(`/map/l/${loopId}.png`, `${loopId}.png`), "loop");
  assert.equal(club.status, 404, "no map for loops the visitor can't see");
});
