import { assert, assertAlmostEquals, assertEquals } from '@std/assert';

import { destination, type LngLat } from './geometry.ts';
import { parseRoute, routeBody } from './graphhopper.ts';
import { createHandler, type Deps, MAX_CALLS } from './handler.ts';
import {
  correctedDistance,
  isCloseEnough,
  meetsPreferences,
  penalty,
  type Preferences,
  warningsFor,
} from './plan.ts';

const start: LngLat = [121.457, 16.672];

// --- plan -----------------------------------------------------------------------

const quick: Preferences = {
  targetM: 50_000,
  avoidHighways: true,
  avoidUnpaved: false,
};

Deno.test('corrected distance follows target/actual, within limits', () => {
  assertAlmostEquals(correctedDistance(120_000, 150_000, 120_000), 96_000, 1);
  assertEquals(correctedDistance(50_000, 1_000_000, 50_000), 5_000);
  assertEquals(correctedDistance(50_000, 1_000, 50_000), 100_000);
  assert(isCloseEnough(60_000, 50_000));
  assert(!isCloseEnough(68_600, 50_000));
});

Deno.test('preferences: expressways only matter when avoiding highways', () => {
  const onExpressway = { distance_m: 50_000, motorway_m: 8_000, unpaved_m: 0 };
  assert(!meetsPreferences(onExpressway, quick));
  assert(meetsPreferences(onExpressway, { ...quick, avoidHighways: false }));
  assert(
    penalty(onExpressway, quick) >
      penalty({ ...onExpressway, distance_m: 60_000, motorway_m: 0 }, quick),
  );
  assertEquals(warningsFor(onExpressway, quick), [
    'This loop uses an expressway for about 8 km.',
  ]);
});

Deno.test('preferences: known unpaved road when avoiding unpaved', () => {
  const p = { ...quick, avoidHighways: false, avoidUnpaved: true };
  const dirt = { distance_m: 50_000, motorway_m: 0, unpaved_m: 3_400 };
  assert(!meetsPreferences(dirt, p));
  assertEquals(warningsFor(dirt, p), ['About 3 km of this loop is unpaved.']);
  assertEquals(warningsFor({ ...dirt, unpaved_m: 500 }, p), []);
});

// --- GraphHopper body and parsing -------------------------------------------------

Deno.test('body: car round trip with the distance, seed and details', () => {
  assertEquals(routeBody(start, 50_000.4, 7), {
    points: [start],
    profile: 'car',
    algorithm: 'round_trip',
    'round_trip.distance': 50_000,
    'round_trip.seed': 7,
    points_encoded: false,
    instructions: true,
    locale: 'en',
    details: ['road_class', 'surface'],
  });
});

const loop: LngLat[] = [
  start,
  destination(start, 0, 2_000),
  destination(destination(start, 0, 2_000), 90, 2_000),
  destination(start, 90, 2_000),
  start,
];

function ghResponse({
  km = 52.3456,
  roadClass = [[0, 4, 'primary']] as unknown[],
  surface = [[0, 4, 'missing']] as unknown[],
} = {}) {
  return {
    paths: [{
      distance: km * 1000,
      time: 4_000_400,
      points: { type: 'LineString', coordinates: loop },
      instructions: [
        { text: 'Continue', street_name: '', distance: 2000.4, time: 120_600, sign: 0, interval: [0, 1] },
        { text: 'Turn right onto Maharlika Highway', street_name: 'Maharlika Highway', distance: 2000, time: 100_000, sign: 2, interval: [1, 2] },
        { text: 'Arrive at destination', street_name: '', distance: 0, time: 0, sign: 4, interval: [4, 4] },
      ],
      details: { road_class: roadClass, surface },
    }],
  };
}

Deno.test('parse: route, steps in seconds, and road meters', () => {
  const r = parseRoute(ghResponse({
    roadClass: [[0, 1, 'motorway'], [1, 4, 'primary']],
    surface: [[0, 2, 'missing'], [2, 3, 'gravel'], [3, 4, 'asphalt']],
  }));
  assertEquals(r.distance_m, 52_346);
  assertEquals(r.duration_s, 4_000);
  assertEquals(r.steps[0].duration_s, 121);
  assertEquals(r.steps[1].name, 'Maharlika Highway');
  assertEquals(r.steps[1].sign, 2);
  assertEquals(r.steps[1].way_points, [1, 2]);
  assertAlmostEquals(r.motorway_m, 2_000, 2);
  assertAlmostEquals(r.unpaved_m, 2_000, 2);
});

Deno.test('parse: a dead-end spur is cut from the route, steps and meters', () => {
  // The rectangle with a 1 km spur north from the top-left corner:
  // 0 start, 1 corner, 2 spur end, 3 corner again, 4 far corner, ...
  const corner = loop[1];
  const tip = destination(corner, 0, 1_000);
  const coordinates = [start, corner, tip, corner, loop[2], loop[3], start];
  const r = parseRoute({
    paths: [{
      distance: 10_000,
      time: 1_000_000,
      points: { coordinates },
      instructions: [
        { text: 'Continue', distance: 2000, time: 100_000, sign: 0, interval: [0, 1] },
        { text: 'Turn left', distance: 1000, time: 100_000, sign: -2, interval: [1, 2] },
        { text: 'Make a U-turn', distance: 1000, time: 100_000, sign: -98, interval: [2, 3] },
        { text: 'Turn right', distance: 2000, time: 100_000, sign: 2, interval: [3, 4] },
        { text: 'Arrive', distance: 0, time: 0, sign: 4, interval: [6, 6] },
      ],
      details: {
        road_class: [[0, 6, 'motorway']],
        surface: [[1, 3, 'gravel']],
      },
    }],
  });
  assertEquals(r.coordinates, [start, corner, loop[2], loop[3], start]);
  assertEquals(r.distance_m, 8_000);
  assertEquals(r.duration_s, 800);
  assertEquals(r.steps.map((s) => s.instruction), ['Continue', 'Turn right', 'Arrive']);
  assertEquals(r.steps.map((s) => s.way_points), [[0, 1], [1, 2], [4, 4]]);
  assertAlmostEquals(r.motorway_m, 8_000, 5);
  assertEquals(r.unpaved_m, 0);
});

// --- handler --------------------------------------------------------------------

function deps(overrides: Partial<Deps> & { responses?: Response[] } = {}) {
  const bodies: Record<string, unknown>[] = [];
  const responses = overrides.responses ??
    [new Response(JSON.stringify(ghResponse()))];
  return {
    bodies,
    deps: {
      consumeQuota: overrides.consumeQuota ?? (() => Promise.resolve(true)),
      queryPlaces: overrides.queryPlaces ??
        (() => Promise.resolve([])),
      callRouting: overrides.callRouting ?? ((body: unknown) => {
        bodies.push(body as Record<string, unknown>);
        return Promise.resolve(responses.shift()!);
      }),
    } satisfies Deps,
  };
}

const ok = (opts: Parameters<typeof ghResponse>[0] = {}) =>
  new Response(JSON.stringify(ghResponse(opts)));
const noPoint = () =>
  new Response(
    JSON.stringify({ message: 'Could not find a valid point after 2 tries' }),
    { status: 400 },
  );

const post = (body: unknown) =>
  new Request('http://local/generate-loop', {
    method: 'POST',
    body: JSON.stringify(body),
  });

const valid = {
  lat: start[1], lng: start[0], duration: 'quick',
  avoidHighways: true, avoidUnpaved: false, seed: 11,
};

Deno.test('returns the route, stats and seed in one call', async () => {
  const { deps: d, bodies } = deps();
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.route.type, 'LineString');
  assertEquals(body.route.coordinates.length, loop.length);
  assertEquals(body.distance_m, 52_346);
  assertEquals(body.seed, 11);
  assertEquals(body.warnings, []);
  assertEquals(body.steps.length, 3);
  assertEquals(typeof body.backtracking_ratio, 'number');
  assertEquals(typeof body.curviness_score, 'number');
  assertEquals(bodies.length, 1);
});

Deno.test('too long: retries the same seed with a shorter distance', async () => {
  const { deps: d, bodies } = deps({ responses: [ok({ km: 80 }), ok({ km: 55 })] });
  const body = await (await createHandler(d)(post(valid))).json();
  assertEquals(body.distance_m, 55_000);
  assertEquals(bodies[1]['round_trip.seed'], 11);
  assertAlmostEquals(bodies[1]['round_trip.distance'] as number, 31_250, 1);
});

Deno.test('uses an expressway: tries the next seed and keeps the clean one', async () => {
  const expressway = ok({ roadClass: [[0, 4, 'motorway']] });
  const { deps: d, bodies } = deps({ responses: [expressway, ok()] });
  const body = await (await createHandler(d)(post(valid))).json();
  assertEquals(body.seed, 12);
  assertEquals(body.motorway_m, 0);
  assertEquals(bodies.length, 2);
});

Deno.test('expressway on every try: best loop plus a warning', async () => {
  const expressway = () => ok({ roadClass: [[0, 4, 'motorway']] });
  const { deps: d, bodies } = deps({
    responses: Array.from({ length: MAX_CALLS }, expressway),
  });
  const body = await (await createHandler(d)(post(valid))).json();
  assertEquals(bodies.length, MAX_CALLS);
  assertEquals(body.warnings.length, 1);
  assert(body.warnings[0].includes('expressway'));
});

Deno.test('no road at a random point: next seed', async () => {
  const { deps: d } = deps({ responses: [noPoint(), ok()] });
  const body = await (await createHandler(d)(post(valid))).json();
  assertEquals(body.seed, 12);
});

Deno.test('no route on every try is a friendly 422', async () => {
  const { deps: d } = deps({
    responses: Array.from({ length: MAX_CALLS }, noPoint),
  });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error.code, 'no_route');
});

Deno.test('over the hourly limit: 429 without routing', async () => {
  const { deps: d, bodies } = deps({ consumeQuota: () => Promise.resolve(false) });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error.code, 'limit_reached');
  assertEquals(bodies.length, 0);
});

Deno.test('busy and down stop without spending more calls', async () => {
  const quota = deps({ responses: [new Response('{}', { status: 429 })] });
  const res = await createHandler(quota.deps)(post(valid));
  assertEquals(res.status, 503);
  assertEquals((await res.json()).error.code, 'routing_busy');
  assertEquals(quota.bodies.length, 1);

  const timeout = new DOMException('timed out', 'TimeoutError');
  const slow = deps({ callRouting: () => Promise.reject(timeout) });
  assertEquals(
    (await (await createHandler(slow.deps)(post(valid))).json()).error.code,
    'routing_busy',
  );

  const offline = deps({ callRouting: () => Promise.reject(new TypeError('x')) });
  const res2 = await createHandler(offline.deps)(post(valid));
  assertEquals(res2.status, 502);
  assertEquals((await res2.json()).error.code, 'routing_down');
});

Deno.test('a failure after a usable loop still returns that loop', async () => {
  const { deps: d } = deps({
    responses: [ok({ km: 80 }), new Response('{}', { status: 500 })],
  });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).distance_m, 80_000);
});

Deno.test('main stop and fuel from nearby places', async () => {
  const mid = loop[2]; // the far corner, halfway around
  const seen: { points: number; radius: number }[] = [];
  const { deps: d } = deps({
    queryPlaces: (_req, line, radius) => {
      seen.push({ points: line.coordinates.length, radius });
      return Promise.resolve([
        { name: 'Overlook', type: 'viewpoint', lat: mid[1], lng: mid[0] + 0.003 },
        { name: 'Petron', type: 'fuel', lat: start[1] + 0.001, lng: start[0] },
      ]);
    },
  });
  const body = await (await createHandler(d)(post(valid))).json();
  assertEquals(body.main_stop.name, 'Overlook');
  assertEquals(body.main_stop.type, 'viewpoint');
  assertEquals(body.fuel_stops.length, 1);
  assertEquals(seen, [{ points: loop.length, radius: 650 }]);
});

Deno.test('places unavailable: still a loop, farthest point as the stop', async () => {
  const { deps: d } = deps({
    queryPlaces: () => Promise.reject(new Error('Overpass 504')),
  });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.main_stop.type, 'turnaround');
  assertEquals(body.fuel_stops, []);
});

Deno.test('bad input is a 400', async () => {
  const { deps: d } = deps();
  for (const bad of [
    {},
    { ...valid, lat: 120 },
    { ...valid, duration: 'week' },
    { ...valid, seed: -1 },
    { ...valid, avoidHighways: 'yes' },
  ]) {
    const res = await createHandler(d)(post(bad));
    assertEquals(res.status, 400, JSON.stringify(bad));
    await res.body?.cancel();
  }
});

Deno.test('far too long on every try: a friendly 422, not a 4-hour quick loop', async () => {
  const { deps: d, bodies } = deps({
    responses: [ok({ km: 219 }), ok({ km: 150 }), ok({ km: 95 })],
  });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error.code, 'too_long');
  assertEquals(bodies.length, MAX_CALLS);
  // Each retry asks for less, below the old 30% floor.
  assert((bodies[2]['round_trip.distance'] as number) < 15_000);
});

Deno.test('a long first try corrected to a usable loop', async () => {
  const { deps: d } = deps({ responses: [ok({ km: 219 }), ok({ km: 58 })] });
  const res = await createHandler(d)(post(valid));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).distance_m, 58_000);
});
