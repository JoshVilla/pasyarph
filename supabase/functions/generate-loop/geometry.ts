// Route geometry helpers. Coordinates are GeoJSON order: [lng, lat].

export type LngLat = [number, number];

const EARTH_RADIUS_M = 6_371_000;
const toRad = (deg: number) => (deg * Math.PI) / 180;
const toDeg = (rad: number) => (rad * 180) / Math.PI;

/** Great-circle distance in meters. */
export function haversineM(a: LngLat, b: LngLat): number {
  const dLat = toRad(b[1] - a[1]);
  const dLng = toRad(b[0] - a[0]);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a[1])) * Math.cos(toRad(b[1])) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function lengthM(coords: LngLat[]): number {
  let total = 0;
  for (let i = 1; i < coords.length; i++) {
    total += haversineM(coords[i - 1], coords[i]);
  }
  return total;
}

/** Initial bearing from a to b, degrees clockwise from north, 0–360. */
export function bearingDeg(a: LngLat, b: LngLat): number {
  const φ1 = toRad(a[1]);
  const φ2 = toRad(b[1]);
  const dλ = toRad(b[0] - a[0]);
  const y = Math.sin(dλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) -
    Math.sin(φ1) * Math.cos(φ2) * Math.cos(dλ);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

/** Point [distanceM] from [origin] along [bearing] (degrees). */
export function destination(
  origin: LngLat,
  bearing: number,
  distanceM: number,
): LngLat {
  const δ = distanceM / EARTH_RADIUS_M;
  const θ = toRad(bearing);
  const φ1 = toRad(origin[1]);
  const λ1 = toRad(origin[0]);
  const φ2 = Math.asin(
    Math.sin(φ1) * Math.cos(δ) + Math.cos(φ1) * Math.sin(δ) * Math.cos(θ),
  );
  const λ2 = λ1 +
    Math.atan2(
      Math.sin(θ) * Math.sin(δ) * Math.cos(φ1),
      Math.cos(δ) - Math.sin(φ1) * Math.sin(φ2),
    );
  return [((toDeg(λ2) + 540) % 360) - 180, toDeg(φ2)];
}

/** Local flat projection in meters around [origin]; fine for one loop. */
function projector(origin: LngLat) {
  const kx = (Math.PI / 180) * EARTH_RADIUS_M * Math.cos(toRad(origin[1]));
  const ky = (Math.PI / 180) * EARTH_RADIUS_M;
  return (p: LngLat): [number, number] => [
    (p[0] - origin[0]) * kx,
    (p[1] - origin[1]) * ky,
  ];
}

/** Points every [stepM] meters along the line, in local meters, with the
 * distance along the route for each. */
function resample(coords: LngLat[], stepM: number) {
  const project = projector(coords[0]);
  const pts = coords.map(project);
  const xs: number[] = [];
  const ys: number[] = [];
  const along: number[] = [];
  let carried = 0; // distance since the last emitted point
  let walked = 0;
  xs.push(pts[0][0]);
  ys.push(pts[0][1]);
  along.push(0);
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1];
    const [x1, y1] = pts[i];
    const seg = Math.hypot(x1 - x0, y1 - y0);
    let t = stepM - carried;
    while (t <= seg) {
      xs.push(x0 + ((x1 - x0) * t) / seg);
      ys.push(y0 + ((y1 - y0) * t) / seg);
      along.push(walked + t);
      t += stepM;
    }
    carried = seg - (t - stepM);
    walked += seg;
  }
  return { xs, ys, along };
}

/**
 * Share of the route (0–1) that runs within [toleranceM] of another part of
 * the same route, i.e. riding the same road twice. Parts closer than
 * [minGapM] along the route are neighbors, not overlaps.
 */
export function backtrackingRatio(
  coords: LngLat[],
  { toleranceM = 30, stepM = 20, minGapM = 300 } = {},
): number {
  if (coords.length < 2 || lengthM(coords) < stepM * 2) return 0;
  const { xs, ys, along } = resample(coords, stepM);
  const n = xs.length;

  // Grid of points with cells as wide as the tolerance, so any match is in
  // the same or a neighboring cell.
  const cell = toleranceM;
  const grid = new Map<string, number[]>();
  const key = (cx: number, cy: number) => `${cx},${cy}`;
  for (let i = 0; i < n; i++) {
    const k = key(Math.floor(xs[i] / cell), Math.floor(ys[i] / cell));
    const bucket = grid.get(k);
    if (bucket) bucket.push(i);
    else grid.set(k, [i]);
  }

  const tol2 = toleranceM * toleranceM;
  let overlapped = 0;
  for (let i = 0; i < n; i++) {
    const cx = Math.floor(xs[i] / cell);
    const cy = Math.floor(ys[i] / cell);
    let hit = false;
    for (let dx = -1; dx <= 1 && !hit; dx++) {
      for (let dy = -1; dy <= 1 && !hit; dy++) {
        for (const j of grid.get(key(cx + dx, cy + dy)) ?? []) {
          if (Math.abs(along[i] - along[j]) < minGapM) continue;
          const ddx = xs[i] - xs[j];
          const ddy = ys[i] - ys[j];
          if (ddx * ddx + ddy * ddy <= tol2) {
            hit = true;
            break;
          }
        }
      }
    }
    if (hit) overlapped++;
  }
  return overlapped / n;
}

/**
 * Douglas–Peucker simplification: keeps the shape within [toleranceM].
 * Used to send a short polyline to Overpass instead of thousands of points.
 */
export function simplify(coords: LngLat[], toleranceM: number): LngLat[] {
  if (coords.length < 3) return coords.slice();
  const project = projector(coords[0]);
  const pts = coords.map(project);
  const keep = new Uint8Array(coords.length);
  keep[0] = keep[coords.length - 1] = 1;

  const stack: [number, number][] = [[0, coords.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop()!;
    let worst = -1;
    let worstD = toleranceM;
    for (let i = a + 1; i < b; i++) {
      const d = segmentDistance(pts[i], pts[a], pts[b]).distance;
      if (d > worstD) {
        worstD = d;
        worst = i;
      }
    }
    if (worst >= 0) {
      keep[worst] = 1;
      stack.push([a, worst], [worst, b]);
    }
  }
  return coords.filter((_, i) => keep[i]);
}

type XY = [number, number];

/** Distance from p to segment ab, and how far along ab (0–1) the nearest
 * point is. */
function segmentDistance(p: XY, a: XY, b: XY) {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0
    ? 0
    : Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / len2));
  const x = a[0] + t * dx;
  const y = a[1] + t * dy;
  return { distance: Math.hypot(p[0] - x, p[1] - y), t };
}

export interface RoutePosition {
  /** Straight-line distance from the point to the route. */
  offRouteM: number;
  /** Distance along the route to the nearest spot. */
  alongM: number;
}

/** Builds a lookup that places any point on [coords]: how far it is from
 * the route, and how far along the route its nearest spot is. */
export function routeLocator(coords: LngLat[]) {
  const project = projector(coords[0]);
  const pts = coords.map(project);
  const along = [0];
  for (let i = 1; i < pts.length; i++) {
    along.push(
      along[i - 1] +
        Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]),
    );
  }
  return {
    lengthM: along[along.length - 1],
    locate(point: LngLat): RoutePosition {
      const p = project(point);
      let best = { offRouteM: Infinity, alongM: 0 };
      for (let i = 1; i < pts.length; i++) {
        const { distance, t } = segmentDistance(p, pts[i - 1], pts[i]);
        if (distance < best.offRouteM) {
          best = {
            offRouteM: distance,
            alongM: along[i - 1] + t * (along[i] - along[i - 1]),
          };
        }
      }
      return best;
    },
  };
}

/**
 * Sum of heading changes (degrees) per km. Straight roads score near 0;
 * mountain switchbacks score in the hundreds. Segments shorter than
 * [minSegmentM] are merged so tiny GPS-style kinks don't count.
 */
export function curvinessScore(
  coords: LngLat[],
  { minSegmentM = 10 } = {},
): number {
  const km = lengthM(coords) / 1000;
  if (km === 0) return 0;

  const headings: number[] = [];
  let from = coords[0];
  for (let i = 1; i < coords.length; i++) {
    if (haversineM(from, coords[i]) < minSegmentM) continue;
    headings.push(bearingDeg(from, coords[i]));
    from = coords[i];
  }

  let turned = 0;
  for (let i = 1; i < headings.length; i++) {
    const d = Math.abs(headings[i] - headings[i - 1]) % 360;
    turned += d > 180 ? 360 - d : d;
  }
  return turned / km;
}
