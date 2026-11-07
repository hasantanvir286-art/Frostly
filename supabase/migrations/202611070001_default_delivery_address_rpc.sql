-- Atomically mark one of the current customer's saved addresses as the default.
create or replace function public.set_default_delivery_address(p_address_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  -- Serialize default changes for a single customer to avoid overlapping writes.
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  if not exists (
    select 1 from public.addresses
    where id = p_address_id and user_id = v_user_id
  ) then
    raise exception 'Saved address not found' using errcode = 'P0002';
  end if;

  update public.addresses
  set is_default = false
  where user_id = v_user_id and is_default;

  update public.addresses
  set is_default = true
  where id = p_address_id and user_id = v_user_id;

  return true;
end;
$$;

revoke all on function public.set_default_delivery_address(uuid) from public, anon;
grant execute on function public.set_default_delivery_address(uuid) to authenticated;
