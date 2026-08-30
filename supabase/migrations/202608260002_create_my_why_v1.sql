create table if not exists public.my_why_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
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
  encryption_version integer not null default 1 check (encryption_version = 1),
  has_text boolean generated always as (encrypted_text_payload is not null) stored,
  has_voice boolean generated always as (voice_storage_path is not null) stored,
  has_video boolean generated always as (video_storage_path is not null) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint my_why_text_envelope_complete check (
    (encrypted_text_payload is null and encrypted_text_nonce is null and encrypted_text_mac is null)
    or
    (encrypted_text_payload is not null and encrypted_text_nonce is not null and encrypted_text_mac is not null)
  ),
  constraint my_why_voice_envelope_complete check (
    (voice_storage_path is null and voice_encryption_nonce is null and voice_encryption_mac is null and voice_metadata is null)
    or
    (voice_storage_path is not null and voice_encryption_nonce is not null and voice_encryption_mac is not null and voice_metadata is not null)
  ),
  constraint my_why_video_envelope_complete check (
    (video_storage_path is null and video_encryption_nonce is null and video_encryption_mac is null and video_metadata is null)
    or
    (video_storage_path is not null and video_encryption_nonce is not null and video_encryption_mac is not null and video_metadata is not null)
  )
);

alter table public.my_why_entries enable row level security;

create policy "Users select their own My Why"
on public.my_why_entries for select to authenticated
using (auth.uid() = user_id);

create policy "Users insert their own My Why"
on public.my_why_entries for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users update their own My Why"
on public.my_why_entries for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users delete their own My Why"
on public.my_why_entries for delete to authenticated
using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'my-why-private',
  'my-why-private',
  false,
  104857616,
  array['application/octet-stream']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Users read their own encrypted My Why media"
on storage.objects for select to authenticated
using (
  bucket_id = 'my-why-private'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] in ('voice', 'video')
);

create policy "Users upload their own encrypted My Why media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'my-why-private'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] in ('voice', 'video')
);

create policy "Users delete their own encrypted My Why media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'my-why-private'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] in ('voice', 'video')
);

comment on table public.my_why_entries is
  'Client-encrypted private journal content. No plaintext or raw key is stored. Service-role access bypasses RLS and is not end-to-end privacy.';
