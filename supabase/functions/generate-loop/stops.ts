// Picking the loop's main stop and the fuel stations along it from
// OpenStreetMap places (see overpass.ts).

import { haversineM, type LngLat, routeLocator } from './geometry.ts';

export type PlaceType =
  | 'viewpoint'
  | 'waterfall'
  | 'attraction'
  | 'food'
  | 'fuel';

export interface Place {
  name: string | null;
  type: PlaceType;
  lat: number;
  lng: number;
}

export type StopType = Exclude<PlaceType, 'fuel'> | 'turnaround';

export interface MainStop {
  /** Null for unnamed places and for the turnaround fallback. */
  name: string | null;
  /** 'turnaround' when no place was found: the farthest point. */
  type: StopType;
  lat: number;
  lng: number;
  km_into_route: number;
}

export interface FuelStop {
  name: string | null;
  lat: number;
  lng: number;
  km_into_route: number;
}

/** Places farther than this from the route are ignored. */
export const MAX_OFF_ROUTE_M = 1_500;

/** Scenic stops should sit in this share of the loop, so the ride out and
 * the ride home are both worth it. */
export const STOP_WINDOW: [number, number] = [0.35, 0.65];

/** Most fuel stations returned. */
export const MAX_FUEL = 15;

/** Fuel stations closer than this to each other count as one. */
const FUEL_DEDUPE_M = 300;

const SCENIC_WEIGHT: Partial<Record<PlaceType, number>> = {
  waterfall: 3,
  viewpoint: 3,
  attraction: 2,
};

interface Located extends Place {
  offRouteM: number;
  alongM: number;
  share: number;
}

const km = (m: number) => Math.round(m / 100) / 10;

/** The farthest point (straight line) from the start. */
export function farthestPoint(coords: LngLat[]): MainStop {
  const { locate } = routeLocator(coords);
  let best = coords[0];
  let bestD = -1;
  for (const c of coords) {
    const d = haversineM(coords[0], c);
    if (d > bestD) {
      bestD = d;
      best = c;
    }
  }
  return {
    name: null,
    type: 'turnaround',
    lat: best[1],
    lng: best[0],
    km_into_route: km(locate(best).alongM),
  };
}

/**
 * Main stop: a waterfall, viewpoint or attraction 35–65% around the loop
 * (named, close to the road, near the middle preferred); else a food spot
 * (named and near the middle preferred); else the farthest point.
 * Fuel: every station near the route, in riding order.
 */
export function pickStops(coords: LngLat[], places: Place[]) {
  const locator = routeLocator(coords);
  const located: Located[] = places
    .map((p) => {
      const pos = locator.locate([p.lng, p.lat]);
      return { ...p, ...pos, share: pos.alongM / locator.lengthM };
    })
    .filter((p) => p.offRouteM <= MAX_OFF_ROUTE_M);

  const middle = (p: Located) => Math.abs(p.share - 0.5);
  const inWindow = (p: Located) =>
    p.share >= STOP_WINDOW[0] && p.share <= STOP_WINDOW[1];

  const scenic = located
    .filter((p) => SCENIC_WEIGHT[p.type] && inWindow(p))
    .sort((a, b) => scenicScore(b) - scenicScore(a));
  const food = located
    .filter((p) => p.type === 'food')
    .sort((a, b) => foodScore(b) - foodScore(a));

  function scenicScore(p: Located) {
    return SCENIC_WEIGHT[p.type]! + (p.name ? 2 : 0) -
      p.offRouteM / 1000 - middle(p) * 4;
  }
  function foodScore(p: Located) {
    return (p.name ? 2 : 0) - p.offRouteM / 1000 - middle(p) * 4;
  }

  const chosen = scenic[0] ?? food[0];
  const mainStop: MainStop = chosen
    ? {
      name: chosen.name,
      type: chosen.type as StopType,
      lat: chosen.lat,
      lng: chosen.lng,
      km_into_route: km(chosen.alongM),
    }
    : farthestPoint(coords);

  const fuel: FuelStop[] = [];
  for (
    const f of located
      .filter((p) => p.type === 'fuel')
      .sort((a, b) => a.alongM - b.alongM)
  ) {
    const dupe = fuel.some((g) =>
      haversineM([g.lng, g.lat], [f.lng, f.lat]) < FUEL_DEDUPE_M
    );
    if (dupe) continue;
    fuel.push({
      name: f.name,
      lat: f.lat,
      lng: f.lng,
      km_into_route: km(f.alongM),
    });
    if (fuel.length === MAX_FUEL) break;
  }

  return { mainStop, fuel };
}
