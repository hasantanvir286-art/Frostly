-- Public product images with upload and mutation restricted to Frostly admins.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('frostly-products', 'frostly-products', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists frostly_products_public_read on storage.objects;
create policy frostly_products_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'frostly-products');

drop policy if exists frostly_products_admin_insert on storage.objects;
create policy frostly_products_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'frostly-products' and public.is_frostly_admin());

drop policy if exists frostly_products_admin_update on storage.objects;
create policy frostly_products_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'frostly-products' and public.is_frostly_admin())
  with check (bucket_id = 'frostly-products' and public.is_frostly_admin());

drop policy if exists frostly_products_admin_delete on storage.objects;
create policy frostly_products_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'frostly-products' and public.is_frostly_admin());
