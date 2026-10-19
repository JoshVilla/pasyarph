// Multi-day loops: one long loop through real overnight towns, about a
// day's ride apart, from the rider and back. GraphHopper's round trips use
// random points, which miss coastlines and famous routes at this size;
// hopping between towns gives loops like Manila → Baguio → Vigan →
// Pagudpud → Tuguegarao → Manila.

import { bearingDeg, haversineM, type LngLat } from './geometry.ts';
import { type Town, TOWNS } from './towns.ts';

export const MIN_DAYS = 2;
export const MAX_DAYS = 7;

/** Road distance a rider covers in a day, and road vs straight line. */
export const DAY_ROAD_M = 280_000;
export const ROAD_FACTOR = 1.4;

/** Straight-line distance between overnight towns. */
export const DAY_STRAIGHT_M = DAY_ROAD_M / ROAD_FACTOR;

/** A day's hop, straight line: shorter is a wasted day, longer too much. */
export const MIN_HOP_M = DAY_STRAIGHT_M * 0.4;
export const MAX_HOP_M = DAY_STRAIGHT_M * 1.35;

/** The last day home may run a bit longer. */
const MAX_LAST_HOP_M = DAY_STRAIGHT_M * 1.6;

/** Towns this far from the start can't tell us which island it's on. */
const ISLAND_RADIUS_M = 150_000;

/** Partial plans kept per day while searching. */
const BEAM = 400;

/** Seeds pick among this many of the best plans (Shuffle). */
const TOP_PLANS = 6;

export function targetMeters(days: number) {
  return days * DAY_ROAD_M;
}

const at = (town: Town): LngLat => [town.lng, town.lat];

export function townPoint(town: Town): LngLat {
  return at(town);
}

/** The island of the nearest town, or null when none is close. */
export function islandAt(point: LngLat, towns = TOWNS): string | null {
  let best: Town | null = null;
  let bestM = Infinity;
  for (const town of towns) {
    const m = haversineM(point, at(town));
    if (m < bestM) {
      best = town;
      bestM = m;
    }
  }
  return best && bestM <= ISLAND_RADIUS_M ? best.island : null;
}

export interface Ring {
  /** Overnight towns in riding order. */
  towns: Town[];
  /** Lower is better. */
  cost: number;
}

/** How far a hop is from a day's ride, squared and relative. */
function hopCost(m: number) {
  const off = (m - DAY_STRAIGHT_M) / DAY_STRAIGHT_M;
  return off * off;
}

/** Turning back on yourself: 0 straight on, 1 a full U-turn. */
function turnCost(a: LngLat, b: LngLat, c: LngLat) {
  const turn = Math.abs(((bearingDeg(b, c) - bearingDeg(a, b) + 540) % 360) - 180);
  return turn > 120 ? (turn - 120) / 60 : 0;
}

/** True when segments ab and cd cross (lng/lat as a plane: fine at this
 * size for telling a loop from a figure eight). */
export function crosses(a: LngLat, b: LngLat, c: LngLat, d: LngLat) {
  const side = (p: LngLat, q: LngLat, r: LngLat) =>
    Math.sign((q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]));
  return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
}

/** A loop crossing itself: an ugly figure eight, not a ring. */
const CROSSING_COST = 3;

/** Crossings of hop from-to with the hops before it (not the one it joins). */
function crossingCost(path: LngLat[], from: LngLat, to: LngLat, skipFirst = false) {
  let cost = 0;
  for (let i = skipFirst ? 1 : 0; i < path.length - 2; i++) {
    if (crosses(path[i], path[i + 1], from, to)) cost += CROSSING_COST;
  }
  return cost;
}

interface Partial {
  towns: Town[];
  cost: number;
}

/**
 * Plans of [nights] overnight towns from [start] and back: every hop a
 * day's ride, no town twice, no doubling back near an earlier stop. Beam
 * search, best first.
 */
function search(start: LngLat, nights: number, pool: Town[]): Ring[] {
  const usable = pool.filter((t) => haversineM(start, at(t)) >= MIN_HOP_M * 0.6);
  let beam: Partial[] = [{ towns: [], cost: 0 }];
  for (let depth = 0; depth < nights; depth++) {
    const next: Partial[] = [];
    for (const p of beam) {
      const from = p.towns.length ? at(p.towns[p.towns.length - 1]) : start;
      const before = p.towns.length > 1
        ? at(p.towns[p.towns.length - 2])
        : p.towns.length === 1
        ? start
        : null;
      for (const town of usable) {
        if (p.towns.includes(town)) continue;
        const to = at(town);
        const hop = haversineM(from, to);
        if (hop < MIN_HOP_M || hop > MAX_HOP_M) continue;
        let cost = p.cost + hopCost(hop);
        if (before) cost += turnCost(before, from, to);
        cost += crossingCost([start, ...p.towns.map(at)], from, to);
        // Coming back past an earlier night (or home, before the end).
        for (const earlier of [start, ...p.towns.slice(0, -1).map(at)]) {
          if (haversineM(earlier, to) < MIN_HOP_M) cost += 1;
        }
        next.push({ towns: [...p.towns, town], cost });
      }
    }
    next.sort((a, b) => a.cost - b.cost);
    beam = next.slice(0, BEAM);
    if (beam.length === 0) return [];
  }

  const plans: Ring[] = [];
  for (const p of beam) {
    const last = at(p.towns[p.towns.length - 1]);
    const home = haversineM(last, start);
    if (home > MAX_LAST_HOP_M) continue;
    const before = p.towns.length > 1 ? at(p.towns[p.towns.length - 2]) : start;
    plans.push({
      towns: p.towns,
      cost: p.cost + hopCost(Math.max(home, MIN_HOP_M)) +
        turnCost(before, last, start) +
        // The way home meets the first hop at the start: not a crossing.
        crossingCost([start, ...p.towns.map(at)], last, start, true),
    });
  }
  return plans.sort((a, b) => a.cost - b.cost);
}

/**
 * Plans for a [days]-day loop from [start], best first, the seed rotating
 * which of the best comes first (Shuffle). Only towns on the start's
 * island. Where the island is too small for that many days, plans with
 * fewer nights come back (the loop will be shorter).
 */
export function planRings(
  start: LngLat,
  days: number,
  seed: number,
  towns = TOWNS,
): Ring[] {
  const island = islandAt(start, towns);
  const pool = island ? towns.filter((t) => t.island === island) : towns;
  for (let nights = days - 1; nights >= 1; nights--) {
    const plans = search(start, nights, pool);
    if (plans.length === 0) continue;
    // The same towns the other way round is a different ride.
    const seen = new Set<string>();
    const distinct = plans.filter((p) => {
      const key = [...p.towns.map((t) => t.name)].sort().join('|');
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
    const top = Math.min(TOP_PLANS, distinct.length);
    const first = seed % top;
    const ordered = [
      ...distinct.slice(first, top),
      ...distinct.slice(0, first),
      ...distinct.slice(top),
    ];
    // Odd seeds ride it the other way round.
    return seed % 2 === 1
      ? ordered.map((p) => ({ ...p, towns: [...p.towns].reverse() }))
      : ordered;
  }
  return [];
}

/** [points] in overlapping chunks of at most [size] (GraphHopper's free
 * plan routes 5 points per request): each chunk starts where the last
 * ended. */
export function chunks(points: LngLat[], size = 5): LngLat[][] {
  const out: LngLat[][] = [];
  for (let i = 0; i < points.length - 1; i += size - 1) {
    out.push(points.slice(i, i + size));
  }
  return out;
}
