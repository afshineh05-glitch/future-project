create table if not exists public.coach_weekly_plans (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  week_end date not null,
  short_retrospective text not null,
  biggest_win text not null,
  main_limiting_factor text not null,
  mission_type text not null check (mission_type in ('protect_recovery', 'improve_training_night_sleep', 'improve_workout_consistency', 'reduce_activity_load', 'maintain_successful_behavior')),
  mission_title text not null,
  mission_reason text not null,
  action_items jsonb not null check (jsonb_typeof(action_items) = 'array' and jsonb_array_length(action_items) between 1 and 3),
  motivation_context text not null,
  previous_mission_title text,
  previous_mission_outcome text not null check (previous_mission_outcome in ('success', 'partial_improvement', 'unchanged', 'insufficient_data')),
  follow_up_message text not null,
  wearable_days integer not null check (wearable_days between 0 and 7),
  workout_source_available boolean not null,
  evidence jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, week_start)
);

alter table public.coach_weekly_plans enable row level security;

create policy "Users can select their own coach weekly plans" on public.coach_weekly_plans for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert their own coach weekly plans" on public.coach_weekly_plans for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their own coach weekly plans" on public.coach_weekly_plans for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own coach weekly plans" on public.coach_weekly_plans for delete to authenticated using ((select auth.uid()) = user_id);

create or replace function public.save_coach_weekly_plan(
  p_week_start date, p_week_end date, p_short_retrospective text,
  p_biggest_win text, p_main_limiting_factor text, p_mission_type text,
  p_mission_title text, p_mission_reason text, p_action_items jsonb,
  p_motivation_context text, p_previous_mission_title text,
  p_previous_mission_outcome text, p_follow_up_message text,
  p_wearable_days integer, p_workout_source_available boolean,
  p_evidence jsonb, p_generated_at timestamptz
)
returns setof public.coach_weekly_plans
language plpgsql security invoker set search_path = ''
as $$
begin
  if p_mission_type not in ('protect_recovery', 'improve_training_night_sleep', 'improve_workout_consistency', 'reduce_activity_load', 'maintain_successful_behavior') then raise exception 'Invalid weekly mission type'; end if;
  if p_previous_mission_outcome not in ('success', 'partial_improvement', 'unchanged', 'insufficient_data') then raise exception 'Invalid weekly mission outcome'; end if;
  return query
  insert into public.coach_weekly_plans (
    user_id, week_start, week_end, short_retrospective, biggest_win,
    main_limiting_factor, mission_type, mission_title, mission_reason,
    action_items, motivation_context, previous_mission_title,
    previous_mission_outcome, follow_up_message, wearable_days,
    workout_source_available, evidence, generated_at
  ) values (
    (select auth.uid()), p_week_start, p_week_end, p_short_retrospective,
    p_biggest_win, p_main_limiting_factor, p_mission_type, p_mission_title,
    p_mission_reason, p_action_items, p_motivation_context,
    p_previous_mission_title, p_previous_mission_outcome,
    p_follow_up_message, p_wearable_days, p_workout_source_available,
    p_evidence, p_generated_at
  ) on conflict (user_id, week_start) do update set
    week_end = excluded.week_end,
    short_retrospective = excluded.short_retrospective,
    biggest_win = excluded.biggest_win,
    main_limiting_factor = excluded.main_limiting_factor,
    mission_type = excluded.mission_type,
    mission_title = excluded.mission_title,
    mission_reason = excluded.mission_reason,
    action_items = excluded.action_items,
    motivation_context = excluded.motivation_context,
    previous_mission_title = excluded.previous_mission_title,
    previous_mission_outcome = excluded.previous_mission_outcome,
    follow_up_message = excluded.follow_up_message,
    wearable_days = excluded.wearable_days,
    workout_source_available = excluded.workout_source_available,
    evidence = excluded.evidence,
    generated_at = excluded.generated_at,
    updated_at = now()
  returning coach_weekly_plans.*;
end;
$$;

revoke all on function public.save_coach_weekly_plan(date,date,text,text,text,text,text,text,jsonb,text,text,text,text,integer,boolean,jsonb,timestamptz) from public, anon;
grant execute on function public.save_coach_weekly_plan(date,date,text,text,text,text,text,text,jsonb,text,text,text,text,integer,boolean,jsonb,timestamptz) to authenticated;
