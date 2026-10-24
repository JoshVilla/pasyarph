// delete-account request handling, with storage and auth injected so it
// can be tested without network calls. index.ts wires the real ones.
//
// Every table cascades from auth.users → profiles (loops, posts, photos,
// rides, likes, comments, clubs, follows, saved loops), so deleting the user
// deletes their data. Storage files don't cascade, so they go first:
// avatars/<uid>/… (profile and club photos), post-photos/<uid>/… and
// covers/<uid>/… (profile covers).

export const BUCKETS = ['avatars', 'post-photos', 'covers'] as const;

/** Storage's remove() takes at most this many paths per call. */
export const REMOVE_BATCH = 1000;

export interface Deps {
  /** The signed-in caller's id, or null when the JWT is missing/invalid. */
  userId(req: Request): Promise<string | null>;
  /** Every file path under [prefix] in [bucket], recursively. */
  listFiles(bucket: string, prefix: string): Promise<string[]>;
  removeFiles(bucket: string, paths: string[]): Promise<void>;
  deleteUser(userId: string): Promise<void>;
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
    if (req.method !== 'POST') {
      return json({ error: 'bad_request', message: 'Use POST.' }, 405);
    }

    const uid = await deps.userId(req);
    if (!uid) {
      return json(
        {
          error: 'unauthorized',
          message: 'Log in again to delete your account.',
        },
        401,
      );
    }

    try {
      for (const bucket of BUCKETS) {
        const paths = await deps.listFiles(bucket, uid);
        // Never touch another user's folder, whatever list() returned.
        const mine = paths.filter((p) => p.startsWith(`${uid}/`));
        for (let i = 0; i < mine.length; i += REMOVE_BATCH) {
          await deps.removeFiles(bucket, mine.slice(i, i + REMOVE_BATCH));
        }
      }
      await deps.deleteUser(uid);
    } catch (e) {
      console.error(`delete-account ${uid}: ${e}`);
      return json(
        {
          error: 'delete_failed',
          message:
            "Couldn't delete your account. Check your connection and try again.",
        },
        500,
      );
    }
    return json({ deleted: true });
  };
}
