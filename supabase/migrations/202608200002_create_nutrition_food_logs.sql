create table if not exists public.nutrition_food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  consumed_at timestamptz not null default now(),
  food_name text not null,
  calories numeric(10, 2) not null check (calories >= 0),
  protein_g numeric(10, 2) not null check (protein_g >= 0),
  carbs_g numeric(10, 2) not null check (carbs_g >= 0),
  fat_g numeric(10, 2) not null check (fat_g >= 0),
  fiber_g numeric(10, 2) null check (fiber_g is null or fiber_g >= 0),
  source text not null,
  analysis_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, analysis_reference)
);

create index nutrition_food_logs_user_consumed_at_idx
on public.nutrition_food_logs (user_id, consumed_at desc);

alter table public.nutrition_food_logs enable row level security;

create policy "Users can read their nutrition food logs"
on public.nutrition_food_logs for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their nutrition food logs"
on public.nutrition_food_logs for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their nutrition food logs"
on public.nutrition_food_logs for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their nutrition food logs"
on public.nutrition_food_logs for delete to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.set_nutrition_food_logs_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_nutrition_food_logs_updated_at
before update on public.nutrition_food_logs
for each row execute function public.set_nutrition_food_logs_updated_at();
