import { assert, assertAlmostEquals, assertEquals } from '@std/assert';

import {
  backtrackingRatio,
  bearingDeg,
  curvinessScore,
  destination,
  haversineM,
  lengthM,
  type LngLat,
  spurMask,
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

const kept = (route: LngLat[]) => {
  const removed = spurMask(route);
  return route.filter((_, i) => !removed[i]);
};

Deno.test('spurs: a dead-end ridden out and back is cut at its mouth', () => {
  const rectangle: [number, number][] = [
    [0, 2_000], [90, 4_000], [180, 2_000], [270, 4_000],
  ];
  const withSpur = walk(start, [
    [0, 2_000], [90, 2_000], [0, 1_000], [180, 1_000],
    [90, 2_000], [180, 2_000], [270, 4_000],
  ]);
  const trimmed = kept(withSpur);
  assertAlmostEquals(lengthM(trimmed), 12_000, 5);
  assertEquals(trimmed.length, walk(start, rectangle).length);
  assert(backtrackingRatio(trimmed) < 0.02);
});

Deno.test('spurs: a spur off a spur goes too', () => {
  const route = walk(start, [
    [0, 2_000], [90, 2_000],
    [0, 1_000], [270, 500], [90, 500], [0, 500], [180, 1_500],
    [90, 2_000], [180, 2_000], [270, 4_000],
  ]);
  assertAlmostEquals(lengthM(kept(route)), 12_000, 5);
});

Deno.test('spurs: clean loops, hairpins and parallel roads are kept', () => {
  const rectangle = walk(start, [[0, 2_000], [90, 4_000], [180, 2_000], [270, 4_000]]);
  assertEquals(kept(rectangle).length, rectangle.length);
  const legs: [number, number][] = [];
  for (let i = 0; i < 20; i++) legs.push([i % 2 ? 300 : 60, 250]);
  const switchbacks = walk(start, legs);
  assertEquals(kept(switchbacks).length, switchbacks.length);
  const parallel = walk(start, [[90, 3_000], [0, 100], [270, 3_000], [180, 100]]);
  assertEquals(kept(parallel).length, parallel.length);
});

Deno.test('spurs: the stem from home and pure out-and-backs are kept', () => {
  // Out a 1 km stem, round a rectangle, back down the stem.
  const stem = walk(start, [
    [0, 1_000], [0, 2_000], [90, 4_000], [180, 2_000], [270, 4_000], [180, 1_000],
  ]);
  assertEquals(kept(stem).length, stem.length);
  const outAndBack = walk(start, [[90, 5_000], [270, 5_000]]);
  assertEquals(kept(outAndBack).length, outAndBack.length);
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
