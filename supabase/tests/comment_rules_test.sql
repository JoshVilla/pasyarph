-- Checks the comment word filter (Prompt 14). Run in the Supabase SQL
-- editor after 20261019000500_comment_rules.sql; it changes nothing.
-- "Success. No rows returned" means every check passed.
do $$
begin
  assert public.normalize_comment('GaaaaGO ka!!') = 'gago ka', 'squeeze and lowercase';
  assert public.normalize_comment('p.u.t.a') = 'p u t a', 'dots split letters';
  assert public.normalize_comment('5h1t') = 'shit', 'letter swaps';

  assert public.has_blocked_word('Ang ganda, tangina!'), 'Filipino word';
  assert public.has_blocked_word('putang ina mo'), 'Filipino phrase';
  assert public.has_blocked_word('what the F U C K'::text) = false,
    'spaced-out letters are not caught (known limit)';
  assert public.has_blocked_word('this is 5h1t'), 'swapped letters';
  assert public.has_blocked_word('GAAAGO'), 'repeated letters';

  -- Whole words only: no false alarms inside normal words.
  assert not public.has_blocked_word('Shiitake at the market, then Scunthorpe road'),
    'shiitake / Scunthorpe';
  assert not public.has_blocked_word('Dumaan kami sa Putatan at Lecheria'),
    'place names containing blocked words';
  assert not public.has_blocked_word('Ganda ng falls, salamat sa ride!'),
    'a normal comment';
end;
$$;
