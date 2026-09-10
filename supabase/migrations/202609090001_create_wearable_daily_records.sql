create table if not exists public.wearable_daily_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  steps integer,
  active_energy_kcal numeric(10, 2),
  average_heart_rate_bpm numeric(7, 2),
  resting_heart_rate_bpm numeric(7, 2),
  distance_meters numeric(12, 2),
  sleep_minutes integer,
  body_weight_kg numeric(7, 2),
  source_updated_at timestamptz not null,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, local_date)
);

create index if not exists wearable_daily_records_user_date_idx
  on public.wearable_daily_records (user_id, local_date desc);

alter table public.wearable_daily_records enable row level security;

create policy "Users can select their own wearable daily records"
  on public.wearable_daily_records for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own wearable daily records"
  on public.wearable_daily_records for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own wearable daily records"
  on public.wearable_daily_records for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own wearable daily records"
  on public.wearable_daily_records for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.sync_wearable_daily_record(
  p_local_date date,
  p_steps integer,
  p_active_energy_kcal numeric,
  p_average_heart_rate_bpm numeric,
  p_resting_heart_rate_bpm numeric,
  p_distance_meters numeric,
  p_sleep_minutes integer,
  p_body_weight_kg numeric,
  p_source_updated_at timestamptz
)
returns setof public.wearable_daily_records
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return query
  insert into public.wearable_daily_records (
    user_id,
    local_date,
    steps,
    active_energy_kcal,
    average_heart_rate_bpm,
    resting_heart_rate_bpm,
    distance_meters,
    sleep_minutes,
    body_weight_kg,
    source_updated_at
  ) values (
    (select auth.uid()),
    p_local_date,
    p_steps,
    p_active_energy_kcal,
    p_average_heart_rate_bpm,
    p_resting_heart_rate_bpm,
    p_distance_meters,
    p_sleep_minutes,
    p_body_weight_kg,
    p_source_updated_at
  )
  on conflict (user_id, local_date) do update set
    steps = coalesce(excluded.steps, wearable_daily_records.steps),
    active_energy_kcal = coalesce(
      excluded.active_energy_kcal,
      wearable_daily_records.active_energy_kcal
    ),
    average_heart_rate_bpm = coalesce(
      excluded.average_heart_rate_bpm,
      wearable_daily_records.average_heart_rate_bpm
    ),
    resting_heart_rate_bpm = coalesce(
      excluded.resting_heart_rate_bpm,
      wearable_daily_records.resting_heart_rate_bpm
    ),
    distance_meters = coalesce(
      excluded.distance_meters,
      wearable_daily_records.distance_meters
    ),
    sleep_minutes = coalesce(
      excluded.sleep_minutes,
      wearable_daily_records.sleep_minutes
    ),
    body_weight_kg = coalesce(
      excluded.body_weight_kg,
      wearable_daily_records.body_weight_kg
    ),
    source_updated_at = excluded.source_updated_at,
    synced_at = now(),
    updated_at = now()
  where excluded.source_updated_at >= wearable_daily_records.source_updated_at
  returning wearable_daily_records.*;
end;
$$;

revoke all on function public.sync_wearable_daily_record(
  date, integer, numeric, numeric, numeric, numeric, integer, numeric, timestamptz
) from public, anon;

grant execute on function public.sync_wearable_daily_record(
  date, integer, numeric, numeric, numeric, numeric, integer, numeric, timestamptz
) to authenticated;
