-- Per-user rate limit for the generate-loop Edge Function: at most 30 calls
-- in any rolling hour. RLS is on with no policies, so the table is only
-- reachable through consume_generate_quota().

create table public.generate_calls (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  called_at timestamptz not null default now()
);

create index generate_calls_user_time_idx
  on public.generate_calls (user_id, called_at desc);

alter table public.generate_calls enable row level security;

-- Records one call for the signed-in user and returns true, or returns false
-- (recording nothing) when the user already made 30 calls in the last hour.
-- The limit is fixed here so callers can't raise it.
create function public.consume_generate_quota()
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

  -- Serialize this user's calls so two at once can't both pass at 29.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));

  delete from public.generate_calls
  where user_id = uid and called_at < now() - interval '1 day';

  select count(*) into used
  from public.generate_calls
  where user_id = uid and called_at > now() - interval '1 hour';

  if used >= 30 then
    return false;
  end if;

  insert into public.generate_calls (user_id) values (uid);
  return true;
end;
$$;

revoke all on function public.consume_generate_quota() from public, anon;
grant execute on function public.consume_generate_quota() to authenticated;
