import { assert, assertAlmostEquals, assertEquals } from '@std/assert';

import { destination, haversineM, lengthM, type LngLat } from './geometry.ts';
import { assembleRide, joinLoop, joinLines, loopTimeS, parseSharedLoop } from './ride.ts';

const home: LngLat = [121.457, 16.672];

/** A trimmed loop: a 2 km x 2 km square starting 800 m north of [home]
 * and ending 800 m east of it (the corner at home cut off). */
function trimmedSquare(): LngLat[] {
  const out: LngLat[] = [];
  const legs: [number, number][] = [[0, 1200], [90, 2000], [180, 2000], [270, 1200]];
  let at = destination(home, 0, 800);
  out.push(at);
  for (const [bearing, meters] of legs) {
    for (let d = 100; d <= meters; d += 100) {
      at = destination(at, bearing, 100);
      out.push(at);
    }
  }
  return out;
}

Deno.test('parse: a loop_for_riding row, or null without a route', () => {
  const loop = parseSharedLoop({
    name: 'Sunday Falls Loop',
    shared_route: { type: 'LineString', coordinates: [[121.4, 16.6], [121.5, 16.7]] },
    distance_m: 118000,
    duration_s: 13800,
    curviness_score: 210,
    main_stop: { name: 'Talon', type: 'waterfall', lat: 16.7, lng: 121.46 },
  })!;
  assertEquals(loop.route.length, 2);
  assertEquals(loop.mainStop!.name, 'Talon');
  assertEquals(parseSharedLoop(null), null);
  assertEquals(parseSharedLoop({ shared_route: null }), null);
});

Deno.test('join: the nearest point, and the loop split there', () => {
  const route = trimmedSquare();
  // A rider 600 m west of the top-right corner's leg... east side midpoint.
  const eastMid = destination(destination(home, 0, 1000), 90, 2000);
  const rider = destination(eastMid, 90, 600);
  const join = joinLoop(route, rider);
  assertAlmostEquals(join.offM, 600, 5);
  assert(haversineM(join.point, eastMid) < 10);
  assertAlmostEquals(lengthM(join.before) + lengthM(join.after), lengthM(route), 1);
  assertEquals(join.after[0], join.point);
  assertEquals(join.before[join.before.length - 1], join.point);
});

Deno.test('assemble: approach, round the loop, the gap, back the same way', () => {
  const route = trimmedSquare();
  const rider = destination(route[30], 90, 500);
  const join = joinLoop(route, rider);
  const approach = [rider, join.point];
  const gap = [route[route.length - 1], home, route[0]]; // connector stand-in
  const ride = assembleRide(join, approach, gap);

  assertEquals(ride[0], rider);
  assertEquals(ride[ride.length - 1], rider);
  // Every loop point is ridden, and the connector bridges the cut corner.
  assertAlmostEquals(
    lengthM(ride),
    lengthM(route) + lengthM(gap) + 2 * haversineM(rider, join.point),
    5,
  );
});

Deno.test('join lines drops repeated points where pieces meet', () => {
  const a: LngLat = [121, 16];
  const b: LngLat = [121.01, 16];
  assertEquals(joinLines([a, b], [b, a]), [a, b, a]);
});

Deno.test('loop time at the loop\'s own speed', () => {
  const loop = parseSharedLoop({
    shared_route: { coordinates: [[0, 0], [0, 1]] },
    distance_m: 100000,
    duration_s: 7200,
  })!;
  assertEquals(loopTimeS(loop, 50000), 3600);
});
