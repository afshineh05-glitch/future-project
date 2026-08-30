create table if not exists public.vision_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  primary_goal text not null,
  future_identity text not null,
  desired_feelings text[] not null default '{}',
  vision_statement text not null default 'This is who I''m becoming.',
  my_why text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vision_profiles_why_length check (char_length(my_why) <= 500)
);

create table if not exists public.vision_daily_reflections (
  user_id uuid not null references auth.users(id) on delete cascade,
  reflection_date date not null,
  response text not null check (response in ('yes', 'a_little', 'not_today')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, reflection_date),
  constraint vision_reflections_note_length check (char_length(note) <= 240)
);

create index if not exists vision_reflections_user_date_idx
  on public.vision_daily_reflections(user_id, reflection_date desc);

alter table public.vision_profiles enable row level security;
alter table public.vision_daily_reflections enable row level security;

create policy "Users manage their vision profile" on public.vision_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their vision reflections" on public.vision_daily_reflections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
