-- Makos Coaches app: notes for coaches only (Devan + Nick). Families and the Movement Coach never see these.
-- A monthly write-up that describes each kid, a running discussion thread, and the end-of-season exit interview they build toward.
-- Run once in the Supabase SQL editor (project rvmvwijyxeghzchyxeht).

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
  using (public.is_coach()) with check (public.is_coach());

drop policy if exists "coaches read notes" on public.coach_notes;
create policy "coaches read notes" on public.coach_notes for select to authenticated using (public.is_coach());
drop policy if exists "coaches add notes" on public.coach_notes;
create policy "coaches add notes" on public.coach_notes for insert to authenticated
  with check (public.is_coach() and author = public.my_email());
drop policy if exists "coaches delete own notes" on public.coach_notes;
create policy "coaches delete own notes" on public.coach_notes for delete to authenticated
  using (public.is_coach() and author = public.my_email());

-- 3. Exit interview: one per player per season, built from the monthly write-ups and notes
create table if not exists public.exit_interviews (
  player_id text not null references public.players(id) on delete cascade,
  season text not null,
  growth text,
  strengths text,
  offseason text,
  next_season text,
  family_message text,
  updated_by text,
  updated_at timestamptz not null default now(),
  primary key (player_id, season)
);
alter table public.exit_interviews enable row level security;
drop policy if exists "coaches manage exit interviews" on public.exit_interviews;
create policy "coaches manage exit interviews" on public.exit_interviews for all to authenticated
  using (public.is_coach()) with check (public.is_coach());
