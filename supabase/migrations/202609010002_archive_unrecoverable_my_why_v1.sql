create table if not exists public.my_why_legacy_archives (
  id uuid primary key default gen_random_uuid(),
  source_entry_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  encrypted_text_payload text,
  encrypted_text_nonce text,
  encrypted_text_mac text,
  voice_storage_path text,
  voice_encryption_nonce text,
  voice_encryption_mac text,
  voice_metadata jsonb,
  video_storage_path text,
  video_encryption_nonce text,
  video_encryption_mac text,
  video_metadata jsonb,
  encryption_version integer not null check (encryption_version = 1),
  source_created_at timestamptz not null,
  source_updated_at timestamptz not null,
  archived_at timestamptz not null default now()
);

alter table public.my_why_legacy_archives enable row level security;

create policy "Users read their own archived My Why"
on public.my_why_legacy_archives for select to authenticated
using (auth.uid() = user_id);

create or replace function public.archive_legacy_my_why_and_start_v2()
returns public.my_why_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  legacy public.my_why_entries;
  active public.my_why_entries;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select * into legacy
  from public.my_why_entries
  where user_id = current_user_id
  for update;

  if legacy.id is null or legacy.encryption_version <> 1 then
    raise exception 'An active legacy V1 My Why is required';
  end if;

  insert into public.my_why_legacy_archives (
    source_entry_id, user_id,
    encrypted_text_payload, encrypted_text_nonce, encrypted_text_mac,
    voice_storage_path, voice_encryption_nonce, voice_encryption_mac, voice_metadata,
    video_storage_path, video_encryption_nonce, video_encryption_mac, video_metadata,
    encryption_version, source_created_at, source_updated_at
  ) values (
    legacy.id, legacy.user_id,
    legacy.encrypted_text_payload, legacy.encrypted_text_nonce, legacy.encrypted_text_mac,
    legacy.voice_storage_path, legacy.voice_encryption_nonce, legacy.voice_encryption_mac, legacy.voice_metadata,
    legacy.video_storage_path, legacy.video_encryption_nonce, legacy.video_encryption_mac, legacy.video_metadata,
    legacy.encryption_version, legacy.created_at, legacy.updated_at
  ) on conflict (source_entry_id) do nothing;

  update public.my_why_entries set
    encrypted_text_payload = null,
    encrypted_text_nonce = null,
    encrypted_text_mac = null,
    voice_storage_path = null,
    voice_encryption_nonce = null,
    voice_encryption_mac = null,
    voice_metadata = null,
    video_storage_path = null,
    video_encryption_nonce = null,
    video_encryption_mac = null,
    video_metadata = null,
    encryption_version = 2,
    updated_at = now()
  where id = legacy.id
  returning * into active;

  return active;
end;
$$;

revoke all on function public.archive_legacy_my_why_and_start_v2() from public;
grant execute on function public.archive_legacy_my_why_and_start_v2() to authenticated;

comment on table public.my_why_legacy_archives is
  'Immutable preservation of unrecoverable V1 My Why ciphertext and encrypted-media metadata when a user explicitly starts fresh with V2.';
