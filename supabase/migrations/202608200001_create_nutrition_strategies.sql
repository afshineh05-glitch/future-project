create table if not exists public.nutrition_strategies (
  user_id uuid primary key references auth.users(id) on delete cascade,
  goal text not null,
  calories_target integer not null check (calories_target > 0),
  calories_range_min integer not null check (calories_range_min > 0),
  calories_range_max integer not null check (
    calories_range_max >= calories_range_min
  ),
  protein_g integer not null check (protein_g > 0),
  carbs_g integer not null check (carbs_g >= 0),
  fat_g integer not null check (fat_g > 0),
  fiber_g integer not null check (fiber_g > 0),
  hydration_l numeric(4, 1) not null check (hydration_l > 0),
  micronutrient_focus text[] not null default '{}'::text[],
  why text not null,
  calculation_version text not null,
  input_fingerprint text not null,
  input_context jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.nutrition_strategies enable row level security;

create policy "Users can read their nutrition strategy"
on public.nutrition_strategies
for select
to authenticated
using ((select auth.uid()) = user_id);

-- Calculation writes remain server-side through the service-role client.

create or replace function public.set_nutrition_strategies_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_nutrition_strategies_updated_at
on public.nutrition_strategies;

create trigger set_nutrition_strategies_updated_at
before update on public.nutrition_strategies
for each row
execute function public.set_nutrition_strategies_updated_at();
