-- pgTAP tests for text posts (create_text_post, feed_page kind 'text').
-- Run with `npx supabase test db`. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

create function pg_temp.act_as(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
end;
$$;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a3', 'a3@test.ph', '{"full_name": "Ana Writer"}'),
  ('00000000-0000-0000-0000-0000000000b3', 'b3@test.ph', '{"full_name": "Ben Reader"}');

-- Ana: a club, then a public, a club and a private text post.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
insert into clubs (id, name) values ('13000000-0000-0000-0000-000000000001', 'Writers');

select is(
  create_text_post('33000000-0000-0000-0000-000000000001', '  Is the road to Daranak open?  ',
                   'public', null, '[]'),
  '33000000-0000-0000-0000-000000000001'::uuid,
  'a text post needs no ride'
);
select create_text_post('33000000-0000-0000-0000-000000000002', 'Club meetup Saturday',
                        'club', '13000000-0000-0000-0000-000000000001', '[]');
select create_text_post('33000000-0000-0000-0000-000000000003', 'Note to self',
                        'private', null, '[]');

select is(
  (select caption from posts where id = '33000000-0000-0000-0000-000000000001'),
  'Is the road to Daranak open?',
  'the text is trimmed'
);
select is(
  create_text_post('33000000-0000-0000-0000-000000000001', 'Is the road to Daranak open?',
                   'public', null, '[]'),
  '33000000-0000-0000-0000-000000000001'::uuid,
  'posting the same id again (a lost reply) returns it'
);
select throws_like(
  $$select create_text_post('33000000-0000-0000-0000-000000000009', '   ', 'public', null, '[]')$$,
  '%bad_text%',
  'empty text is refused'
);
select throws_like(
  $$select create_text_post('33000000-0000-0000-0000-000000000009', 'Hi', 'public', null,
      '[{"storage_path": "someone-else/x/0.jpg", "position": 0}]')$$,
  '%bad_photos%',
  'photos must be in the author''s folder for this post'
);
select is(
  (select kind from feed_page('club', '13000000-0000-0000-0000-000000000001')
   where id = '33000000-0000-0000-0000-000000000002'),
  'text',
  'a club text post is on the club page, as kind text'
);
select is(
  (select loop from feed_page('rider', '00000000-0000-0000-0000-0000000000a3')
   where id = '33000000-0000-0000-0000-000000000001'),
  null,
  'a text post has no loop'
);

-- Ben: not in the club.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b3');
select set_eq(
  $$select id from feed_page('global') where id::text like '33000000-%'$$,
  $$values ('33000000-0000-0000-0000-000000000001'::uuid)$$,
  'Global shows public text posts only'
);
select is_empty(
  $$select id from feed_near(16.67, 121.45, 20000000) where id::text like '33000000-%'$$,
  'text posts never show in Near you'
);
select is_empty(
  $$select id from posts where id = '33000000-0000-0000-0000-000000000003'$$,
  'a private text post is hidden from others'
);
select throws_like(
  $$select create_text_post('33000000-0000-0000-0000-000000000008', 'Let me in', 'club',
      '13000000-0000-0000-0000-000000000001', '[]')$$,
  '%not_club_member%',
  'posting to a club you''re not in is refused'
);
select lives_ok(
  $$insert into comments (post_id, body) values ('33000000-0000-0000-0000-000000000001', 'Open na!')$$,
  'others can comment on a public text post'
);
select is(
  link_preview('post', '33000000-0000-0000-0000-000000000002')->>'status',
  'club',
  'a club text post link says it''s for the club'
);

-- Deleting the club makes its text posts private, not gone.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
delete from clubs where id = '13000000-0000-0000-0000-000000000001';
select is(
  (select visibility::text from posts where id = '33000000-0000-0000-0000-000000000002'),
  'private',
  'a deleted club''s text posts become private'
);

select * from finish();
rollback;
