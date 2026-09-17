create table if not exists public.user_shopping_areas (
  user_id uuid primary key references auth.users(id) on delete cascade,
  approximate_latitude numeric null check (approximate_latitude between -90 and 90),
  approximate_longitude numeric null check (approximate_longitude between -180 and 180),
  city text null,
  postal_code text null check (postal_code is null or postal_code ~ '^[ABCEGHJKLMNPRSTVXY][0-9][ABCEGHJKLMNPRSTVWXYZ] [0-9][ABCEGHJKLMNPRSTVWXYZ][0-9]$'),
  radius_km numeric not null default 15 check (radius_km in (2, 5, 10, 15, 25)),
  updated_at timestamptz not null default now(),
  check (
    (approximate_latitude is not null and approximate_longitude is not null)
    or nullif(trim(postal_code), '') is not null
  )
);

alter table public.user_shopping_areas enable row level security;

create policy "Users can read their own shopping area"
  on public.user_shopping_areas for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert their own shopping area"
  on public.user_shopping_areas for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their own shopping area"
  on public.user_shopping_areas for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own shopping area"
  on public.user_shopping_areas for delete to authenticated using ((select auth.uid()) = user_id);

comment on table public.user_shopping_areas is
  'Minimal user-controlled shopping area for nearby grocery search; not for advertising profiles or background tracking.';

create table if not exists public.grocery_search_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0 check (request_count >= 0)
);

alter table public.grocery_search_rate_limits enable row level security;
revoke all on public.grocery_search_rate_limits from anon, authenticated;

create or replace function public.claim_grocery_search_request()
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := (select auth.uid());
  accepted boolean := false;
begin
  if caller_id is null then
    return false;
  end if;

  insert into public.grocery_search_rate_limits as limits (
    user_id,
    window_started_at,
    request_count
  ) values (
    caller_id,
    now(),
    1
  )
  on conflict (user_id) do update
  set
    window_started_at = case
      when limits.window_started_at < now() - interval '5 minutes' then now()
      else limits.window_started_at
    end,
    request_count = case
      when limits.window_started_at < now() - interval '5 minutes' then 1
      else limits.request_count + 1
    end
  where
    limits.window_started_at < now() - interval '5 minutes'
    or limits.request_count < 20
  returning true into accepted;

  return coalesce(accepted, false);
end;
$$;

revoke all on function public.claim_grocery_search_request() from public, anon;
grant execute on function public.claim_grocery_search_request() to authenticated;
