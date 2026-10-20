-- Customer profile fields and self-service avatar uploads.
alter table public.profiles
  add column if not exists phone text not null default '',
  add column if not exists avatar_url text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('frostly-avatars', 'frostly-avatars', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists frostly_avatars_public_read on storage.objects;
drop policy if exists frostly_avatars_owner_read on storage.objects;
create policy frostly_avatars_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'frostly-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists frostly_avatars_owner_insert on storage.objects;
create policy frostly_avatars_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'frostly-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists frostly_avatars_owner_update on storage.objects;
create policy frostly_avatars_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'frostly-avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'frostly-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists frostly_avatars_owner_delete on storage.objects;
create policy frostly_avatars_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'frostly-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
