-- Prompt 16: rate limit for route-through-points (the Create tab snaps
-- custom loops to roads). Editing a loop routes after every change, so it
-- gets its own, larger budget instead of sharing Generate's 30 per hour.
-- Both are counted in generate_calls, told apart by kind.

alter table public.generate_calls
  add column kind text not null default 'generate'
  check (kind in ('generate', 'route'));

drop index public.generate_calls_user_time_idx;
create index generate_calls_user_kind_time_idx
  on public.generate_calls (user_id, kind, called_at desc);

-- Records one call of p_kind for the signed-in user and returns true, or
-- returns false (recording nothing) when the user already made p_limit
-- calls of that kind in the last hour.
create function public.consume_quota(p_kind text, p_limit integer)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  used integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  -- Serialize this user's calls so two at once can't both pass the limit.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));

  delete from public.generate_calls
  where user_id = uid and called_at < now() - interval '1 day';

  select count(*) into used
  from public.generate_calls
  where user_id = uid and kind = p_kind
    and called_at > now() - interval '1 hour';

  if used >= p_limit then
    return false;
  end if;

  insert into public.generate_calls (user_id, kind) values (uid, p_kind);
  return true;
end;
$$;

-- Not callable directly: the limits are fixed in the wrappers below so
-- callers can't raise them.
revoke all on function public.consume_quota(text, integer) from public, anon, authenticated;

create or replace function public.consume_generate_quota()
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select public.consume_quota('generate', 30);
$$;

-- One call per routing change in the Create tab (debounced), so about 10
-- loops' worth of editing an hour.
create function public.consume_route_quota()
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select public.consume_quota('route', 200);
$$;

revoke all on function public.consume_route_quota() from public, anon;
grant execute on function public.consume_route_quota() to authenticated;
