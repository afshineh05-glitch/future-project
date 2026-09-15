create table if not exists public.behavior_patterns (
  user_id uuid not null references auth.users(id) on delete cascade,
  fingerprint text not null check (fingerprint ~ '^v1:' and char_length(fingerprint) <= 160),
  pattern_type text not null check (pattern_type in (
    'strongTrainingWeekday', 'missedTrainingWeekday', 'shortenedWorkouts',
    'nutritionRhythm', 'reflectionRhythm', 'recoveryLinkedAdherence',
    'returnAfterGap', 'consistentRoutine'
  )),
  direction text not null check (direction in ('positive', 'negative', 'mixed')),
  confidence_band text not null check (confidence_band in ('emerging', 'established', 'strong')),
  observations integer not null check (observations >= 2),
  evidence jsonb not null check (jsonb_typeof(evidence) = 'array'),
  window_start date not null,
  window_end date not null,
  coach_hint text not null check (char_length(coach_hint) between 1 and 240),
  learned_at timestamptz not null,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, fingerprint),
  constraint behavior_patterns_42_day_window check (window_end - window_start = 41)
);

create index if not exists behavior_patterns_active_user_idx
  on public.behavior_patterns (user_id, learned_at desc) where retired_at is null;

alter table public.behavior_patterns enable row level security;

create policy "Users can select their own behavior patterns" on public.behavior_patterns
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert their own behavior patterns" on public.behavior_patterns
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their own behavior patterns" on public.behavior_patterns
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own behavior patterns" on public.behavior_patterns
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Atomically upserts the current fingerprints and retires previously learned
-- patterns that the latest 42-day evidence no longer supports.
create or replace function public.replace_behavior_patterns_v1(
  p_patterns jsonb,
  p_learned_at timestamptz
)
returns setof public.behavior_patterns
language plpgsql security invoker set search_path = ''
as $$
begin
  if jsonb_typeof(p_patterns) <> 'array' then
    raise exception 'Patterns must be a JSON array';
  end if;

  update public.behavior_patterns
  set retired_at = p_learned_at, updated_at = now()
  where user_id = (select auth.uid())
    and retired_at is null
    and not exists (
      select 1 from jsonb_array_elements(p_patterns) item
      where item->>'fingerprint' = behavior_patterns.fingerprint
    );

  insert into public.behavior_patterns (
    user_id, fingerprint, pattern_type, direction, confidence_band,
    observations, evidence, window_start, window_end, coach_hint, learned_at,
    retired_at
  )
  select (select auth.uid()), item->>'fingerprint', item->>'pattern_type',
    item->>'direction', item->>'confidence_band',
    (item->>'observations')::integer, item->'evidence',
    (item->>'window_start')::date, (item->>'window_end')::date,
    item->>'coach_hint', p_learned_at, null
  from jsonb_array_elements(p_patterns) item
  on conflict (user_id, fingerprint) do update set
    pattern_type = excluded.pattern_type,
    direction = excluded.direction,
    confidence_band = excluded.confidence_band,
    observations = excluded.observations,
    evidence = excluded.evidence,
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    coach_hint = excluded.coach_hint,
    learned_at = excluded.learned_at,
    retired_at = null,
    updated_at = now();

  return query select * from public.behavior_patterns
    where user_id = (select auth.uid()) and retired_at is null;
end;
$$;

revoke all on function public.replace_behavior_patterns_v1(jsonb,timestamptz) from public, anon;
grant execute on function public.replace_behavior_patterns_v1(jsonb,timestamptz) to authenticated;
