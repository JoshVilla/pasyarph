// GraphHopper round trips: request body, response parsing, errors.
//
// The free plan only offers the car/bike/foot profiles and no custom models
// ("flexible mode"), so highways and unpaved roads can't be avoided while
// routing. Instead each route comes back with road_class and surface details
// and the handler prefers loops that don't use them (see scoring.ts).

import { haversineM, type LngLat, spurMask } from './geometry.ts';

export const GRAPHHOPPER_URL = 'https://graphhopper.com/api/1/route';

/** A plain A → B car route (ride-this-loop approach and connector). */
export function pointsBody(from: LngLat, to: LngLat) {
  return {
    points: [from, to],
    profile: 'car',
    points_encoded: false,
    instructions: false,
    details: ['road_class', 'surface'],
  };
}

export function routeBody(start: LngLat, distanceM: number, seed: number) {
  return {
    points: [start],
    profile: 'car',
    algorithm: 'round_trip',
    'round_trip.distance': Math.round(distanceM),
    'round_trip.seed': seed,
    points_encoded: false,
    instructions: true,
    locale: 'en',
    details: ['road_class', 'surface'],
  };
}

export interface Step {
  instruction: string;
  name: string;
  distance_m: number;
  duration_s: number;
  /** GraphHopper sign: -2 left, 2 right, 0 continue, 4 finish, 6 roundabout,
   * ... Unknown values may appear. */
  sign: number;
  /** Index range into the route coordinates. */
  way_points: [number, number];
}

export interface Route {
  coordinates: LngLat[];
  distance_m: number;
  duration_s: number;
  steps: Step[];
  /** Meters on expressways (road_class motorway). */
  motorway_m: number;
  /** Meters on roads tagged unpaved, or tracks. Most roads have no surface
   * tag, so this is a lower bound. */
  unpaved_m: number;
}

const UNPAVED = new Set([
  'unpaved', 'gravel', 'dirt', 'ground', 'grass', 'sand', 'compacted',
  'fine_gravel', 'mud',
]);

/** Meters of [coords] covered by detail intervals whose value matches,
 * skipping segments that end in a [removed] vertex. */
function metersWhere(
  coords: LngLat[],
  removed: Uint8Array,
  intervals: unknown,
  matches: (value: string) => boolean,
): number {
  if (!Array.isArray(intervals)) return 0;
  let total = 0;
  for (const [from, to, value] of intervals as [number, number, unknown][]) {
    if (!matches(String(value).toLowerCase())) continue;
    for (let i = from + 1; i <= to && i < coords.length; i++) {
      if (!removed[i]) total += haversineM(coords[i - 1], coords[i]);
    }
  }
  return total;
}

/** GraphHopper U-turn signs (left, right, unknown). */
const U_TURNS = new Set([-8, 8, -98]);

/**
 * The first path of a GraphHopper response, with dead-end spurs cut out
 * (see [spurMask]): riders shouldn't ride into a side road and back just
 * because a random via point landed there. Distance, time, steps and road
 * meters describe the trimmed loop.
 */
export function parseRoute(json: unknown): Route {
  // deno-lint-ignore no-explicit-any
  const path = (json as any)?.paths?.[0];
  const coords = path?.points?.coordinates;
  if (!Array.isArray(coords) || coords.length < 2) {
    throw new LoopError('no_route');
  }
  const raw = coords.map((c: number[]) => [c[0], c[1]] as LngLat);
  const removed = spurMask(raw);

  // Old index -> new index; a removed vertex maps to the spur's mouth.
  const newIndex: number[] = [];
  let next = -1;
  let cutM = 0;
  for (let i = 0; i < raw.length; i++) {
    if (removed[i]) cutM += haversineM(raw[i - 1], raw[i]);
    else next++;
    newIndex.push(Math.max(0, next));
  }
  const coordinates = raw.filter((_, i) => !removed[i]);

  const steps: Step[] = [];
  // deno-lint-ignore no-explicit-any
  for (const s of (path.instructions ?? []) as any[]) {
    const from = Number(s.interval?.[0] ?? 0);
    const to = Number(s.interval?.[1] ?? 0);
    const sign = Number(s.sign ?? 0);
    // Steps that only ride a spur: into it, the U-turn.
    const inSpur = from < to && newIndex[from] === newIndex[to];
    if (inSpur || (U_TURNS.has(sign) && removed[from])) continue;
    steps.push({
      instruction: String(s.text ?? ''),
      name: String(s.street_name ?? ''),
      distance_m: Math.round(Number(s.distance ?? 0)),
      duration_s: Math.round(Number(s.time ?? 0) / 1000),
      sign,
      way_points: [newIndex[from] ?? 0, newIndex[to] ?? 0],
    });
  }

  const details = path.details ?? {};
  const rawDistance = Number(path.distance ?? 0);
  const distance = Math.max(0, rawDistance - cutM);
  const share = rawDistance > 0 ? distance / rawDistance : 1;
  return {
    coordinates,
    distance_m: Math.round(distance),
    duration_s: Math.round((Number(path.time ?? 0) / 1000) * share),
    steps,
    motorway_m: Math.round(
      metersWhere(raw, removed, details.road_class, (v) => v === 'motorway'),
    ),
    unpaved_m: Math.round(
      metersWhere(raw, removed, details.surface, (v) => UNPAVED.has(v)) +
        metersWhere(raw, removed, details.road_class, (v) => v === 'track'),
    ),
  };
}

export type LoopErrorCode =
  | 'bad_request'
  | 'unauthorized'
  | 'limit_reached'
  | 'no_route'
  | 'too_long'
  | 'loop_not_found'
  | 'routing_busy'
  | 'routing_down';

const MESSAGES: Record<LoopErrorCode, string> = {
  bad_request:
    "Something's off with that request. Update the app and try again.",
  unauthorized: 'Log in again to generate loops.',
  limit_reached:
    "You've generated 30 loops in the last hour. Take a break and try again soon.",
  no_route: "Couldn't find a loop from here. Try Shuffle or a shorter ride.",
  too_long:
    "Couldn't find a loop that short from here. Try Shuffle or a longer ride.",
  loop_not_found: "This loop isn't available anymore.",
  routing_busy: 'The route service is busy. Try again in a minute.',
  routing_down: "The route service isn't responding. Try again soon.",
};

const STATUS: Record<LoopErrorCode, number> = {
  bad_request: 400,
  unauthorized: 401,
  limit_reached: 429,
  no_route: 422,
  too_long: 422,
  loop_not_found: 404,
  routing_busy: 503,
  routing_down: 502,
};

export class LoopError extends Error {
  constructor(readonly code: LoopErrorCode, detail?: string) {
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

/** Maps a failed GraphHopper response to a [LoopError]. */
export function routingError(status: number, json: unknown): LoopError {
  // deno-lint-ignore no-explicit-any
  const message = String((json as any)?.message ?? status);
  if (status === 429 || status === 504) {
    return new LoopError('routing_busy', message);
  }
  // A random round-trip point with no road nearby, or no connection back.
  if (status === 400 && /valid point|connection between/i.test(message)) {
    return new LoopError('no_route', message);
  }
  return new LoopError('routing_down', message);
}
