-- Allow superadmins to delete customer-only accounts through a guarded RPC.
-- Customers with order history are kept so order records remain attributable.

create or replace function public.superadmin_delete_customer(p_user_id uuid)
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
    raise exception 'Customer account is required';
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
  if v_role <> 'customer' then
    raise exception 'Only customer accounts can be deleted here';
  end if;
  if exists (select 1 from public.orders where user_id = p_user_id) then
    raise exception 'This customer has order history. Change the account role or retain it instead of deleting it.';
  end if;

  insert into public.admin_audit_logs(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'customer_account_deleted', 'profile', p_user_id,
          jsonb_build_object('email', v_email));

  delete from auth.users where id = p_user_id;
  if not found then
    raise exception 'Account was not deleted';
  end if;
end;
$$;

revoke all on function public.superadmin_delete_customer(uuid) from public, anon;
grant execute on function public.superadmin_delete_customer(uuid) to authenticated;
