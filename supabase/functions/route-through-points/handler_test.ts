import { assertEquals, assertThrows } from '@std/assert';

import type { LngLat } from '../generate-loop/geometry.ts';
import {
  chunk,
  createHandler,
  type Deps,
  parseRuns,
  RouteError,
  routingError,
  splitLegs,
} from './handler.ts';

const p = (i: number): LngLat => [121.4 + i * 0.01, 16.6];

// --- requests ---------------------------------------------------------------

Deno.test('runs: valid points pass, bad ones are rejected', () => {
  assertEquals(parseRuns({ runs: [[p(0), p(1)]] }), [[p(0), p(1)]]);
  assertThrows(() => parseRuns({ runs: [] }), RouteError);
  assertThrows(() => parseRuns({ runs: [[p(0)]] }), RouteError);
  assertThrows(() => parseRuns({ runs: [[p(0), [200, 0]]] }), RouteError);
  assertThrows(() => parseRuns({ runs: [[p(0), ['a', 1]]] }), RouteError);
  assertThrows(() => parseRuns(null), RouteError);
});

Deno.test('runs: at most 16 legs in one request', () => {
  const full = Array.from({ length: 17 }, (_, i) => p(i));
  assertEquals(parseRuns({ runs: [full] }).length, 1);
  assertThrows(() => parseRuns({ runs: [[...full, p(17)]] }), RouteError);
});

Deno.test('chunks: at most 5 points, sharing the joining point', () => {
  const pts = Array.from({ length: 9 }, (_, i) => p(i));
  assertEquals(chunk(pts), [pts.slice(0, 5), pts.slice(4, 9)]);
  assertEquals(chunk(pts.slice(0, 2)), [pts.slice(0, 2)]);
  assertEquals(chunk(pts.slice(0, 6)), [pts.slice(0, 5), pts.slice(4, 6)]);
  // Every leg is in exactly one chunk.
  const legs = chunk(pts).reduce((n, c) => n + c.length - 1, 0);
  assertEquals(legs, pts.length - 1);
});

// --- responses ----------------------------------------------------------------

/** A GraphHopper path through [n] points, 2 coordinates per leg, 1 km and
 * 60 s per coordinate step. */
function path(n: number) {
  const coords: LngLat[] = [];
  const instructions = [];
  for (let leg = 0; leg < n - 1; leg++) {
    const i = coords.length === 0 ? 0 : coords.length - 1;
    if (coords.length === 0) coords.push(p(0));
    coords.push([p(leg)[0] + 0.005, 16.61], p(leg + 1));
    instructions.push({
      sign: 0,
      interval: [i, i + 2],
      distance: 2000,
      time: 120_000,
      text: 'Continue',
    });
    instructions.push(
      leg === n - 2
        ? { sign: 4, interval: [i + 2, i + 2], distance: 0, time: 0 }
        : { sign: 5, interval: [i + 2, i + 2], distance: 0, time: 0 },
    );
  }
  return { paths: [{ points: { coordinates: coords }, instructions }] };
}

Deno.test('legs: split at each via point with their own distance and time', () => {
  const legs = splitLegs(path(4), 4);
  assertEquals(legs.length, 3);
  assertEquals(legs[0].coordinates.length, 3);
  assertEquals(legs[0].coordinates[0], p(0));
  assertEquals(legs[2].coordinates.at(-1), p(3));
  // Legs share their joining coordinate.
  assertEquals(legs[0].coordinates.at(-1), legs[1].coordinates[0]);
  for (const leg of legs) {
    assertEquals(leg.distance_m, 2000);
    assertEquals(leg.duration_s, 120);
  }
});

Deno.test('legs: a missing via point is an error, not a wrong split', () => {
  assertThrows(() => splitLegs(path(3), 4), RouteError);
  assertThrows(() => splitLegs({ paths: [] }, 2), RouteError);
});

Deno.test('errors: off-road points, busy and down', () => {
  assertEquals(
    routingError(400, { message: 'Cannot find point 2: 16.6,121.4' }).code,
    'off_road',
  );
  assertEquals(
    routingError(400, { message: 'Connection between locations not found' })
      .code,
    'no_route',
  );
  assertEquals(routingError(429, {}).code, 'routing_busy');
  assertEquals(routingError(500, {}).code, 'routing_down');
});

// --- handler ------------------------------------------------------------------

function deps(over: Partial<Deps> = {}) {
  const bodies: { points: LngLat[] }[] = [];
  const d: Deps = {
    consumeQuota: () => Promise.resolve(true),
    callRouting(body) {
      const b = body as { points: LngLat[] };
      bodies.push(b);
      return Promise.resolve(Response.json(path(b.points.length)));
    },
    ...over,
  };
  return { d, bodies };
}

const post = (body: unknown) =>
  new Request('http://x', { method: 'POST', body: JSON.stringify(body) });

Deno.test('handler: one list of legs per run, long runs in chunks', async () => {
  const { d, bodies } = deps();
  const long = Array.from({ length: 7 }, (_, i) => p(i));
  const res = await createHandler(d)(
    post({ runs: [[p(0), p(1)], long] }),
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.runs.map((r: unknown[]) => r.length), [1, 6]);
  assertEquals(bodies.map((b) => b.points.length), [2, 5, 3]);
});

Deno.test('handler: over the quota, no routing calls', async () => {
  const { d, bodies } = deps({ consumeQuota: () => Promise.resolve(false) });
  const res = await createHandler(d)(post({ runs: [[p(0), p(1)]] }));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error.code, 'limit_reached');
  assertEquals(bodies.length, 0);
});

Deno.test('handler: GraphHopper errors reach the app with a safe message', async () => {
  const { d } = deps({
    callRouting: () =>
      Promise.resolve(
        Response.json({ message: 'Cannot find point 1: 0,0' }, { status: 400 }),
      ),
  });
  const res = await createHandler(d)(post({ runs: [[p(0), p(1)]] }));
  assertEquals(res.status, 422);
  assertEquals(
    (await res.json()).error.message,
    'One of your points is too far from a road. Move it closer.',
  );
});
