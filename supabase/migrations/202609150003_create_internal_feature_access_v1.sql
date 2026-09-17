-- Server-controlled internal feature access. No rows are inserted here:
-- public/default access remains disabled until an administrator grants a user.
create table if not exists public.internal_feature_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  feature_key text not null check (feature_key ~ '^[a-z][a-z0-9_]{1,63}$'),
  enabled boolean not null default false,
  granted_at timestamptz not null default now(),
  primary key (user_id, feature_key)
);

alter table public.internal_feature_access enable row level security;

create policy "Users can read their own internal feature access"
  on public.internal_feature_access for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.internal_feature_access from public, anon;
grant select on table public.internal_feature_access to authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.internal_feature_access from authenticated;

comment on table public.internal_feature_access is
  'Server/admin-managed feature access. Client users may read only their own rows; grants require a trusted admin path.';
