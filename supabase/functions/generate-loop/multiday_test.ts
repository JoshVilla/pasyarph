import { assert, assertEquals, assertNotEquals } from '@std/assert';

import { haversineM, type LngLat } from './geometry.ts';
import {
  chunks,
  crosses,
  islandAt,
  MAX_HOP_M,
  MIN_HOP_M,
  planRings,
  targetMeters,
  townPoint,
} from './multiday.ts';

const manila: LngLat = [120.9842, 14.5995];
const cebu: LngLat = [123.8854, 10.3157];
const davao: LngLat = [125.4553, 7.1907];

Deno.test('island: the nearest town decides; open sea is none', () => {
  assertEquals(islandAt(manila), 'luzon');
  assertEquals(islandAt(cebu), 'cebu');
  assertEquals(islandAt(davao), 'mindanao');
  assertEquals(islandAt([135, 15]), null);
});

Deno.test('a plan: right number of nights, a day apart, same island', () => {
  for (const days of [2, 3, 4, 5, 6, 7]) {
    const plan = planRings(manila, days, 0)[0];
    assertEquals(plan.towns.length, days - 1, `${days} days`);
    assert(plan.towns.every((t) => t.island === 'luzon'));
    assertEquals(new Set(plan.towns).size, plan.towns.length, 'no town twice');
    const stops = [manila, ...plan.towns.map(townPoint)];
    for (let i = 1; i < stops.length; i++) {
      const hop = haversineM(stops[i - 1], stops[i]);
      assert(hop >= MIN_HOP_M && hop <= MAX_HOP_M, `${days} days hop ${i}`);
    }
  }
});

Deno.test('the best plans from Manila go round, not across themselves', () => {
  const plan = planRings(manila, 6, 0)[0];
  const ring = [manila, ...plan.towns.map(townPoint), manila];
  for (let i = 0; i < ring.length - 1; i++) {
    for (let j = i + 2; j < ring.length - 1; j++) {
      if (i === 0 && j === ring.length - 2) continue; // both touch home
      assert(
        !crosses(ring[i], ring[i + 1], ring[j], ring[j + 1]),
        `hops ${i} and ${j} cross`,
      );
    }
  }
});

Deno.test('Shuffle: other seeds, other towns or the other way round', () => {
  const a = planRings(manila, 5, 0)[0].towns.map((t) => t.name);
  const b = planRings(manila, 5, 2)[0].towns.map((t) => t.name);
  const reversed = planRings(manila, 5, 1)[0].towns.map((t) => t.name);
  assertNotEquals(a, b);
  assertEquals(new Set(reversed).size, reversed.length);
  // Odd seeds ride a plan the other way: it starts where another ends.
  const firsts = planRings(manila, 5, 0).map((p) => p.towns.at(-1)!.name);
  assert(firsts.includes(reversed[0]));
});

Deno.test('a small island gets fewer nights instead of nothing', () => {
  const plan = planRings(cebu, 7, 0)[0];
  assert(plan.towns.length >= 1 && plan.towns.length < 6);
  assert(plan.towns.every((t) => t.island === 'cebu'));
});

Deno.test('nowhere near a town: no plan', () => {
  assertEquals(planRings([135, 15], 3, 0), []);
});

Deno.test('targets and chunks', () => {
  assertEquals(targetMeters(5), 1_400_000);
  const pts: LngLat[] = Array.from({ length: 8 }, (_, i) => [120 + i, 15]);
  assertEquals(chunks(pts).map((c) => c.length), [5, 4]);
  assertEquals(chunks(pts)[1][0], pts[4]);
  assert(crosses([0, 0], [2, 2], [0, 2], [2, 0]));
  assert(!crosses([0, 0], [1, 0], [0, 1], [1, 1]));
});
