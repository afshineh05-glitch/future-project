create table if not exists public.vision_daily_reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reflection_date date not null,
  reflection_value text not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vision_daily_reflections_value_check
    check (reflection_value in ('yes', 'a_little', 'not_today')),
  constraint vision_daily_reflections_user_date_key
    unique (user_id, reflection_date)
);

-- Normalize databases where the earlier, already-versioned migration file was
-- run after its local contents gained the temporary `response`-based shape.
alter table public.vision_daily_reflections
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists reflection_value text,
  add column if not exists note text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'vision_daily_reflections'
      and column_name = 'response'
  ) then
    update public.vision_daily_reflections
    set reflection_value = response
    where reflection_value is null;

    alter table public.vision_daily_reflections drop column response;
  end if;
end;
$$;

alter table public.vision_daily_reflections
  alter column id set not null,
  alter column reflection_value set not null;

do $$
declare
  primary_key_name text;
begin
  select constraint_name
  into primary_key_name
  from information_schema.table_constraints
  where table_schema = 'public'
    and table_name = 'vision_daily_reflections'
    and constraint_type = 'PRIMARY KEY';

  if primary_key_name is not null and primary_key_name <> 'vision_daily_reflections_pkey' then
    execute format(
      'alter table public.vision_daily_reflections drop constraint %I',
      primary_key_name
    );
  elsif primary_key_name = 'vision_daily_reflections_pkey' and exists (
    select 1
    from information_schema.key_column_usage
    where table_schema = 'public'
      and table_name = 'vision_daily_reflections'
      and constraint_name = primary_key_name
      and column_name <> 'id'
  ) then
    alter table public.vision_daily_reflections
      drop constraint vision_daily_reflections_pkey;
  end if;

  if not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'vision_daily_reflections'
      and constraint_type = 'PRIMARY KEY'
  ) then
    alter table public.vision_daily_reflections
      add constraint vision_daily_reflections_pkey primary key (id);
  end if;
end;
$$;

alter table public.vision_daily_reflections
  drop constraint if exists vision_daily_reflections_response_check,
  drop constraint if exists vision_reflections_note_length,
  drop constraint if exists vision_daily_reflections_value_check;

alter table public.vision_daily_reflections
  add constraint vision_daily_reflections_value_check
    check (reflection_value in ('yes', 'a_little', 'not_today')),
  add constraint vision_daily_reflections_note_length
    check (note is null or char_length(note) <= 240);

do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'vision_daily_reflections'
      and constraint_name = 'vision_daily_reflections_user_date_key'
      and constraint_type = 'UNIQUE'
  ) then
    alter table public.vision_daily_reflections
      add constraint vision_daily_reflections_user_date_key
      unique (user_id, reflection_date);
  end if;
end;
$$;

drop index if exists public.vision_reflections_user_date_idx;

create index if not exists vision_daily_reflections_user_date_idx
  on public.vision_daily_reflections(user_id, reflection_date desc);

create or replace function public.set_vision_daily_reflections_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_vision_daily_reflections_updated_at
on public.vision_daily_reflections;

create trigger set_vision_daily_reflections_updated_at
before update on public.vision_daily_reflections
for each row
execute function public.set_vision_daily_reflections_updated_at();

alter table public.vision_daily_reflections enable row level security;

drop policy if exists "Users manage their vision reflections"
on public.vision_daily_reflections;
drop policy if exists "Users can read their vision reflections"
on public.vision_daily_reflections;
drop policy if exists "Users can create their vision reflections"
on public.vision_daily_reflections;
drop policy if exists "Users can update their vision reflections"
on public.vision_daily_reflections;
drop policy if exists "Users can delete their vision reflections"
on public.vision_daily_reflections;

create policy "Users can read their vision reflections"
on public.vision_daily_reflections
for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their vision reflections"
on public.vision_daily_reflections
for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their vision reflections"
on public.vision_daily_reflections
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their vision reflections"
on public.vision_daily_reflections
for delete to authenticated
using ((select auth.uid()) = user_id);
