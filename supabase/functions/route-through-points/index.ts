// route-through-points: snaps a custom loop (Create tab) to roads with
// GraphHopper directions, S → 1 → … → n → S, a few legs at a time.
// Secrets: GRAPHHOPPER_API_KEY (shared with generate-loop).
// SUPABASE_URL and SUPABASE_ANON_KEY are provided by Supabase.

import { createClient } from '@supabase/supabase-js';

import {
  createHandler,
  GRAPHHOPPER_URL,
  RouteError,
} from './handler.ts';

// A 5-point route normally answers in under a second.
const ROUTING_TIMEOUT_MS = 15_000;

Deno.serve(createHandler({
  async consumeQuota(req) {
    const authorization = req.headers.get('Authorization');
    if (!authorization) throw new RouteError('unauthorized');
    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data, error } = await client.rpc('consume_route_quota');
    if (error) {
      if (error.code === '42501') throw new RouteError('unauthorized');
      throw new RouteError(
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
}));
