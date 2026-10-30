-- Feed "Global" filter: public rides and loops from everywhere, not only
-- near the rider. Same as before plus the 'global' scope.
create or replace function public.feed_scope_match(
  p_scope text,
  p_target uuid,
  p_author uuid,
  p_visibility public.loop_visibility,
  p_club_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case p_scope
    when 'global' then p_visibility = 'public'
    when 'following' then exists (
      select 1 from public.follows f
      where f.follower_id = (select auth.uid()) and f.followee_id = p_author
    )
    when 'clubs' then p_visibility = 'club' and public.is_club_member(p_club_id)
    when 'club' then p_visibility = 'club' and p_club_id = p_target
    when 'rider' then p_author = p_target
    else false
  end;
$$;
