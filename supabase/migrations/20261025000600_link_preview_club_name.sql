-- Expose the loop's club name in link_preview() so shared links can show it.
create or replace function public.link_preview(p_kind text, p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_loop_id uuid;
  v_post public.posts%rowtype;
  v_loop public.loops%rowtype;
  v_status text;
  v_result jsonb;
begin
  if p_kind = 'post' then
    select * into v_post from public.posts where id = p_id;
    if not found then
      return jsonb_build_object('status', 'missing');
    end if;
    v_loop_id := v_post.loop_id;
  elsif p_kind = 'loop' then
    v_loop_id := p_id;
  else
    raise exception 'unknown link kind %', p_kind using errcode = '22023';
  end if;

  select * into v_loop from public.loops where id = v_loop_id;
  if not found then
    return jsonb_build_object('status', 'missing');
  end if;

  v_status := case
    when v_uid is not null and v_loop.owner_id = v_uid then 'ok'
    when v_loop.visibility = 'public' then 'ok'
    when v_loop.visibility = 'club'
      and v_uid is not null
      and public.is_club_member(v_loop.club_id) then 'ok'
    when v_loop.visibility = 'club' then 'club'
    else 'private'
  end;

  if v_status = 'club' then
    return jsonb_build_object(
      'status', 'club',
      'club_id', v_loop.club_id,
      'club_name', (select c.name from public.clubs c where c.id = v_loop.club_id)
    );
  elsif v_status <> 'ok' then
    return jsonb_build_object('status', v_status);
  end if;

  v_result := jsonb_build_object(
    'status', 'ok',
    'kind', p_kind,
    'id', p_id,
    'loop_id', v_loop.id,
    'name', v_loop.name,
    'distance_m', v_loop.distance_m,
    'duration_s', v_loop.duration_s,
    'main_stop', v_loop.main_stop->>'name',
    'club_name', (select c.name from public.clubs c where c.id = v_loop.club_id),
    -- About 10 m detail is plenty for a 640 px map and keeps the URL short.
    'route', extensions.st_asgeojson(
      extensions.st_simplify(v_loop.shared_route::extensions.geometry, 0.0001),
      5
    )::jsonb,
    'author', (
      select a.display_name from public.profiles a
      where a.id = coalesce(v_post.author_id, v_loop.owner_id)
    )
  );

  if p_kind = 'post' then
    v_result := v_result || jsonb_build_object(
      'caption', v_post.caption,
      'photo', (
        select ph.storage_path from public.post_photos ph
        where ph.post_id = v_post.id
        order by ph.position
        limit 1
      )
    );
  end if;
  return v_result;
end;
$$;

revoke execute on function public.link_preview(text, uuid) from public;
grant execute on function public.link_preview(text, uuid) to anon, authenticated;