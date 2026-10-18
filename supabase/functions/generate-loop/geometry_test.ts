import { assert, assertAlmostEquals, assertEquals } from '@std/assert';

import {
  backtrackingRatio,
  bearingDeg,
  curvinessScore,
  destination,
  haversineM,
  lengthM,
  type LngLat,
} from './geometry.ts';

// Cordon, Isabela.
const start: LngLat = [121.457, 16.672];

/** Walks [legs] of (bearing, meters) from [from], one vertex every 50 m. */
function walk(from: LngLat, legs: [number, number][]): LngLat[] {
  const out: LngLat[] = [from];
  let at = from;
  for (const [bearing, meters] of legs) {
    for (let d = 50; d <= meters; d += 50) {
      at = destination(at, bearing, 50);
      out.push(at);
    }
  }
  return out;
}

Deno.test('haversine: one degree of latitude is about 111 km', () => {
  assertAlmostEquals(haversineM([0, 0], [0, 1]), 111_195, 1);
});

Deno.test('destination and bearing agree', () => {
  const p = destination(start, 60, 5_000);
  assertAlmostEquals(haversineM(start, p), 5_000, 0.5);
  assertAlmostEquals(bearingDeg(start, p), 60, 0.1);
});

Deno.test('backtracking: out-and-back road is almost all overlap', () => {
  const route = walk(start, [[90, 5_000], [270, 5_000]]);
  assert(backtrackingRatio(route) > 0.9);
});

Deno.test('backtracking: a clean rectangle has none', () => {
  const route = walk(start, [[0, 2_000], [90, 4_000], [180, 2_000], [270, 4_000]]);
  assert(backtrackingRatio(route) < 0.02);
});

Deno.test('backtracking: a spur in a loop counts only the spur', () => {
  // 12 km rectangle with a 1 km dead-end spur ridden out and back (2 km).
  const route = walk(start, [
    [0, 2_000], [90, 2_000], [0, 1_000], [180, 1_000],
    [90, 2_000], [180, 2_000], [270, 4_000],
  ]);
  const ratio = backtrackingRatio(route);
  // ~2 km of 14 km, minus the turnaround.
  assert(ratio > 0.1 && ratio < 0.16, `ratio ${ratio}`);
});

Deno.test('backtracking: parallel roads 100 m apart are not overlap', () => {
  const route = walk(start, [[90, 3_000], [0, 100], [270, 3_000]]);
  assertEquals(backtrackingRatio(route), 0);
});

Deno.test('curviness: straight road is 0', () => {
  assertAlmostEquals(curvinessScore(walk(start, [[45, 5_000]])), 0, 0.5);
});

Deno.test('curviness: three right angles over 12 km is ~22.5°/km', () => {
  const route = walk(start, [[0, 2_000], [90, 4_000], [180, 2_000], [270, 4_000]]);
  assertAlmostEquals(lengthM(route), 12_000, 5);
  assertAlmostEquals(curvinessScore(route), 270 / 12, 1);
});

Deno.test('curviness: switchbacks score far higher than a straight road', () => {
  const legs: [number, number][] = [];
  for (let i = 0; i < 20; i++) legs.push([i % 2 ? 300 : 60, 250]);
  assert(curvinessScore(walk(start, legs)) > 200);
});

Deno.test('short or empty routes are 0', () => {
  assertEquals(backtrackingRatio([start]), 0);
  assertEquals(curvinessScore([start, start]), 0);
});
