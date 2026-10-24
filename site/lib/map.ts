// The loop's static map for the web page and link previews (og:image):
// MapTiler's static API with the app's map style and route colors, or a
// plain SVG route line when there's no key or MapTiler fails.

const accent = "#C2410C";
const mapGround = "#F7F7F7";
const style = "streets-v2-pastel";

export const mapWidth = 600;
export const mapHeight = 315;

type Coord = [number, number]; // [lng, lat], as in GeoJSON

/** Google encoded polyline (lat, lng order) for MapTiler's `enc:` paths. */
export function encodePolyline(coords: Coord[], precision = 5): string {
  const factor = 10 ** precision;
  let out = "";
  let lastLat = 0;
  let lastLng = 0;
  const encode = (value: number) => {
    let v = value < 0 ? ~(value << 1) : value << 1;
    let chunk = "";
    while (v >= 0x20) {
      chunk += String.fromCharCode((0x20 | (v & 0x1f)) + 63);
      v >>>= 5;
    }
    return chunk + String.fromCharCode(v + 63);
  };
  for (const [lng, lat] of coords) {
    const la = Math.round(lat * factor);
    const ln = Math.round(lng * factor);
    out += encode(la - lastLat) + encode(ln - lastLng);
    lastLat = la;
    lastLng = ln;
  }
  return out;
}

/** Every [step]th point plus the last, so the URL stays well under 8 KB. */
export function thin(coords: Coord[], max = 400): Coord[] {
  if (coords.length <= max) return coords;
  const step = Math.ceil(coords.length / max);
  const out = coords.filter((_, i) => i % step === 0);
  if (out[out.length - 1] !== coords[coords.length - 1]) {
    out.push(coords[coords.length - 1]);
  }
  return out;
}

/** MapTiler static map: white casing under the orange route, as in the app. */
export function staticMapUrl(coords: Coord[], key: string): string {
  const enc = `enc:${encodePolyline(thin(coords))}`;
  const params = new URLSearchParams();
  params.append("path", `stroke:#FFFFFF|width:8|fill:none|${enc}`);
  params.append("path", `stroke:${accent}|width:4|fill:none|${enc}`);
  params.set("padding", "0.15");
  params.set("attribution", "bottomright");
  params.set("key", key);
  return `https://api.maptiler.com/maps/${style}/static/auto/${mapWidth}x${mapHeight}@2x.png?${params}`;
}

/** The route alone on the map's land color. */
export function routeSvg(coords: Coord[]): string {
  const pad = 24;
  const w = mapWidth;
  const h = mapHeight;
  let body = "";
  if (coords.length >= 2) {
    // Longitude shrinks with latitude; scale it so the shape isn't stretched.
    const midLat =
      (Math.min(...coords.map((c) => c[1])) +
        Math.max(...coords.map((c) => c[1]))) /
      2;
    const kx = Math.cos((midLat * Math.PI) / 180);
    const xs = coords.map((c) => c[0] * kx);
    const ys = coords.map((c) => -c[1]);
    const [minX, maxX] = [Math.min(...xs), Math.max(...xs)];
    const [minY, maxY] = [Math.min(...ys), Math.max(...ys)];
    const scale = Math.min(
      (w - 2 * pad) / (maxX - minX || 1),
      (h - 2 * pad) / (maxY - minY || 1),
    );
    const ox = (w - (maxX - minX) * scale) / 2;
    const oy = (h - (maxY - minY) * scale) / 2;
    const points = xs
      .map(
        (x, i) =>
          `${(ox + (x - minX) * scale).toFixed(1)},${(oy + (ys[i] - minY) * scale).toFixed(1)}`,
      )
      .join(" ");
    const line = (color: string, width: number) =>
      `<polyline points="${points}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linejoin="round" stroke-linecap="round"/>`;
    body = line("#FFFFFF", 8) + line(accent, 4);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"><rect width="100%" height="100%" fill="${mapGround}"/>${body}</svg>`;
}
