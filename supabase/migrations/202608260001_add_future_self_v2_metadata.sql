alter table public.vision_profiles
  add column if not exists future_self_input_mode text
    check (future_self_input_mode in ('face_only', 'full_body')),
  add column if not exists current_photo_input_mode text
    check (current_photo_input_mode in ('face_only', 'full_body')),
  add column if not exists future_self_generated_input_mode text
    check (future_self_generated_input_mode in ('face_only', 'full_body')),
  add column if not exists future_self_horizon_months integer
    check (future_self_horizon_months = 8),
  add column if not exists future_self_source_reference text,
  add column if not exists future_self_goal_used text;

update public.vision_profiles
set current_photo_input_mode = 'full_body'
where current_photo_path is not null and current_photo_input_mode is null;

update public.vision_profiles
set future_self_input_mode = 'full_body'
where (current_photo_path is not null or future_self_image_path is not null)
  and future_self_input_mode is null;

update public.vision_profiles
set future_self_generated_input_mode = 'full_body',
    future_self_horizon_months = 8,
    future_self_source_reference = coalesce(future_self_source_reference, current_photo_path),
    future_self_goal_used = coalesce(future_self_goal_used, primary_goal)
where future_self_image_path is not null;
