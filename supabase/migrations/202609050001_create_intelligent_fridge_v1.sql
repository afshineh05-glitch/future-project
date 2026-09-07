create table if not exists public.user_fridge_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ingredient_key text not null,
  ingredient_name text not null,
  category text not null,
  quantity numeric null check (quantity >= 0 and quantity <= 100000),
  quantity_unit text null check (quantity_unit is null or quantity_unit in ('g', 'kg', 'item')),
  is_available boolean not null default true,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, ingredient_key)
);

alter table public.user_fridge_items enable row level security;

create policy "Users can read their own fridge items"
  on public.user_fridge_items for select
  using (auth.uid() = user_id);
create policy "Users can insert their own fridge items"
  on public.user_fridge_items for insert
  with check (auth.uid() = user_id);
create policy "Users can update their own fridge items"
  on public.user_fridge_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "Users can delete their own fridge items"
  on public.user_fridge_items for delete
  using (auth.uid() = user_id);

create table if not exists public.user_food_source_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ingredient_key text not null,
  weight numeric not null default 1 check (weight > 0 and weight <= 100),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, ingredient_key)
);

alter table public.user_food_source_preferences enable row level security;

create policy "Users can read their own food source preferences"
  on public.user_food_source_preferences for select
  using (auth.uid() = user_id);
create policy "Users can insert their own food source preferences"
  on public.user_food_source_preferences for insert
  with check (auth.uid() = user_id);
create policy "Users can update their own food source preferences"
  on public.user_food_source_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "Users can delete their own food source preferences"
  on public.user_food_source_preferences for delete
  using (auth.uid() = user_id);

create table if not exists public.commerce_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  partner_id text not null,
  event_type text not null check (event_type in ('partner_impression', 'outbound_click')),
  source text not null,
  recipe_id text null,
  ingredient_key text null,
  created_at timestamptz not null default now()
);

alter table public.commerce_events enable row level security;

create policy "Users can read their own commerce events"
  on public.commerce_events for select
  using (auth.uid() = user_id);
create policy "Users can insert their own commerce events"
  on public.commerce_events for insert
  with check (auth.uid() = user_id);
