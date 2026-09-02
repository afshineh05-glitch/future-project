do $$
declare
  deleted_count integer;
begin
  if not exists (
    select 1
    from public.body_progress_checks
    where id = '7ef231f3-17d1-4a13-bbba-b2f0a3f3a8b1'::uuid
      and weight = 78
      and waist = 88
      and chest = 110
      and hips = 100
      and arm = 39
      and thigh = 60
      and neck = 40
      and note = 'Test progress check'
      and checked_at = '2026-08-30T20:46:19.783608Z'::timestamptz
      and created_at = '2026-08-30T20:46:20.11769Z'::timestamptz
  ) then
    raise exception 'Preserved Body Progress check no longer matches inspection';
  end if;

  if not exists (
    select 1
    from public.body_progress_checks
    where id = '3e6f0ca9-578b-4d1b-8723-28aa0311df3b'::uuid
  ) then
    raise notice 'Known legacy Body Progress duplicate was already removed';
    return;
  end if;

  if not exists (
    select 1
    from public.body_progress_checks duplicate
    where duplicate.id = '3e6f0ca9-578b-4d1b-8723-28aa0311df3b'::uuid
      and duplicate.user_id = (
        select preserved.user_id
        from public.body_progress_checks preserved
        where preserved.id = '7ef231f3-17d1-4a13-bbba-b2f0a3f3a8b1'::uuid
      )
      and duplicate.weight = 78
      and duplicate.waist = 88
      and duplicate.chest = 111
      and duplicate.hips = 100
      and duplicate.arm = 39
      and duplicate.thigh = 60
      and duplicate.neck = 40
      and duplicate.note is null
      and duplicate.checked_at = '2026-08-30T20:45:47.848884Z'::timestamptz
      and duplicate.created_at = '2026-08-30T20:45:48.677448Z'::timestamptz
  ) then
    raise exception 'Legacy Body Progress duplicate no longer matches inspection';
  end if;

  delete from public.body_progress_checks
  where id = '3e6f0ca9-578b-4d1b-8723-28aa0311df3b'::uuid;

  get diagnostics deleted_count = row_count;
  if deleted_count <> 1 then
    raise exception 'Expected to delete one legacy Body Progress duplicate, deleted %', deleted_count;
  end if;
end;
$$;
