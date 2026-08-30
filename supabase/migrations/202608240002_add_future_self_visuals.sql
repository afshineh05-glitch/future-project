alter table public.vision_profiles
  add column if not exists current_photo_path text,
  add column if not exists future_self_image_path text,
  add column if not exists future_self_generated_at timestamptz;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'future-self-images',
  'future-self-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "Users read their future self images"
on storage.objects for select to authenticated
using (bucket_id = 'future-self-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users upload their future self images"
on storage.objects for insert to authenticated
with check (bucket_id = 'future-self-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users update their future self images"
on storage.objects for update to authenticated
using (bucket_id = 'future-self-images' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'future-self-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users delete their future self images"
on storage.objects for delete to authenticated
using (bucket_id = 'future-self-images' and (storage.foldername(name))[1] = auth.uid()::text);
