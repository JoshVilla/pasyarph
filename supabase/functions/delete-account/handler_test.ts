import { assertEquals } from '@std/assert';

import { createHandler, type Deps, REMOVE_BATCH } from './handler.ts';

const UID = '00000000-0000-0000-0000-0000000000a1';

function fakeDeps(
  files: Record<string, string[]>,
  overrides: Partial<Deps> = {},
) {
  const removed: Record<string, string[][]> = {};
  const deleted: string[] = [];
  const deps: Deps = {
    userId: () => Promise.resolve(UID),
    listFiles: (bucket) => Promise.resolve(files[bucket] ?? []),
    removeFiles: (bucket, paths) => {
      (removed[bucket] ??= []).push(paths);
      return Promise.resolve();
    },
    deleteUser: (id) => {
      deleted.push(id);
      return Promise.resolve();
    },
    ...overrides,
  };
  return { deps, removed, deleted };
}

const post = () => new Request('http://x/delete-account', { method: 'POST' });

Deno.test('deletes the files in both buckets, then the user', async () => {
  const { deps, removed, deleted } = fakeDeps({
    'avatars': [`${UID}/avatar.jpg`, `${UID}/clubs/c1.jpg`],
    'post-photos': [`${UID}/p1/0.jpg`],
  });
  const res = await createHandler(deps)(post());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { deleted: true });
  assertEquals(removed, {
    'avatars': [[`${UID}/avatar.jpg`, `${UID}/clubs/c1.jpg`]],
    'post-photos': [[`${UID}/p1/0.jpg`]],
  });
  assertEquals(deleted, [UID]);
});

Deno.test('removes files in batches', async () => {
  const many = Array.from(
    { length: REMOVE_BATCH + 5 },
    (_, i) => `${UID}/p/${i}.jpg`,
  );
  const { deps, removed } = fakeDeps({ 'post-photos': many });
  await createHandler(deps)(post());
  assertEquals(removed['post-photos'].map((b) => b.length), [REMOVE_BATCH, 5]);
});

Deno.test('never removes files of another user', async () => {
  const { deps, removed } = fakeDeps({
    'avatars': [`${UID}/avatar.jpg`, 'someone-else/avatar.jpg'],
  });
  await createHandler(deps)(post());
  assertEquals(removed['avatars'], [[`${UID}/avatar.jpg`]]);
});

Deno.test('a user with no files is still deleted', async () => {
  const { deps, removed, deleted } = fakeDeps({});
  const res = await createHandler(deps)(post());
  assertEquals(res.status, 200);
  assertEquals(removed, {});
  assertEquals(deleted, [UID]);
});

Deno.test('signed out: 401, nothing deleted', async () => {
  const { deps, deleted } = fakeDeps({}, {
    userId: () => Promise.resolve(null),
  });
  const res = await createHandler(deps)(post());
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error, 'unauthorized');
  assertEquals(deleted, []);
});

Deno.test('a storage failure keeps the account', async () => {
  const { deps, deleted } = fakeDeps(
    { 'avatars': [`${UID}/a.jpg`] },
    { removeFiles: () => Promise.reject(new Error('storage down')) },
  );
  const res = await createHandler(deps)(post());
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, 'delete_failed');
  assertEquals(deleted, []);
});

Deno.test('only POST', async () => {
  const { deps } = fakeDeps({});
  const res = await createHandler(deps)(
    new Request('http://x', { method: 'GET' }),
  );
  assertEquals(res.status, 405);
});
