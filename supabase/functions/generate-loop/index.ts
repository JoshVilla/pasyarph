// generate-loop: builds a motorcycle loop that starts and ends at the rider,
// using GraphHopper round trips.
// Secrets: GRAPHHOPPER_API_KEY
//   (`npx supabase secrets set GRAPHHOPPER_API_KEY=...`).
// SUPABASE_URL and SUPABASE_ANON_KEY are provided by Supabase.

import { createClient } from '@supabase/supabase-js';

import { GRAPHHOPPER_URL, LoopError } from './graphhopper.ts';
import { createHandler } from './handler.ts';

// A round trip normally answers in under 2 s.
const ROUTING_TIMEOUT_MS = 20_000;

Deno.serve(createHandler({
  async consumeQuota(req) {
    const authorization = req.headers.get('Authorization');
    if (!authorization) throw new LoopError('unauthorized');
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data, error } = await supabase.rpc('consume_generate_quota');
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
}));
