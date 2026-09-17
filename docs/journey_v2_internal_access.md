# Journey V2 internal access

Journey V2 is disabled unless the authenticated user has an explicit server-side
grant. The migration intentionally inserts no access rows.

To grant the project owner access, run this statement through a trusted
Supabase SQL editor or service-role/admin path, replacing the value with the
owner's authenticated `auth.users.id`:

```sql
insert into public.internal_feature_access (user_id, feature_key, enabled)
values ('OWNER_AUTH_USER_ID', 'journey_v2', true)
on conflict (user_id, feature_key) do update
set enabled = excluded.enabled, granted_at = now();
```

Do not run this from the client. Authenticated users can read only their own
effective row and cannot insert, update, or delete access.

For local development only, explicitly launch Flutter with:

```text
flutter run --dart-define=ENABLE_JOURNEY_V2=true
```

The override is honored only in debug mode. A normal build without the define
remains disabled unless the server grant exists; defining it cannot enable a
release build by accident. Daily Reflection V2 and Evidence Wall are not part
of Journey V2.
