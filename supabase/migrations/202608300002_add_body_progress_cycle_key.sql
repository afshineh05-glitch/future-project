alter table public.body_progress_checks
  add column if not exists cycle_key text;

-- Preserve every existing row, including known legacy duplicates. New writes
-- use deterministic cycle keys; legacy rows receive unique compatibility keys.
update public.body_progress_checks
set cycle_key = 'legacy:' || id::text
where cycle_key is null;

alter table public.body_progress_checks
  alter column cycle_key set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'body_progress_checks_cycle_key_length_check'
      and conrelid = 'public.body_progress_checks'::regclass
  ) then
    alter table public.body_progress_checks
      add constraint body_progress_checks_cycle_key_length_check
      check (char_length(cycle_key) between 1 and 200);
  end if;
end;
$$;

create unique index if not exists body_progress_checks_user_cycle_key_uidx
  on public.body_progress_checks (user_id, cycle_key);
