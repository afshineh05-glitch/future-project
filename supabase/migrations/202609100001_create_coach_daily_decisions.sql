create table if not exists public.coach_daily_decisions (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  decision text not null check (decision in ('planned_session', 'lighter_session')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, local_date)
);

alter table public.coach_daily_decisions enable row level security;

create policy "Users can select their own coach daily decisions"
  on public.coach_daily_decisions for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own coach daily decisions"
  on public.coach_daily_decisions for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own coach daily decisions"
  on public.coach_daily_decisions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own coach daily decisions"
  on public.coach_daily_decisions for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.save_coach_daily_decision(
  p_local_date date,
  p_decision text
)
returns setof public.coach_daily_decisions
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_decision not in ('planned_session', 'lighter_session') then
    raise exception 'Invalid coach daily decision';
  end if;

  return query
  insert into public.coach_daily_decisions (user_id, local_date, decision)
  values ((select auth.uid()), p_local_date, p_decision)
  on conflict (user_id, local_date) do update set
    decision = excluded.decision,
    updated_at = now()
  returning coach_daily_decisions.*;
end;
$$;

revoke all on function public.save_coach_daily_decision(date, text)
  from public, anon;
grant execute on function public.save_coach_daily_decision(date, text)
  to authenticated;
