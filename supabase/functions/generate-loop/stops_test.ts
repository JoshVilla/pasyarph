import { assert, assertAlmostEquals, assertEquals } from '@std/assert';

import {
  destination,
  haversineM,
  type LngLat,
  routeLocator,
  simplify,
} from './geometry.ts';
import { placeName, placeType } from './osm_places.ts';
import { farthestPoint, MAX_FUEL, type Place, pickStops } from './stops.ts';

const start: LngLat = [121.457, 16.672];

/** 12 km rectangle: 2 km north, 4 km east, 2 km south, 4 km west. One
 * vertex every 100 m. */
function rectangle(): LngLat[] {
  const out: LngLat[] = [start];
  let at = start;
  for (const [bearing, meters] of [[0, 2000], [90, 4000], [180, 2000], [270, 4000]]) {
    for (let d = 100; d <= meters; d += 100) {
      at = destination(at, bearing, 100);
      out.push(at);
    }
  }
  return out;
}

const loop = rectangle();
// Points on the loop by distance ridden.
const at = (m: number): LngLat => {
  const legs: [number, number][] = [[0, 2000], [90, 4000], [180, 2000], [270, 4000]];
  let p = start;
  let left = m;
  for (const [bearing, len] of legs) {
    const step = Math.min(left, len);
    p = destination(p, bearing, step);
    left -= step;
    if (left <= 0) break;
  }
  return p;
};
const place = (
  type: Place['type'],
  alongM: number,
  name: string | null = null,
  offM = 100,
): Place => {
  const [lng, lat] = destination(at(alongM), 45, offM);
  return { type, name, lat, lng };
};

// --- geometry -------------------------------------------------------------------

Deno.test('route locator: distance off the route and along it', () => {
  const locator = routeLocator(loop);
  assertAlmostEquals(locator.lengthM, 12_000, 5);
  const pos = locator.locate(destination(at(3_000), 0, 250)); // north of the top edge
  assertAlmostEquals(pos.offRouteM, 250, 2);
  assertAlmostEquals(pos.alongM, 3_000, 5);
});

Deno.test('simplify keeps corners and drops straight runs', () => {
  const simple = simplify(loop, 20);
  assertEquals(simple.length, 5); // start + 3 corners + end
  assert(haversineM(simple[2], at(6_000)) < 1);
});

// --- picking --------------------------------------------------------------------

Deno.test('scenic stop in the middle of the loop wins', () => {
  const { mainStop } = pickStops(loop, [
    place('viewpoint', 1_000, 'Too early'),
    place('food', 6_000, 'Carinderia'),
    place('waterfall', 6_200, 'Talon'),
  ]);
  assertEquals(mainStop.name, 'Talon');
  assertEquals(mainStop.type, 'waterfall');
  assertAlmostEquals(mainStop.km_into_route, 6.2, 0.15);
});

Deno.test('scenic stops outside 35–65% are skipped for food', () => {
  const { mainStop } = pickStops(loop, [
    place('viewpoint', 1_000, 'Too early'),
    place('viewpoint', 11_000, 'Too late'),
    place('food', 9_000, 'Kape'),
  ]);
  assertEquals(mainStop.type, 'food');
  assertEquals(mainStop.name, 'Kape');
});

Deno.test('named and nearer the middle beats unnamed', () => {
  const { mainStop } = pickStops(loop, [
    place('viewpoint', 6_000, null),
    place('viewpoint', 7_000, 'Overlook'),
  ]);
  assertEquals(mainStop.name, 'Overlook');
});

Deno.test('places more than 1.5 km off the route are ignored', () => {
  const { mainStop } = pickStops(loop, [place('waterfall', 6_000, 'Far', 3_000)]);
  assertEquals(mainStop.type, 'turnaround');
});

Deno.test('no places: the farthest point, unnamed', () => {
  const { mainStop, fuel } = pickStops(loop, []);
  assertEquals(mainStop, farthestPoint(loop));
  assertEquals(mainStop.type, 'turnaround');
  assertEquals(mainStop.name, null);
  assertAlmostEquals(mainStop.km_into_route, 6, 0.15); // the far corner
  assertEquals(fuel, []);
});

Deno.test('fuel: in riding order, near-duplicates merged, capped', () => {
  const { fuel } = pickStops(loop, [
    place('fuel', 8_000, 'Petron'),
    place('fuel', 2_000, 'Shell'),
    place('fuel', 2_100, 'Shell (other pump)'),
  ]);
  assertEquals(fuel.map((f) => f.name), ['Shell', 'Petron']);

  const many = Array.from({ length: 30 }, (_, i) => place('fuel', i * 400));
  assertEquals(pickStops(loop, many).fuel.length, MAX_FUEL);
});

// --- OSM tags ---------------------------------------------------------------------

Deno.test('OSM tags: which features are places, and their names', () => {
  assertEquals(placeType({ tourism: 'viewpoint' }), 'viewpoint');
  assertEquals(placeType({ natural: 'waterfall' }), 'waterfall');
  assertEquals(placeType({ waterway: 'waterfall' }), 'waterfall');
  assertEquals(placeType({ tourism: 'attraction' }), 'attraction');
  assertEquals(placeType({ amenity: 'fast_food' }), 'food');
  assertEquals(placeType({ amenity: 'fuel' }), 'fuel');
  assertEquals(placeType({ shop: 'bakery' }), null);
  assertEquals(placeType({ tourism: 'hotel' }), null);

  assertEquals(placeName({ name: ' Talon ', brand: 'x' }), 'Talon');
  assertEquals(placeName({ brand: 'Petron' }), 'Petron');
  assertEquals(placeName({ name: '  ' }), null);
  assertEquals(placeName({}), null);
});
