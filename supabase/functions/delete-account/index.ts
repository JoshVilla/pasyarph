// delete-account: deletes the caller's storage files, then their user, which
// cascades to all their data. SUPABASE_URL, SUPABASE_ANON_KEY and
// SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from '@supabase/supabase-js';

import { createHandler } from './handler.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

Deno.serve(createHandler({
  async userId(req) {
    const authorization = req.headers.get('Authorization');
    if (!authorization) return null;
    const client = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data, error } = await client.auth.getUser();
    return error ? null : (data.user?.id ?? null);
  },

  async listFiles(bucket, prefix) {
    const files: string[] = [];
    const walk = async (folder: string) => {
      for (let offset = 0;; offset += 1000) {
        const { data, error } = await admin.storage
          .from(bucket)
          .list(folder, { limit: 1000, offset });
        if (error) throw error;
        for (const entry of data) {
          const path = `${folder}/${entry.name}`;
          // Folders have no id.
          if (entry.id === null) await walk(path);
          else files.push(path);
        }
        if (data.length < 1000) return;
      }
    };
    await walk(prefix);
    return files;
  },

  async removeFiles(bucket, paths) {
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw error;
  },

  async deleteUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
}));
