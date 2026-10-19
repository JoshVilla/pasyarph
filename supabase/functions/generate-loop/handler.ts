// generate-loop request handling, with its outside world injected so it can
// be tested without network calls. index.ts wires the real dependencies.

import {
  backtrackingRatio,
  curvinessScore,
  haversineM,
  lengthM,
  routeLocator,
  type LngLat,
  simplify,
} from './geometry.ts';
import {
  LoopError,
  parseRoute,
  pointsBody,
  type Route,
  routeBody,
  routingError,
  viaBody,
} from './graphhopper.ts';
import {
  chunks,
  MAX_DAYS,
  MIN_DAYS,
  planRings,
  targetMeters,
  townPoint,
} from './multiday.ts';
import { MAX_OFF_ROUTE_M, type Place, pickStops } from './stops.ts';
import {
  assembleRide,
  GAP_M,
  joinLoop,
  loopTimeS,
  ON_LOOP_M,
  parseSharedLoop,
} from './ride.ts';
import {
  correctedDistance,
  type Duration,
  isCloseEnough,
  isTooLong,
  meetsPreferences,
  penalty,
  type Preferences,
  TARGET_LENGTH_M,
  warningsFor,
} from './plan.ts';

export interface LoopRequest {
  lat: number;
  lng: number;
  duration: Duration;
  avoidHighways: boolean;
  avoidUnpaved: boolean;
  seed: number;
  /** Multi-day loops only: 2-7. */
  days?: number;
}

export interface Deps {
  /** Records a call; false when the user is over the hourly limit. Throws
   * LoopError('unauthorized') when the caller isn't signed in. */
  consumeQuota(req: Request): Promise<boolean>;
  /** POSTs a body to GraphHopper /route. */
  callRouting(body: unknown): Promise<Response>;
  /** Places within [radiusM] of a GeoJSON LineString (the places_along
   * RPC). May throw. */
  queryPlaces(
    req: Request,
    line: { type: 'LineString'; coordinates: LngLat[] },
    radiusM: number,
  ): Promise<Place[]>;
  /** The loop_for_riding row for [loopId] as the caller sees it: null when
   * it doesn't exist or isn't visible to them. May throw. */
  loopForRiding(req: Request, loopId: string): Promise<unknown>;
}

/** Simplifying the route this much keeps the RPC payload small and moves
 * the line by at most 150 m, so the search band is widened by as much;
 * pickStops re-checks exact distances. */
const PLACES_SIMPLIFY_M = 150;

/** OSM places near the route. Places are a bonus: any failure means no
 * places, and the farthest point becomes the main stop. */
async function placesNear(
  deps: Deps,
  req: Request,
  coords: LngLat[],
): Promise<Place[]> {
  try {
    const line = {
      type: 'LineString' as const,
      coordinates: simplify(coords, PLACES_SIMPLIFY_M),
    };
    return await deps.queryPlaces(
      req,
      line,
      MAX_OFF_ROUTE_M + PLACES_SIMPLIFY_M,
    );
  } catch (e) {
    console.warn('generate-loop places unavailable:', String(e));
    return [];
  }
}

/** Most GraphHopper calls per Generate (each costs 2 credits). */
export const MAX_CALLS = 3;

const MAX_SEED = 2 ** 31 - 1;

export function parseRequest(json: unknown): LoopRequest {
  // deno-lint-ignore no-explicit-any
  const b = json as any;
  const lat = Number(b?.lat);
  const lng = Number(b?.lng);
  const ok = b !== null &&
    typeof b === 'object' &&
    Number.isFinite(lat) && Math.abs(lat) <= 90 &&
    Number.isFinite(lng) && Math.abs(lng) <= 180 &&
    Object.hasOwn(TARGET_LENGTH_M, b.duration) &&
    (b.avoidHighways === undefined || typeof b.avoidHighways === 'boolean') &&
    (b.avoidUnpaved === undefined || typeof b.avoidUnpaved === 'boolean') &&
    (b.seed === undefined ||
      (Number.isInteger(b.seed) && b.seed >= 0 && b.seed <= MAX_SEED)) &&
    (b.days === undefined ||
      (Number.isInteger(b.days) && b.days >= MIN_DAYS && b.days <= MAX_DAYS));
  if (!ok) throw new LoopError('bad_request');
  return {
    lat,
    lng,
    duration: b.duration,
    avoidHighways: b.avoidHighways ?? false,
    avoidUnpaved: b.avoidUnpaved ?? false,
    seed: b.seed ?? Math.floor(Math.random() * MAX_SEED),
    ...(b.duration === 'multi' ? { days: b.days ?? 3 } : {}),
  };
}

function route(
  deps: Deps,
  start: LngLat,
  distanceM: number,
  seed: number,
): Promise<Route> {
  return routeWith(deps, routeBody(start, distanceM, seed));
}

async function routeWith(
  deps: Deps,
  body: unknown,
  opts?: { cutSpurs?: boolean },
): Promise<Route> {
  let res: Response;
  try {
    res = await deps.callRouting(body);
  } catch (e) {
    const timedOut = e instanceof Error && e.name === 'TimeoutError';
    throw new LoopError(timedOut ? 'routing_busy' : 'routing_down', String(e));
  }
  const json = await res.json().catch(() => null);
  if (!res.ok) throw routingError(res.status, json);
  return parseRoute(json, opts);
}

/**
 * Up to [MAX_CALLS] round trips: a loop that is too long or short is retried
 * with a rescaled distance (same seed); one that uses roads the rider wants
 * to avoid, or has no road at a random point, moves to the next seed. Returns
 * the best loop seen, unless even that is far too long.
 */
async function bestLoop(deps: Deps, req: LoopRequest, prefs: Preferences) {
  const start: LngLat = [req.lng, req.lat];
  let seed = req.seed;
  let distance = prefs.targetM;
  let best: { route: Route; seed: number } | undefined;
  let lastError: LoopError | undefined;

  for (let call = 0; call < MAX_CALLS; call++) {
    let r: Route;
    try {
      r = await route(deps, start, distance, seed);
    } catch (e) {
      if (!(e instanceof LoopError)) throw e;
      lastError = e;
      if (e.code !== 'no_route') break; // busy/down: don't spend more calls
      seed = (seed + 1) % MAX_SEED;
      continue;
    }
    if (!best || penalty(r, prefs) < penalty(best.route, prefs)) {
      best = { route: r, seed };
    }
    if (meetsPreferences(r, prefs)) break;

    if (!isCloseEnough(r.distance_m, prefs.targetM)) {
      distance = correctedDistance(distance, r.distance_m, prefs.targetM);
    } else {
      seed = (seed + 1) % MAX_SEED;
    }
  }
  if (!best) throw lastError ?? new LoopError('no_route');
  if (isTooLong(best.route.distance_m, prefs.targetM)) {
    throw new LoopError(
      'too_long',
      `best loop  m for a  m target`,
    );
  }
  return best;
}

export interface RideRequest {
  loopId: string;
  lat: number;
  lng: number;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseRideRequest(json: unknown): RideRequest {
  // deno-lint-ignore no-explicit-any
  const b = json as any;
  const lat = Number(b?.lat);
  const lng = Number(b?.lng);
  const ok = typeof b?.loop_id === 'string' && UUID.test(b.loop_id) &&
    Number.isFinite(lat) && Math.abs(lat) <= 90 &&
    Number.isFinite(lng) && Math.abs(lng) <= 180;
  if (!ok) throw new LoopError('bad_request');
  return { loopId: b.loop_id, lat, lng };
}

/** Ride legs longer than this get a warning with the distance. */
const LONG_APPROACH_M = 30_000;

/**
 * "Ride this loop": someone else's loop from where the rider is (see
 * ride.ts). Same response as a generated loop, plus approach_m. At most two
 * GraphHopper calls: the approach, and the connector over the trimmed gap.
 */
export async function rideLoop(deps: Deps, httpReq: Request, req: RideRequest) {
  if (!(await deps.consumeQuota(httpReq))) {
    throw new LoopError('limit_reached');
  }
  let row: unknown;
  try {
    row = await deps.loopForRiding(httpReq, req.loopId);
  } catch (e) {
    throw new LoopError('routing_down', `loop_for_riding: ${String(e)}`);
  }
  const loop = parseSharedLoop(row);
  if (!loop) throw new LoopError('loop_not_found');

  const rider: LngLat = [req.lng, req.lat];
  const join = joinLoop(loop.route, rider);
  const approach = join.offM <= ON_LOOP_M
    ? null
    : await routeWith(deps, pointsBody(rider, join.point));
  const end = loop.route[loop.route.length - 1];
  const start = loop.route[0];
  const connector = haversineM(end, start) <= GAP_M
    ? null
    : await routeWith(deps, pointsBody(end, start));

  const coordinates = assembleRide(
    join,
    approach?.coordinates ?? [],
    connector?.coordinates ?? [],
  );
  const loopM = lengthM(loop.route);
  const approachM = approach?.distance_m ?? 0;
  const distance = Math.round(
    loopM + 2 * approachM + (connector?.distance_m ?? 0),
  );
  const duration = loopTimeS(loop, loopM) +
    2 * (approach?.duration_s ?? 0) +
    (connector?.duration_s ?? 0);

  const places = await placesNear(deps, httpReq, coordinates);
  const picked = pickStops(coordinates, places);
  const mainStop = loop.mainStop
    ? {
      ...loop.mainStop,
      km_into_route: Math.round(
        routeLocator(coordinates).locate([loop.mainStop.lng, loop.mainStop.lat])
          .alongM / 100,
      ) / 10,
    }
    : picked.mainStop;

  return {
    route: { type: 'LineString', coordinates },
    distance_m: distance,
    duration_s: duration,
    steps: [],
    seed: 0,
    backtracking_ratio: round(backtrackingRatio(coordinates), 3),
    curviness_score: round(curvinessScore(coordinates), 1),
    motorway_m: (approach?.motorway_m ?? 0) * 2 + (connector?.motorway_m ?? 0),
    unpaved_m: (approach?.unpaved_m ?? 0) * 2 + (connector?.unpaved_m ?? 0),
    main_stop: mainStop,
    fuel_stops: picked.fuel,
    warnings: approachM > LONG_APPROACH_M
      ? [`${loop.name} starts about ${Math.round(approachM / 1000)} km from you.`]
      : [],
    approach_m: approachM,
    loop_name: loop.name,
  };
}

/** Rings tried per multi-day Generate: each costs 1-2 GraphHopper calls. */
const MULTI_ATTEMPTS = 2;

/** Multi-day routes are long: simplified this much (shape kept) so the
 * response stays small. */
const MULTI_SIMPLIFY_M = 8;

/** Shorter than this share of the days asked for: tell the rider. */
const MULTI_SHORT_SHARE = 0.7;

/**
 * A multi-day loop: from the rider through a ring of overnight towns and
 * back (see multiday.ts), routed in chunks of at most 5 points. When a ring
 * can't be routed (a town off the road network), the next one is tried.
 */
async function multiDayLoop(deps: Deps, httpReq: Request, req: LoopRequest) {
  const start: LngLat = [req.lng, req.lat];
  const days = req.days ?? 3;
  const rings = planRings(start, days, req.seed);
  if (rings.length === 0) {
    throw new LoopError('no_route', 'no overnight towns near the start');
  }

  let lastError: LoopError | undefined;
  for (const ring of rings.slice(0, MULTI_ATTEMPTS)) {
    const points = [start, ...ring.towns.map(townPoint), start];
    const parts: Route[] = [];
    try {
      for (const chunk of chunks(points)) {
        parts.push(await routeWith(deps, viaBody(chunk), { cutSpurs: false }));
      }
    } catch (e) {
      if (!(e instanceof LoopError) || e.code !== 'no_route') throw e;
      lastError = e;
      continue;
    }

    const joined: LngLat[] = [];
    for (const part of parts) {
      joined.push(...(joined.length ? part.coordinates.slice(1) : part.coordinates));
    }
    const coordinates = simplify(joined, MULTI_SIMPLIFY_M);
    const sum = (f: (r: Route) => number) => parts.reduce((s, r) => s + f(r), 0);
    const total = {
      distance_m: sum((r) => r.distance_m),
      duration_s: sum((r) => r.duration_s),
      motorway_m: sum((r) => r.motorway_m),
      unpaved_m: sum((r) => r.unpaved_m),
    };
    const prefs: Preferences = {
      targetM: targetMeters(days),
      avoidHighways: req.avoidHighways,
      avoidUnpaved: req.avoidUnpaved,
    };
    const { locate } = routeLocator(coordinates);
    const { mainStop, fuel } = pickStops(
      coordinates,
      await placesNear(deps, httpReq, coordinates),
    );
    const warnings = warningsFor(total, prefs);
    if (total.distance_m < prefs.targetM * MULTI_SHORT_SHARE) {
      warnings.push(
        `This loop is about ${Math.round(total.distance_m / 1000)} km: ` +
          `there aren't enough roads around here for ${days} days.`,
      );
    }
    return {
      route: { type: 'LineString', coordinates },
      ...total,
      steps: [],
      seed: req.seed,
      backtracking_ratio: round(backtrackingRatio(coordinates), 3),
      curviness_score: round(curvinessScore(coordinates), 1),
      main_stop: mainStop,
      fuel_stops: fuel,
      warnings,
      days,
      overnights: ring.towns.map((t) => ({
        name: t.name,
        lat: t.lat,
        lng: t.lng,
        km_into_route: Math.round(locate(townPoint(t)).alongM / 1000),
      })),
    };
  }
  throw lastError ?? new LoopError('no_route');
}

export async function generateLoop(deps: Deps, httpReq: Request) {
  if (httpReq.method !== 'POST') throw new LoopError('bad_request');
  const body = await httpReq.json().catch(() => null);
  if (body?.loop_id !== undefined) {
    return rideLoop(deps, httpReq, parseRideRequest(body));
  }
  const req = parseRequest(body);
  if (!(await deps.consumeQuota(httpReq))) {
    throw new LoopError('limit_reached');
  }
  if (req.duration === 'multi') return multiDayLoop(deps, httpReq, req);

  const prefs: Preferences = {
    targetM: TARGET_LENGTH_M[req.duration],
    avoidHighways: req.avoidHighways,
    avoidUnpaved: req.avoidUnpaved,
  };
  const { route: r, seed } = await bestLoop(deps, req, prefs);
  const { mainStop, fuel } = pickStops(
    r.coordinates,
    await placesNear(deps, httpReq, r.coordinates),
  );
  return {
    route: { type: 'LineString', coordinates: r.coordinates },
    distance_m: r.distance_m,
    duration_s: r.duration_s,
    steps: r.steps,
    seed,
    backtracking_ratio: round(backtrackingRatio(r.coordinates), 3),
    curviness_score: round(curvinessScore(r.coordinates), 1),
    motorway_m: r.motorway_m,
    unpaved_m: r.unpaved_m,
    main_stop: mainStop,
    fuel_stops: fuel,
    warnings: warningsFor(r, prefs),
  };
}

const round = (x: number, places: number) =>
  Math.round(x * 10 ** places) / 10 ** places;

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    try {
      return json(await generateLoop(deps, req), 200);
    } catch (e) {
      if (e instanceof LoopError) {
        if (e.status >= 500) {
          console.error(`generate-loop ${e.code}:`, e.message);
        }
        return json(e.toJson(), e.status);
      }
      console.error('generate-loop unexpected:', e);
      return json(new LoopError('routing_down').toJson(), 502);
    }
  };
}
