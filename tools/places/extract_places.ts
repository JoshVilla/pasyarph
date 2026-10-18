// Builds tools/places/out/places.csv (viewpoints, waterfalls, attractions,
// food, fuel) from an OpenStreetMap extract, for the Supabase `places`
// table. See tools/places/README.md.
//
//   npx deno run --allow-read --allow-write --allow-env --allow-sys \
//     tools/places/extract_places.ts path/to/philippines-latest.osm.pbf
//
// Two passes over the file: the first keeps tagged nodes (complete places)
// and tagged ways (outlines, e.g. a fuel station building) with their node
// ids; the second looks up only those nodes' coordinates so each way is
// placed at the average of its corners. Relations are skipped (very few
// places are mapped only as relations).
// Data © OpenStreetMap contributors, ODbL.

import { createOSMStream } from 'npm:osm-pbf-parser-node@1.1.4';

import {
  PLACE_TAG_KEYS,
  placeName,
  placeType,
} from '../../supabase/functions/generate-loop/osm_places.ts';

const file = Deno.args[0];
if (!file) {
  console.error('Usage: extract_places.ts <file.osm.pbf>');
  Deno.exit(2);
}

interface Row {
  osmId: string;
  name: string | null;
  type: string;
  lat: number;
  lng: number;
}

// deno-lint-ignore no-explicit-any
type Item = any;
const opts = {
  withTags: { node: PLACE_TAG_KEYS, way: PLACE_TAG_KEYS, relation: false },
  withInfo: false,
};

const rows: Row[] = [];
const ways: { id: number; refs: number[]; name: string | null; type: string }[] = [];
const wanted = new Set<number>();

console.log('Pass 1: tagged nodes and ways…');
let seen = 0;
const t0 = Date.now();
for await (const item of createOSMStream(file, opts) as AsyncIterable<Item>) {
  if (++seen % 10_000_000 === 0) {
    console.log(`  ${seen / 1_000_000}M entities, ${rows.length} nodes, ${ways.length} ways`);
  }
  if (!item.tags || (item.type !== 'node' && item.type !== 'way')) continue;
  const type = placeType(item.tags);
  if (!type) continue;
  const name = placeName(item.tags);
  if (item.type === 'node') {
    rows.push({ osmId: `n${item.id}`, name, type, lat: item.lat, lng: item.lon });
  } else {
    // An open outline repeats nothing; a closed one repeats its first node.
    const refs: number[] = item.refs.length > 1 && item.refs[0] === item.refs.at(-1)
      ? item.refs.slice(0, -1)
      : item.refs;
    ways.push({ id: item.id, refs, name, type });
    for (const r of refs) wanted.add(r);
  }
}
console.log(`  done in ${((Date.now() - t0) / 1000).toFixed(0)}s: ${rows.length} nodes, ${ways.length} ways`);

console.log(`Pass 2: coordinates for ${wanted.size} way nodes…`);
const coords = new Map<number, [number, number]>();
const t1 = Date.now();
for await (
  const item of createOSMStream(file, { withTags: false, withInfo: false }) as AsyncIterable<Item>
) {
  if (item.type === 'node') {
    if (wanted.has(item.id)) coords.set(item.id, [item.lat, item.lon]);
  } else if (item.type === 'way') {
    break; // PBF files list all nodes before ways
  }
}
console.log(`  done in ${((Date.now() - t1) / 1000).toFixed(0)}s`);

let missing = 0;
for (const w of ways) {
  const pts = w.refs.map((r) => coords.get(r)).filter((p) => p !== undefined);
  if (!pts.length) {
    missing++;
    continue;
  }
  const lat = pts.reduce((s, p) => s + p[0], 0) / pts.length;
  const lng = pts.reduce((s, p) => s + p[1], 0) / pts.length;
  rows.push({ osmId: `w${w.id}`, name: w.name, type: w.type, lat, lng });
}

const csv = (v: string | number | null) =>
  v == null ? '' : /[",\n\r]/.test(String(v)) ? `"${String(v).replaceAll('"', '""')}"` : String(v);
const lines = rows
  .sort((a, b) => a.osmId.localeCompare(b.osmId))
  .map((p) => [p.osmId, p.name, p.type, p.lat.toFixed(6), p.lng.toFixed(6)].map(csv).join(','));

await Deno.mkdir(new URL('./out/', import.meta.url), { recursive: true });
const out = new URL('./out/places.csv', import.meta.url);
await Deno.writeTextFile(out, ['osm_id,name,type,lat,lng', ...lines].join('\n') + '\n');

const counts: Record<string, number> = {};
for (const p of rows) counts[p.type] = (counts[p.type] ?? 0) + 1;
console.log(`\nWrote ${rows.length} places to ${decodeURIComponent(out.pathname)}`);
console.log(counts);
if (missing) console.log(`${missing} ways skipped (nodes outside the extract)`);
