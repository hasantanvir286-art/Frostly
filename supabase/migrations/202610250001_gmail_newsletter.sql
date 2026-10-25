-- Newsletter opt-out and idempotent public subscription.
alter table public.newsletter_subscriptions
  add column if not exists unsubscribe_token uuid not null default gen_random_uuid(),
  add column if not exists unsubscribed_at timestamptz;

create index if not exists newsletter_subscriptions_active_idx
  on public.newsletter_subscriptions(created_at)
  where unsubscribed_at is null;

create or replace function public.newsletter_subscribe(p_email text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
begin
  if v_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then
    raise exception 'Enter a valid email address';
  end if;

  insert into public.newsletter_subscriptions(email, consented_at, unsubscribed_at)
  values (v_email, now(), null)
  on conflict (email) do update
    set consented_at = excluded.consented_at,
        unsubscribed_at = null;
end;
$$;

revoke all on function public.newsletter_subscribe(text) from public;
grant execute on function public.newsletter_subscribe(text) to anon, authenticated;
revoke insert, select on public.newsletter_subscriptions from anon, authenticated;
