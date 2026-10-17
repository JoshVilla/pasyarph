-- PostGIS for route lines, stop points and distance queries.
-- Supabase keeps extensions in the `extensions` schema.
create extension if not exists postgis with schema extensions;

create type public.bike_type as enum ('scooter', 'underbone', 'big_bike', 'dual_sport');
create type public.loop_source as enum ('generated', 'custom');
create type public.loop_visibility as enum ('public', 'club', 'private');
create type public.club_role as enum ('owner', 'member');
create type public.report_target as enum ('post', 'comment', 'loop', 'user');
