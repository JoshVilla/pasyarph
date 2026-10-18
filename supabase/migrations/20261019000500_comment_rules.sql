-- Prompt 14: comment rules, enforced in Postgres so no client can skip them.
--   comment_blocked    the text has a word from blocked_words
--   comment_duplicate  the same text again: on the same post ever, or on
--                      any post within 10 minutes (copy-paste spam)

-- Words and phrases not allowed in comments, English and Filipino. Edit in
-- the Table Editor; the app never reads it. Matched as whole words after
-- lowercasing and undoing common letter swaps (see normalize_comment).
create table public.blocked_words (
  word text primary key check (word = lower(trim(word)) and word <> ''),
  lang text not null default 'en' check (lang in ('en', 'fil')),
  created_at timestamptz not null default now()
);

alter table public.blocked_words enable row level security;
-- No policies: only the dashboard (service role) reads or edits it.

insert into public.blocked_words (word, lang) values
  ('fuck', 'en'), ('fucking', 'en'), ('fucker', 'en'), ('motherfucker', 'en'),
  ('shit', 'en'), ('bullshit', 'en'), ('bitch', 'en'), ('asshole', 'en'),
  ('bastard', 'en'), ('cunt', 'en'), ('dick', 'en'), ('pussy', 'en'),
  ('slut', 'en'), ('whore', 'en'), ('retard', 'en'),
  ('putangina', 'fil'), ('putang ina', 'fil'), ('tangina', 'fil'),
  ('tang ina', 'fil'), ('puta', 'fil'), ('gago', 'fil'), ('gaga', 'fil'),
  ('ulol', 'fil'), ('tarantado', 'fil'), ('tarantada', 'fil'),
  ('leche', 'fil'), ('lintik', 'fil'), ('pakyu', 'fil'), ('kupal', 'fil'),
  ('hinayupak', 'fil'), ('punyeta', 'fil'), ('pokpok', 'fil'),
  ('burat', 'fil'), ('titi', 'fil'), ('pekpek', 'fil'), ('kantot', 'fil')
on conflict do nothing;

-- Lowercase, common swaps undone (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a,
-- $→s), letters repeated 3+ times squeezed to one ("gaaaago" → "gago"),
-- and anything else that isn't a letter turned into a space.
create function public.normalize_comment(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(regexp_replace(
    regexp_replace(
      translate(lower(coalesce(p_text, '')), '013457@$', 'oieastas'),
      '([a-z])\1{2,}', '\1', 'g'
    ),
    '[^a-z]+', ' ', 'g'
  ));
$$;

-- True when the text has a blocked word or phrase as whole words.
create function public.has_blocked_word(p_text text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.blocked_words w
    where ' ' || public.normalize_comment(p_text) || ' '
      like '% ' || w.word || ' %'
  );
$$;

revoke execute on function public.has_blocked_word(text) from public, anon;

create function public.check_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_norm text := public.normalize_comment(new.body);
begin
  if public.has_blocked_word(new.body) then
    raise exception 'comment_blocked' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.comments c
    where c.author_id = new.author_id
      and c.id <> new.id
      and public.normalize_comment(c.body) = v_norm
      and (c.post_id = new.post_id or c.created_at > now() - interval '10 minutes')
  ) then
    raise exception 'comment_duplicate' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger check_comment
  before insert or update of body on public.comments
  for each row execute function public.check_comment();
