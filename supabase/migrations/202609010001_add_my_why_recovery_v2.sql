alter table public.my_why_entries
  drop constraint if exists my_why_entries_encryption_version_check;

alter table public.my_why_entries
  add constraint my_why_entries_encryption_version_check
  check (encryption_version in (1, 2));

create table if not exists public.my_why_key_envelopes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  wrapped_key_ciphertext text not null,
  wrapped_key_nonce text not null,
  wrapped_key_mac text not null,
  wrapping_version integer not null default 1 check (wrapping_version = 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint my_why_wrapped_key_envelope_complete check (
    char_length(wrapped_key_ciphertext) > 0
    and char_length(wrapped_key_nonce) > 0
    and char_length(wrapped_key_mac) > 0
  )
);

alter table public.my_why_key_envelopes enable row level security;

create policy "Users read their own My Why recovery envelope"
on public.my_why_key_envelopes for select to authenticated
using (auth.uid() = user_id);

comment on table public.my_why_key_envelopes is
  'Contains only AES-GCM-wrapped My Why data keys. Raw keys are never stored in Postgres.';
