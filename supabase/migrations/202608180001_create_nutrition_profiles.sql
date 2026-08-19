create table if not exists public.nutrition_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  diet_type text not null check (
    diet_type in ('Omnivore', 'Vegetarian', 'Vegan', 'Pescatarian')
  ),
  food_allergies text[] not null default array['None']::text[],
  foods_to_avoid text[] not null default '{}'::text[],
  disliked_foods text[] not null default '{}'::text[],
  meals_per_day text not null check (
    meals_per_day in ('2', '3', '4', '5+')
  ),
  maximum_cooking_time text not null check (
    maximum_cooking_time in ('≤15 min', '≤30 min', '≤45 min')
  ),
  cooking_skill text not null check (
    cooking_skill in ('Beginner', 'Comfortable', 'Advanced')
  ),
  food_budget text not null check (
    food_budget in ('Budget-conscious', 'Moderate', 'Flexible')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nutrition_profiles_allergies_not_empty
    check (cardinality(food_allergies) > 0),
  constraint nutrition_profiles_none_allergy_exclusive
    check (
      not ('None' = any(food_allergies))
      or cardinality(food_allergies) = 1
    )
);

alter table public.nutrition_profiles enable row level security;

create policy "Users can read their nutrition profile"
on public.nutrition_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their nutrition profile"
on public.nutrition_profiles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their nutrition profile"
on public.nutrition_profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their nutrition profile"
on public.nutrition_profiles
for delete
to authenticated
using ((select auth.uid()) = user_id);
