// Which OpenStreetMap features count as Pasyar places, and what they are
// called. Used by tools/places/extract_places.ts to build the places table;
// generate-loop itself reads that table (places_along in migrations).

import type { PlaceType } from './stops.ts';

/** Tag keys the classifier and naming read; everything else can be dropped
 * while parsing. */
export const PLACE_TAG_KEYS = [
  'tourism',
  'waterway',
  'natural',
  'amenity',
  'name',
  'name:en',
  'brand',
];

export function placeType(tags: Record<string, string>): PlaceType | null {
  if (tags.waterway === 'waterfall' || tags.natural === 'waterfall') {
    return 'waterfall';
  }
  if (tags.tourism === 'viewpoint') return 'viewpoint';
  if (tags.tourism === 'attraction') return 'attraction';
  if (tags.amenity === 'fuel') return 'fuel';
  if (['restaurant', 'cafe', 'fast_food'].includes(tags.amenity)) {
    return 'food';
  }
  return null;
}

/** The name riders know it by; fuel stations often only have a brand. */
export function placeName(tags: Record<string, string>): string | null {
  const name = tags.name ?? tags['name:en'] ?? tags.brand;
  return name?.trim() ? name.trim() : null;
}
