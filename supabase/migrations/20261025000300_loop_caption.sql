-- Add an optional caption/description to custom (and generated) loops.
alter table public.loops
  add column if not exists caption text
  check (caption is null or char_length(caption) <= 500);

-- Column-level grants: caption must be readable, insertable, and updatable.
grant select (caption) on public.loops to authenticated;
grant insert (caption) on public.loops to authenticated;
grant update (caption) on public.loops to authenticated;
