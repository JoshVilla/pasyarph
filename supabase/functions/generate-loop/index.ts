// generate-loop: builds a motorcycle loop that starts and ends at the rider,
// using GraphHopper round trips, and picks its main stop from the places
// table (OpenStreetMap data, see tools/places).
// Secrets: GRAPHHOPPER_API_KEY
//   (`npx supabase secrets set GRAPHHOPPER_API_KEY=...`).
// SUPABASE_URL and SUPABASE_ANON_KEY are provided by Supabase.

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import { GRAPHHOPPER_URL, LoopError } from './graphhopper.ts';
import { createHandler } from './handler.ts';
import type { Place } from './stops.ts';

// A round trip normally answers in under 2 s.
const ROUTING_TIMEOUT_MS = 20_000;

/** A client acting as the caller, so RLS and auth.uid() apply. */
const clients = new WeakMap<Request, SupabaseClient>();
function clientFor(req: Request): SupabaseClient {
  let client = clients.get(req);
  if (!client) {
    const authorization = req.headers.get('Authorization');
    if (!authorization) throw new LoopError('unauthorized');
    client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    clients.set(req, client);
  }
  return client;
}

Deno.serve(createHandler({
  async consumeQuota(req) {
    const { data, error } = await clientFor(req).rpc('consume_generate_quota');
    if (error) {
      if (error.code === '42501') throw new LoopError('unauthorized');
      throw new LoopError(
        'routing_down',
        `quota check failed: ${error.message}`,
      );
    }
    return data === true;
  },

  callRouting(body) {
    const key = Deno.env.get('GRAPHHOPPER_API_KEY');
    if (!key) throw new Error('GRAPHHOPPER_API_KEY secret is not set');
    const url = `${GRAPHHOPPER_URL}?key=${encodeURIComponent(key)}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(ROUTING_TIMEOUT_MS),
    });
  },

  async loopForRiding(req, loopId) {
    const { data, error } = await clientFor(req).rpc('loop_for_riding', {
      p_loop_id: loopId,
    });
    if (error) throw new Error(error.message);
    return data;
  },

  async queryPlaces(req, line, radiusM) {
    const { data, error } = await clientFor(req).rpc('places_along', {
      route: line,
      radius_m: radiusM,
    });
    if (error) throw new Error(`places_along: ${error.message}`);
    return (data ?? []) as Place[];
  },
}));
