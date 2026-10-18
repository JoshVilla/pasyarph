// generate-loop request handling, with its outside world injected so it can
// be tested without network calls. index.ts wires the real dependencies.

import { backtrackingRatio, curvinessScore, type LngLat } from './geometry.ts';
import {
  LoopError,
  parseRoute,
  type Route,
  routeBody,
  routingError,
} from './graphhopper.ts';
import {
  correctedDistance,
  type Duration,
  isCloseEnough,
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
}

export interface Deps {
  /** Records a call; false when the user is over the hourly limit. Throws
   * LoopError('unauthorized') when the caller isn't signed in. */
  consumeQuota(req: Request): Promise<boolean>;
  /** POSTs a body to GraphHopper /route. */
  callRouting(body: unknown): Promise<Response>;
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
      (Number.isInteger(b.seed) && b.seed >= 0 && b.seed <= MAX_SEED));
  if (!ok) throw new LoopError('bad_request');
  return {
    lat,
    lng,
    duration: b.duration,
    avoidHighways: b.avoidHighways ?? false,
    avoidUnpaved: b.avoidUnpaved ?? false,
    seed: b.seed ?? Math.floor(Math.random() * MAX_SEED),
  };
}

async function route(
  deps: Deps,
  start: LngLat,
  distanceM: number,
  seed: number,
): Promise<Route> {
  let res: Response;
  try {
    res = await deps.callRouting(routeBody(start, distanceM, seed));
  } catch (e) {
    const timedOut = e instanceof Error && e.name === 'TimeoutError';
    throw new LoopError(timedOut ? 'routing_busy' : 'routing_down', String(e));
  }
  const json = await res.json().catch(() => null);
  if (!res.ok) throw routingError(res.status, json);
  return parseRoute(json);
}

/**
 * Up to [MAX_CALLS] round trips: a loop that is too long or short is retried
 * with a rescaled distance (same seed); one that uses roads the rider wants
 * to avoid, or has no road at a random point, moves to the next seed. Returns
 * the best loop seen.
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
  return best;
}

export async function generateLoop(deps: Deps, httpReq: Request) {
  if (httpReq.method !== 'POST') throw new LoopError('bad_request');
  const req = parseRequest(await httpReq.json().catch(() => null));
  if (!(await deps.consumeQuota(httpReq))) {
    throw new LoopError('limit_reached');
  }

  const prefs: Preferences = {
    targetM: TARGET_LENGTH_M[req.duration],
    avoidHighways: req.avoidHighways,
    avoidUnpaved: req.avoidUnpaved,
  };
  const { route: r, seed } = await bestLoop(deps, req, prefs);
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
