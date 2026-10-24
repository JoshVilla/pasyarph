// What a share link points at, from Supabase's link_preview() (see
// supabase/migrations/20261024000100_share_links.sql). Called signed out,
// so only public loops and posts come back with details.

export interface Env {
  SUPABASE_URL: string;
  /** The same anon / publishable key the app uses. */
  SUPABASE_ANON_KEY: string;
  /**
   * Optional, needs a MapTiler plan with the Static Maps API. Without it
   * the map is a plain route line and loop links have no preview image.
   */
  MAPTILER_KEY?: string;
}

export type LinkKind = "loop" | "post";

export interface Preview {
  status: "ok" | "club" | "private" | "missing";
  kind?: LinkKind;
  id?: string;
  loop_id?: string;
  name?: string;
  distance_m?: number;
  duration_s?: number;
  main_stop?: string | null;
  /** The trimmed route (never the owner's start), simplified. */
  route?: { type: "LineString"; coordinates: [number, number][] } | null;
  author?: string | null;
  caption?: string | null;
  /** Storage path in the public post-photos bucket. */
  photo?: string | null;
  club_name?: string | null;
}

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The preview, or null when Supabase couldn't be reached. */
export async function fetchPreview(
  env: Env,
  kind: LinkKind,
  id: string,
): Promise<Preview | null> {
  if (!uuid.test(id)) return { status: "missing" };
  try {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/link_preview`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_kind: kind, p_id: id }),
    });
    if (!res.ok) {
      console.log(`link_preview ${kind} ${id}: HTTP ${res.status}`);
      return null;
    }
    return (await res.json()) as Preview;
  } catch (e) {
    console.log(`link_preview ${kind} ${id}: ${e}`);
    return null;
  }
}

/** Public URL of a post photo. */
export function photoUrl(env: Env, path: string): string {
  return `${env.SUPABASE_URL}/storage/v1/object/public/post-photos/${path
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

/** "82 km", "8.4 km" (as the app shows it). */
export function formatDistance(meters: number): string {
  const km = meters / 1000;
  return km < 10 ? `${km.toFixed(1)} km` : `${Math.round(km)} km`;
}

/** "3 h 50", "4 h", "45 min" (as the app shows it). */
export function formatRideTime(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h} h` : `${h} h ${String(m).padStart(2, "0")}`;
}
