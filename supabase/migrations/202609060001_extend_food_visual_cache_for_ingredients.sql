alter table public.food_visuals
  alter column image_url drop not null,
  alter column storage_path drop not null;

alter table public.food_visuals
  add column if not exists status text not null default 'ready',
  add column if not exists fetched_at timestamptz not null default now(),
  add column if not exists retry_after timestamptz;

alter table public.food_visuals
  drop constraint if exists food_visuals_status_valid;

alter table public.food_visuals
  add constraint food_visuals_status_valid
  check (status in ('ready', 'missing', 'failed'));

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'ingredient-images',
  'ingredient-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Writes remain service-role-only. Public bucket objects are readable through
-- their stable CDN URL; no client insert/update/delete policy is created.
