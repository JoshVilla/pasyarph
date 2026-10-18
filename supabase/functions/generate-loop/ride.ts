// "Ride this loop" (Prompt 15): someone else's loop, ridden from where you
// are. Only its trimmed route (shared_route) is used, never the owner's
// start: approach to the nearest point of the loop, round the loop, bridge
// the trimmed gap at the owner's end, back to the join, then home the way
// you came.

import { haversineM, type LngLat, routeLocator } from './geometry.ts';

export interface SharedLoop {
  name: string;
  /** shared_route: the loop with its first and last 800 m cut off. */
  route: LngLat[];
  distanceM: number;
  durationS: number;
  curviness: number | null;
  mainStop: { name: string | null; type: string; lat: number; lng: number } | null;
}

/** A loop_for_riding row, or null when it's missing or has no route. */
export function parseSharedLoop(json: unknown): SharedLoop | null {
  // deno-lint-ignore no-explicit-any
  const j = json as any;
  const coords = j?.shared_route?.coordinates;
  if (!Array.isArray(coords) || coords.length < 2) return null;
  const stop = j.main_stop;
  return {
    name: String(j.name ?? 'Loop'),
    route: coords.map((c: number[]) => [c[0], c[1]] as LngLat),
    distanceM: Number(j.distance_m ?? 0),
    durationS: Number(j.duration_s ?? 0),
    curviness: j.curviness_score == null ? null : Number(j.curviness_score),
    mainStop: stop && Number.isFinite(Number(stop.lat))
      ? {
        name: stop.name ?? null,
        type: String(stop.type ?? 'turnaround'),
        lat: Number(stop.lat),
        lng: Number(stop.lng),
      }
      : null,
  };
}

export interface Join {
  /** Where the rider meets the loop. */
  point: LngLat;
  /** The loop from the join to its end. */
  after: LngLat[];
  /** The loop from its start to the join. */
  before: LngLat[];
  /** Straight-line distance from the rider to the join. */
  offM: number;
}

/** Splits [route] at its point nearest to [rider]. */
export function joinLoop(route: LngLat[], rider: LngLat): Join {
  const { locate } = routeLocator(route);
  const { alongM, offRouteM } = locate(rider);

  let walked = 0;
  for (let i = 1; i < route.length; i++) {
    const seg = haversineM(route[i - 1], route[i]);
    if (walked + seg >= alongM || i === route.length - 1) {
      const t = seg === 0 ? 0 : Math.min(1, Math.max(0, (alongM - walked) / seg));
      const a = route[i - 1];
      const b = route[i];
      const point: LngLat = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
      return {
        point,
        after: [point, ...route.slice(i)],
        before: [...route.slice(0, i), point],
        offM: offRouteM,
      };
    }
    walked += seg;
  }
  return { point: route[0], after: route, before: [route[0]], offM: offRouteM };
}

/** Consecutive points closer than this are merged when joining pieces. */
const SAME_POINT_M = 1;

/** Joins line pieces end to start, dropping repeated points. */
export function joinLines(...pieces: LngLat[][]): LngLat[] {
  const out: LngLat[] = [];
  for (const piece of pieces) {
    for (const p of piece) {
      const last = out[out.length - 1];
      if (!last || haversineM(last, p) > SAME_POINT_M) out.push(p);
    }
  }
  return out;
}

/**
 * The whole ride: [approach] (rider → join), the loop from the join round
 * to the join again with [connector] bridging the loop's end back to its
 * start, then [approach] reversed back to the rider.
 */
export function assembleRide(
  join: Join,
  approach: LngLat[],
  connector: LngLat[],
): LngLat[] {
  return joinLines(
    approach,
    join.after,
    connector,
    join.before,
    [...approach].reverse(),
  );
}

/** Riding time for [meters] of the loop at the loop's own average speed. */
export function loopTimeS(loop: SharedLoop, meters: number): number {
  if (loop.distanceM <= 0 || loop.durationS <= 0) return 0;
  return Math.round(meters * (loop.durationS / loop.distanceM));
}

/** Closer than this, the rider is already on the loop: no approach leg. */
export const ON_LOOP_M = 150;

/** Loop ends closer than this need no connector. */
export const GAP_M = 200;
