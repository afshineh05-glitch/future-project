create extension if not exists pgcrypto;

create table if not exists public.food_visuals (
  id uuid primary key default gen_random_uuid(),
  food_key text unique not null,
  display_name text not null,
  image_url text not null,
  storage_path text not null unique,
  source text not null,
  source_image_id text,
  source_page_url text,
  search_query text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_visuals_key_format
    check (food_key ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  constraint food_visuals_source_not_blank
    check (length(trim(source)) > 0)
);

alter table public.food_visuals enable row level security;

-- Intentionally no client-facing table policies. The authenticated Edge
-- Function resolves visuals and the service-role client owns cache writes.

create or replace function public.set_food_visuals_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_food_visuals_updated_at
on public.food_visuals;

create trigger set_food_visuals_updated_at
before update on public.food_visuals
for each row
execute function public.set_food_visuals_updated_at();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'food-visuals',
  'food-visuals',
  true,
  10485760,
  array['image/jpeg']::text[]
)
on conflict (id) do nothing;

-- The bucket is public for stable CDN reads. No storage.objects insert,
-- update, or delete policy is created; writes remain service-role-only.
