// route-through-points request handling, with its outside world injected so
// it can be tested without network calls. index.ts wires the real
// dependencies.
//
// The Create tab sends only the legs it hasn't routed yet, grouped in runs
// of consecutive points (S → 1 → 2 … → S). Each run is routed through
// GraphHopper in chunks of at most [MAX_POINTS_PER_REQUEST] points (the free
// plan's limit) and split back into one leg per pair of points, so the app
// can cache legs and only re-route what changed.

import type { LngLat } from '../generate-loop/geometry.ts';
import { GRAPHHOPPER_URL } from '../generate-loop/graphhopper.ts';

export { GRAPHHOPPER_URL };

/** GraphHopper free plan: at most 5 points per route request. */
export const MAX_POINTS_PER_REQUEST = 5;

/** Start + 15 points + back to start. */
export const MAX_LEGS = 16;

export interface Leg {
  coordinates: LngLat[];
  distance_m: number;
  duration_s: number;
}

export interface Deps {
  /** Records a call; false when the user is over the hourly limit. Throws
   * RouteError('unauthorized') when the caller isn't signed in. */
  consumeQuota(req: Request): Promise<boolean>;
  /** POSTs a body to GraphHopper /route. */
  callRouting(body: unknown): Promise<Response>;
}

export type RouteErrorCode =
  | 'bad_request'
  | 'unauthorized'
  | 'limit_reached'
  | 'off_road'
  | 'no_route'
  | 'routing_busy'
  | 'routing_down';

const MESSAGES: Record<RouteErrorCode, string> = {
  bad_request:
    "Something's off with that request. Update the app and try again.",
  unauthorized: 'Log in again to create loops.',
  limit_reached:
    "You've moved a lot of points in the last hour. Take a break and try again soon.",
  off_road: 'One of your points is too far from a road. Move it closer.',
  no_route: "Couldn't find roads between your points. Try moving them.",
  routing_busy: 'The route service is busy. Try again in a minute.',
  routing_down: "The route service isn't responding. Try again soon.",
};

const STATUS: Record<RouteErrorCode, number> = {
  bad_request: 400,
  unauthorized: 401,
  limit_reached: 429,
  off_road: 422,
  no_route: 422,
  routing_busy: 503,
  routing_down: 502,
};

export class RouteError extends Error {
  constructor(readonly code: RouteErrorCode, detail?: string) {
    super(detail ?? MESSAGES[code]);
  }

  get status() {
    return STATUS[this.code];
  }

  /** Body sent to the app. [message] is safe to show riders. */
  toJson() {
    return { error: { code: this.code, message: MESSAGES[this.code] } };
  }
}

const isLngLat = (p: unknown): p is LngLat =>
  Array.isArray(p) && p.length === 2 &&
  Number.isFinite(p[0]) && Math.abs(p[0]) <= 180 &&
  Number.isFinite(p[1]) && Math.abs(p[1]) <= 90;

/** `{runs: [[[lng, lat], ...], ...]}`: each run has at least 2 points. */
export function parseRuns(json: unknown): LngLat[][] {
  // deno-lint-ignore no-explicit-any
  const runs = (json as any)?.runs;
  if (!Array.isArray(runs) || runs.length === 0) {
    throw new RouteError('bad_request');
  }
  let legs = 0;
  for (const run of runs) {
    if (!Array.isArray(run) || run.length < 2 || !run.every(isLngLat)) {
      throw new RouteError('bad_request');
    }
    legs += run.length - 1;
  }
  if (legs > MAX_LEGS) throw new RouteError('bad_request');
  return runs.map((run: number[][]) => run.map((p) => [p[0], p[1]] as LngLat));
}

/** [points] in overlapping chunks of at most [size]: each chunk starts at
 * the last point of the one before. */
export function chunk(points: LngLat[], size = MAX_POINTS_PER_REQUEST) {
  const out: LngLat[][] = [];
  for (let i = 0; i < points.length - 1; i += size - 1) {
    out.push(points.slice(i, i + size));
  }
  return out;
}

export function pointsBody(points: LngLat[]) {
  return {
    points,
    profile: 'car',
    points_encoded: false,
    // Instructions mark where each via point is reached (sign 5), which is
    // how the path is split into legs.
    instructions: true,
    locale: 'en',
  };
}

/** GraphHopper sign for "via point reached". */
const VIA_REACHED = 5;

/**
 * Splits the first path of a GraphHopper response through [pointCount]
 * points into pointCount - 1 legs, with each leg's share of the distance
 * and time (summed from the instructions that start in it).
 */
export function splitLegs(json: unknown, pointCount: number): Leg[] {
  // deno-lint-ignore no-explicit-any
  const path = (json as any)?.paths?.[0];
  const raw = path?.points?.coordinates;
  if (!Array.isArray(raw) || raw.length < 2) throw new RouteError('no_route');
  const coords = raw.map((c: number[]) => [c[0], c[1]] as LngLat);
  // deno-lint-ignore no-explicit-any
  const instructions = (path.instructions ?? []) as any[];

  const cuts = [0];
  for (const s of instructions) {
    if (Number(s.sign) === VIA_REACHED) cuts.push(Number(s.interval?.[0] ?? 0));
  }
  cuts.push(coords.length - 1);
  if (cuts.length !== pointCount) {
    throw new RouteError(
      'no_route',
      `expected ${pointCount - 2} via points, got ${cuts.length - 2}`,
    );
  }

  const legs: Leg[] = [];
  for (let i = 0; i < cuts.length - 1; i++) {
    const from = cuts[i];
    const to = cuts[i + 1];
    let distance = 0;
    let time = 0;
    for (const s of instructions) {
      const at = Number(s.interval?.[0] ?? 0);
      const last = i === cuts.length - 2;
      if (at >= from && (at < to || (last && at <= to))) {
        distance += Number(s.distance ?? 0);
        time += Number(s.time ?? 0);
      }
    }
    legs.push({
      coordinates: coords.slice(from, to + 1),
      distance_m: Math.round(distance),
      duration_s: Math.round(time / 1000),
    });
  }
  return legs;
}

/** Maps a failed GraphHopper response to a [RouteError]. */
export function routingError(status: number, json: unknown): RouteError {
  // deno-lint-ignore no-explicit-any
  const message = String((json as any)?.message ?? status);
  if (status === 429 || status === 504) {
    return new RouteError('routing_busy', message);
  }
  if (status === 400 && /cannot find point/i.test(message)) {
    return new RouteError('off_road', message);
  }
  if (status === 400 && /connection between/i.test(message)) {
    return new RouteError('no_route', message);
  }
  return new RouteError('routing_down', message);
}

async function routeChunk(deps: Deps, points: LngLat[]): Promise<Leg[]> {
  let res: Response;
  try {
    res = await deps.callRouting(pointsBody(points));
  } catch (e) {
    const timedOut = e instanceof Error && e.name === 'TimeoutError';
    throw new RouteError(timedOut ? 'routing_busy' : 'routing_down', String(e));
  }
  const json = await res.json().catch(() => null);
  if (!res.ok) throw routingError(res.status, json);
  return splitLegs(json, points.length);
}

/** One list of legs per run. Chunks are routed one after another: the
 * free plan also limits requests per minute. */
export async function routeRuns(deps: Deps, httpReq: Request) {
  if (httpReq.method !== 'POST') throw new RouteError('bad_request');
  const runs = parseRuns(await httpReq.json().catch(() => null));
  if (!(await deps.consumeQuota(httpReq))) {
    throw new RouteError('limit_reached');
  }
  const out: Leg[][] = [];
  for (const run of runs) {
    const legs: Leg[] = [];
    for (const points of chunk(run)) legs.push(...await routeChunk(deps, points));
    out.push(legs);
  }
  return { runs: out };
}

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    try {
      return json(await routeRuns(deps, req), 200);
    } catch (e) {
      if (e instanceof RouteError) {
        if (e.status >= 500) {
          console.error(`route-through-points ${e.code}:`, e.message);
        }
        return json(e.toJson(), e.status);
      }
      console.error('route-through-points unexpected:', e);
      return json(new RouteError('routing_down').toJson(), 502);
    }
  };
}
