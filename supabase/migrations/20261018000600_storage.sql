-- Public buckets: files are readable by anyone with the URL (avatars in the
-- feed, post photos). There is deliberately no broad select policy, so the
-- API can't list other users' files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp']),
  ('post-photos', 'post-photos', true, 10 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Users manage only files under their own folder: <bucket>/<user_id>/...
-- Select on own files is needed for upserts (replacing an avatar).
create policy "avatars + post-photos: users read their own folder"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('avatars', 'post-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "avatars + post-photos: users upload to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'post-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "avatars + post-photos: users replace their own files"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'post-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('avatars', 'post-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "avatars + post-photos: users delete their own files"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('avatars', 'post-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
