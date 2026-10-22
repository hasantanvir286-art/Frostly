-- Permit deletion of non-superadmin staff accounts only when their history is unreferenced.
-- Operational and audit rows stay intact; accounts tied to them must be retained.

create or replace function public.superadmin_delete_staff(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role text;
  v_email text;
begin
  if not public.is_frostly_superadmin() then
    raise exception 'Superadmin access required';
  end if;
  if p_user_id is null then
    raise exception 'Staff account is required';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot delete your own account';
  end if;

  select p.role, u.email::text
    into v_role, v_email
    from public.profiles p
    join auth.users u on u.id = p.id
   where p.id = p_user_id
   for update of p;
  if not found then
    raise exception 'Account not found';
  end if;
  if v_role in ('customer', 'superadmin') then
    raise exception 'Only non-superadmin staff accounts can be deleted here';
  end if;

  if exists (select 1 from public.orders where user_id = p_user_id)
     or exists (select 1 from public.delivery_assignments where staff_user_id = p_user_id or assigned_by = p_user_id)
     or exists (select 1 from public.inventory_movements where changed_by = p_user_id)
     or exists (select 1 from public.order_status_history where changed_by = p_user_id)
     or exists (select 1 from public.admin_audit_logs where actor_id = p_user_id)
     or exists (select 1 from public.site_settings where updated_by = p_user_id) then
    raise exception 'This account has linked order, operational, or audit history and cannot be deleted';
  end if;

  insert into public.admin_audit_logs(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'staff_account_deleted', 'profile', p_user_id,
          jsonb_build_object('email', v_email, 'role', v_role));

  delete from auth.users where id = p_user_id;
  if not found then
    raise exception 'Account was not deleted';
  end if;
end;
$$;

revoke all on function public.superadmin_delete_staff(uuid) from public, anon;
grant execute on function public.superadmin_delete_staff(uuid) to authenticated;
