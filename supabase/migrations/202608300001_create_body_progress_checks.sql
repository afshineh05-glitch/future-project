create table if not exists public.body_progress_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight numeric(7,2) not null check (weight > 0),
  waist numeric(7,2) not null check (waist > 0),
  chest numeric(7,2) not null check (chest > 0),
  hips numeric(7,2) not null check (hips > 0),
  arm numeric(7,2) not null check (arm > 0),
  thigh numeric(7,2) not null check (thigh > 0),
  neck numeric(7,2) not null check (neck > 0),
  note text check (note is null or char_length(note) <= 1000),
  checked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists body_progress_checks_user_checked_at_idx
  on public.body_progress_checks (user_id, checked_at desc);

alter table public.body_progress_checks enable row level security;

create policy "Users can select their own body progress checks"
  on public.body_progress_checks for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own body progress checks"
  on public.body_progress_checks for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own body progress checks"
  on public.body_progress_checks for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.set_body_progress_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_body_progress_checks_updated_at
before update on public.body_progress_checks
for each row execute function public.set_body_progress_updated_at();
