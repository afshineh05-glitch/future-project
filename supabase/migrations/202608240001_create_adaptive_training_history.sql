-- Canonical performed-workout history for the existing Training Plan.
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.training_plans(id) on delete set null,
  training_day_id uuid references public.training_days(id) on delete set null,
  scheduled_at timestamptz not null,
  started_at timestamptz,
  completed_at timestamptz,
  status text not null check (status in ('completed', 'partial', 'skipped')),
  planned_duration_minutes integer,
  actual_duration_minutes integer,
  recovery_feedback jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.workout_exercise_performances (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  training_exercise_id uuid references public.training_exercises(id) on delete set null,
  exercise_id text not null,
  planned_sets integer not null default 0,
  target_rep_min integer,
  target_rep_max integer,
  completed_sets integer not null default 0,
  perceived_difficulty numeric check (perceived_difficulty between 1 and 10),
  status text not null check (status in ('completed', 'partial', 'skipped')),
  substituted_from_exercise_id text,
  substitution_reason text,
  performed_sets jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.exercise_preference_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null,
  signal text not null check (signal in ('completed','skipped','replaced','added','removed','liked','disliked','excluded')),
  replacement_exercise_id text,
  reason text,
  session_id uuid references public.workout_sessions(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists workout_sessions_user_date_idx on public.workout_sessions(user_id, scheduled_at desc);
create index if not exists workout_performance_exercise_idx on public.workout_exercise_performances(exercise_id, created_at desc);
create index if not exists preference_events_user_exercise_idx on public.exercise_preference_events(user_id, exercise_id, created_at desc);

alter table public.workout_sessions enable row level security;
alter table public.workout_exercise_performances enable row level security;
alter table public.exercise_preference_events enable row level security;

create policy "Users manage own workout sessions" on public.workout_sessions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own workout performances" on public.workout_exercise_performances for all using (exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid())) with check (exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid()));
create policy "Users manage own preference events" on public.exercise_preference_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
