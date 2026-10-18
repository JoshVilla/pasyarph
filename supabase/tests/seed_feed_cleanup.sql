-- Removes the posts seed_feed.sql added (their photos go with them; the
-- photo files belong to the real post and stay).
delete from public.posts where caption like '[test]%';
