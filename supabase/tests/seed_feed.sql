-- Test data for the feed (Prompt 13): 35 posts copied from your newest real
-- post (same author, loop, stop and photo files), one hour apart, so the
-- feed has enough to scroll and page. Every 4th has no photos, which the
-- feed shows as a shared-loop card. Run in the Supabase SQL editor after
-- posting at least once. Captions start with "[test]";
-- seed_feed_cleanup.sql removes them.
do $$
declare
  v_template public.posts;
  v_post_id uuid;
  i integer;
begin
  select * into v_template
  from public.posts
  where caption is distinct from '[test]' and coalesce(caption, '') not like '[test]%'
  order by created_at desc
  limit 1;
  if not found then
    raise exception 'Post a ride from the app first; the seed copies it.';
  end if;

  for i in 1..35 loop
    v_post_id := gen_random_uuid();
    insert into public.posts (id, author_id, loop_id, caption, stop_location, created_at)
    values (
      v_post_id,
      v_template.author_id,
      v_template.loop_id,
      format('[test] Post %s: %s', i, (array[
        'Smooth roads after the bridge.',
        'Hit Shuffle three times and got this one.',
        'Sunrise at the viewpoint, worth the early start.',
        'Rough patch near the river, take it slow.',
        'Best halo-halo on the loop.'
      ])[1 + i % 5]),
      v_template.stop_location,
      v_template.created_at - make_interval(hours => i)
    );
    if i % 4 <> 0 then
      insert into public.post_photos (post_id, storage_path, position, width, height)
      select v_post_id, ph.storage_path, ph.position, ph.width, ph.height
      from public.post_photos ph
      where ph.post_id = v_template.id;
    end if;
  end loop;

  raise notice 'Added 35 test posts copied from post %', v_template.id;
end;
$$;
