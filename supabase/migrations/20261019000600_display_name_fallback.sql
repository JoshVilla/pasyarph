-- Comments, posts and the feed show profiles.display_name. Riders who
-- skipped the rider-name step (or signed up before it) had none and showed
-- as "A rider". Their full name fills in until they pick a rider name.

create function public.profiles_default_display_name()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_name text := left(trim(new.full_name), 30);
begin
  if new.display_name is null and char_length(v_name) >= 2 then
    new.display_name := v_name;
  end if;
  return new;
end;
$$;

create trigger profiles_default_display_name
  before insert or update of full_name, display_name on public.profiles
  for each row execute function public.profiles_default_display_name();

-- Existing profiles without a rider name.
update public.profiles
set display_name = left(trim(full_name), 30)
where display_name is null
  and char_length(left(trim(full_name), 30)) >= 2;
