-- Makos Coaches app: notes for the coaching staff only. Families never see these.
-- A monthly write-up that describes each kid, a running discussion thread, and the end-of-season exit interview they build toward.
-- Run once in the Supabase SQL editor (project rvmvwijyxeghzchyxeht).

-- 0. Who gets in: coaches (Devan, Nick), the Movement Coach (pt), and 'staff' (helpers who only use Makos Coaches,
--    not the family app). Staff rows have no player and do not unlock anything in the family app.
alter table public.family_access drop constraint if exists family_access_role_check;
alter table public.family_access add constraint family_access_role_check check (role in ('family', 'coach', 'pt', 'staff'));
alter table public.family_access add column if not exists display_name text;
create or replace function public.is_staff() returns boolean
  language sql stable security definer set search_path = public as
  $$ select exists (select 1 from public.family_access where lower(email) = public.my_email() and role in ('coach', 'pt', 'staff')) $$;

-- An earlier draft had no month column. If that ran, the table is empty: replace it.
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'player_profiles')
     and not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'player_profiles' and column_name = 'month') then
    drop table public.player_profiles;
  end if;
end $$;

-- 1. Who the kid is: one write-up per player per month, either coach can edit
create table if not exists public.player_profiles (
  player_id text not null references public.players(id) on delete cascade,
  month date not null,
  positions text,
  strengths text,
  work_on text,
  what_works text,
  next_plan text,
  updated_by text,
  updated_at timestamptz not null default now(),
  primary key (player_id, month)
);
alter table public.player_profiles add column if not exists next_plan text;

-- 2. The discussion (one row per note)
create table if not exists public.coach_notes (
  id uuid primary key default gen_random_uuid(),
  player_id text not null references public.players(id) on delete cascade,
  author text not null default public.my_email(),
  tag text not null default 'General',
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists coach_notes_player_idx on public.coach_notes (player_id, created_at desc);

alter table public.player_profiles enable row level security;
alter table public.coach_notes enable row level security;

drop policy if exists "coaches manage profiles" on public.player_profiles;
create policy "coaches manage profiles" on public.player_profiles for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

drop policy if exists "coaches read notes" on public.coach_notes;
create policy "coaches read notes" on public.coach_notes for select to authenticated using (public.is_staff());
drop policy if exists "coaches add notes" on public.coach_notes;
create policy "coaches add notes" on public.coach_notes for insert to authenticated
  with check (public.is_staff() and author = public.my_email());
drop policy if exists "coaches delete own notes" on public.coach_notes;
create policy "coaches delete own notes" on public.coach_notes for delete to authenticated
  using (public.is_staff() and author = public.my_email());

-- 3. Interviews: a midway check-in and an end-of-year exit interview per player per season (season = Aug–Jul)
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'exit_interviews')
     and not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'exit_interviews' and column_name = 'stage') then
    drop table public.exit_interviews;
  end if;
end $$;
create table if not exists public.exit_interviews (
  player_id text not null references public.players(id) on delete cascade,
  season text not null,
  stage text not null default 'end' check (stage in ('mid', 'end')),
  growth text,
  strengths text,
  offseason text,
  next_season text,
  family_message text,
  updated_by text,
  updated_at timestamptz not null default now(),
  primary key (player_id, season, stage)
);
alter table public.exit_interviews enable row level security;
drop policy if exists "coaches manage exit interviews" on public.exit_interviews;
create policy "coaches manage exit interviews" on public.exit_interviews for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- 4. GameChanger numbers: each import of a GameChanger "Export stats" file saves one snapshot per player
create table if not exists public.gc_stats (
  id uuid primary key default gen_random_uuid(),
  player_id text not null references public.players(id) on delete cascade,
  snapshot date not null,
  team text,
  stats jsonb not null,
  imported_by text not null default public.my_email(),
  imported_at timestamptz not null default now(),
  unique (player_id, snapshot, team)
);
alter table public.gc_stats enable row level security;
drop policy if exists "coaches manage gc stats" on public.gc_stats;
create policy "coaches manage gc stats" on public.gc_stats for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- 5. Staff can READ what kids log in the family app (players, cage sessions, session reports). Read only.
drop policy if exists "staff reads players" on public.players;
create policy "staff reads players" on public.players for select to authenticated using (public.is_staff());
drop policy if exists "staff reads log" on public.log;
create policy "staff reads log" on public.log for select to authenticated using (public.is_staff());
drop policy if exists "staff reads feedback" on public.cage_feedback;
create policy "staff reads feedback" on public.cage_feedback for select to authenticated using (public.is_staff());

-- 6. Names on notes ("Devan", "Nick", "Coach Ahart"...), visible to staff only
create or replace function public.staff_names() returns table (email text, display_name text, role text)
  language sql stable security definer set search_path = public as
  $$ select lower(email), display_name, role from public.family_access
     where role in ('coach', 'pt', 'staff') and public.is_staff() $$;
grant execute on function public.staff_names() to authenticated;
