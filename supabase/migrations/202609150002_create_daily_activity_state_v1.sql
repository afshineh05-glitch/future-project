-- Derived, read-through index of existing authoritative daily sources.
-- This table never replaces workout, nutrition, reflection, or mission rows.
create table if not exists public.daily_activity_state (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  activity_identity text not null check (char_length(activity_identity) between 1 and 160),
  activity_type text not null check (activity_type in (
    'workout', 'nutrition', 'reflection', 'weeklyMission', 'dailyDecision'
  )),
  status text not null check (status in (
    'planned', 'recorded', 'partial', 'completed', 'skipped'
  )),
  source_table text not null check (source_table in (
    'workout_sessions', 'nutrition_food_logs', 'vision_daily_reflections',
    'coach_weekly_plans', 'coach_daily_decisions'
  )),
  source_id text,
  observation_count integer not null default 1 check (observation_count >= 1),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  first_observed_at timestamptz not null,
  last_observed_at timestamptz not null,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, local_date, activity_identity),
  constraint daily_activity_identity_namespace check (
    (activity_type = 'workout' and activity_identity like 'workout:%') or
    (activity_type = 'nutrition' and activity_identity = 'nutrition:daily') or
    (activity_type = 'reflection' and activity_identity = 'reflection:daily') or
    (activity_type = 'weeklyMission' and activity_identity like 'weekly_mission:%') or
    (activity_type = 'dailyDecision' and activity_identity = 'daily_decision')
  )
);

create index if not exists daily_activity_state_user_date_idx
  on public.daily_activity_state (user_id, local_date desc)
  where retired_at is null;

alter table public.daily_activity_state enable row level security;

create policy "Users can select their own daily activity state"
  on public.daily_activity_state for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert their own daily activity state"
  on public.daily_activity_state for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own daily activity state"
  on public.daily_activity_state for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own daily activity state"
  on public.daily_activity_state for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.sync_daily_activity_state_v1(
  p_local_date date,
  p_activities jsonb,
  p_observed_types jsonb,
  p_synced_at timestamptz
)
returns setof public.daily_activity_state
language plpgsql security invoker set search_path = ''
as $$
begin
  if p_local_date is null or p_synced_at is null then
    raise exception 'Local date and sync time are required';
  end if;
  if jsonb_typeof(p_activities) <> 'array' then
    raise exception 'Activities must be a JSON array';
  end if;
  if jsonb_typeof(p_observed_types) <> 'array' then
    raise exception 'Observed types must be a JSON array';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_activities) item
    group by item->>'activity_identity'
    having count(*) > 1
  ) then
    raise exception 'Activity identities must be unique per local date';
  end if;

  update public.daily_activity_state
  set retired_at = p_synced_at, updated_at = now()
  where user_id = (select auth.uid())
    and local_date = p_local_date
    and retired_at is null
    and activity_type in (
      select jsonb_array_elements_text(p_observed_types)
    )
    and not exists (
      select 1 from jsonb_array_elements(p_activities) item
      where item->>'activity_identity' = daily_activity_state.activity_identity
    );

  -- A workout keeps its source UUID when edited or rescheduled. Retire an
  -- older active date before activating the same source session on this date.
  update public.daily_activity_state existing
  set retired_at = p_synced_at, updated_at = now()
  where existing.user_id = (select auth.uid())
    and existing.activity_type = 'workout'
    and existing.local_date <> p_local_date
    and existing.retired_at is null
    and exists (
      select 1 from jsonb_array_elements(p_activities) item
      where item->>'activity_type' = 'workout'
        and item->>'source_id' = existing.source_id
    );

  insert into public.daily_activity_state (
    user_id, local_date, activity_identity, activity_type, status,
    source_table, source_id, observation_count, metadata,
    first_observed_at, last_observed_at, retired_at
  )
  select (select auth.uid()), p_local_date, item->>'activity_identity',
    item->>'activity_type', item->>'status', item->>'source_table',
    item->>'source_id', coalesce((item->>'observation_count')::integer, 1),
    coalesce(item->'metadata', '{}'::jsonb), p_synced_at, p_synced_at, null
  from jsonb_array_elements(p_activities) item
  on conflict (user_id, local_date, activity_identity) do update set
    activity_type = excluded.activity_type,
    status = excluded.status,
    source_table = excluded.source_table,
    source_id = excluded.source_id,
    observation_count = excluded.observation_count,
    metadata = excluded.metadata,
    last_observed_at = excluded.last_observed_at,
    retired_at = null,
    updated_at = now();

  return query
  select * from public.daily_activity_state
  where user_id = (select auth.uid())
    and local_date = p_local_date
    and retired_at is null
  order by activity_identity;
end;
$$;

revoke all on function public.sync_daily_activity_state_v1(date,jsonb,jsonb,timestamptz)
  from public, anon;
grant execute on function public.sync_daily_activity_state_v1(date,jsonb,jsonb,timestamptz)
  to authenticated;
