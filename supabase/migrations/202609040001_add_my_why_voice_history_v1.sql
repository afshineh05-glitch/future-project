create table if not exists public.my_why_voice_recordings (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.my_why_entries(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  encryption_nonce text not null,
  encryption_mac text not null,
  metadata jsonb not null,
  encryption_version integer not null check (encryption_version in (1, 2)),
  created_at timestamptz not null default now()
);

alter table public.my_why_voice_recordings enable row level security;

create policy "Users select their own My Why voice recordings"
on public.my_why_voice_recordings for select to authenticated
using (auth.uid() = user_id);

create policy "Users insert their own My Why voice recordings"
on public.my_why_voice_recordings for insert to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.my_why_entries
    where id = entry_id and user_id = auth.uid()
  )
);

create policy "Users delete their own My Why voice recordings"
on public.my_why_voice_recordings for delete to authenticated
using (auth.uid() = user_id);

alter table public.my_why_entries
  add column if not exists has_voice_history boolean not null default false;

alter table public.my_why_entries drop column if exists has_voice;

alter table public.my_why_entries
  add column has_voice boolean generated always as (
    voice_storage_path is not null or has_voice_history
  ) stored;

create or replace function public.sync_my_why_voice_history_flag()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  target_entry_id uuid;
begin
  if tg_op = 'DELETE' then
    target_entry_id := old.entry_id;
  else
    target_entry_id := new.entry_id;
  end if;
  update public.my_why_entries
  set has_voice_history = exists (
    select 1 from public.my_why_voice_recordings
    where entry_id = target_entry_id
  ), updated_at = now()
  where id = target_entry_id;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger sync_my_why_voice_history_after_insert
after insert on public.my_why_voice_recordings
for each row execute function public.sync_my_why_voice_history_flag();

create trigger sync_my_why_voice_history_after_delete
after delete on public.my_why_voice_recordings
for each row execute function public.sync_my_why_voice_history_flag();

comment on table public.my_why_voice_recordings is
  'Owner-only metadata for independently AES-256-GCM encrypted My Why voice objects. Existing single voices remain on my_why_entries.';
