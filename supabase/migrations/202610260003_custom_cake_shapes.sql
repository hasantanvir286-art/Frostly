-- Add selectable cake shapes and server-calculated shape surcharges.
alter table public.cake_requests
  add column if not exists shape_key text not null default 'round'
  check (shape_key in ('round','square','heart','tiered'));

update public.site_settings
set cake_builder = cake_builder || jsonb_build_object(
  'shape_surcharges', coalesce(cake_builder->'shape_surcharges', '{"round":0,"square":0,"heart":0,"tiered":0}'::jsonb)
)
where id = 'main';

-- Replace the earlier RPC so the selected shape and its price are validated on the server.
drop function if exists public.submit_cake_request(uuid,text,text,text,text,text,text,text);

create or replace function public.submit_cake_request(
  p_request_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_design_key text,
  p_size_key text,
  p_flavor_key text,
  p_icing_color text,
  p_shape_key text,
  p_message_text text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_config jsonb;
  v_size_price integer;
  v_flavor_surcharge integer;
  v_design_surcharge integer;
  v_shape_surcharge integer;
  v_total integer;
  v_request uuid;
begin
  if v_user is null then raise exception 'Sign in before requesting a custom cake'; end if;
  if p_request_id is null then raise exception 'Invalid request reference'; end if;
  if p_design_key not in ('classic','floral','drip','celebration') then raise exception 'Choose a valid cake design'; end if;
  if p_size_key not in ('half_kg','one_kg','two_kg') then raise exception 'Choose a valid cake size'; end if;
  if p_flavor_key not in ('vanilla','chocolate','strawberry','red_velvet') then raise exception 'Choose a valid cake flavor'; end if;
  if p_icing_color not in ('ivory','pink','blue','mint','lavender','chocolate') then raise exception 'Choose a valid icing color'; end if;
  if p_shape_key not in ('round','square','heart','tiered') then raise exception 'Choose a valid cake shape'; end if;
  if length(btrim(coalesce(p_message_text,''))) > 60 then raise exception 'Cake message must be 60 characters or fewer'; end if;
  if length(btrim(coalesce(p_customer_name,''))) not between 2 and 100 then raise exception 'Enter a valid customer name'; end if;
  if coalesce(p_customer_phone,'') !~ '^(\+?88)?01[3-9][0-9]{8}$' then raise exception 'Enter a valid Bangladesh phone number'; end if;

  select cake_builder into v_config from public.site_settings where id = 'main';
  if not coalesce((v_config->>'enabled')::boolean, false) then raise exception 'Custom cake requests are not enabled yet'; end if;
  v_size_price := nullif(v_config->'size_prices'->>p_size_key,'')::integer;
  v_flavor_surcharge := coalesce(nullif(v_config->'flavor_surcharges'->>p_flavor_key,'')::integer,0);
  v_design_surcharge := coalesce(nullif(v_config->'design_surcharges'->>p_design_key,'')::integer,0);
  v_shape_surcharge := coalesce(nullif(v_config->'shape_surcharges'->>p_shape_key,'')::integer,0);
  if coalesce(v_size_price,0) <= 0 then raise exception 'The selected cake size is not priced yet'; end if;
  if v_flavor_surcharge < 0 or v_design_surcharge < 0 or v_shape_surcharge < 0 then raise exception 'Cake pricing is not configured correctly'; end if;
  v_total := v_size_price + v_flavor_surcharge + v_design_surcharge + v_shape_surcharge;

  insert into public.cake_requests(request_id,user_id,customer_name,customer_phone,design_key,size_key,flavor_key,icing_color,shape_key,message_text,estimated_total_bdt)
  values(p_request_id,v_user,btrim(p_customer_name),btrim(p_customer_phone),p_design_key,p_size_key,p_flavor_key,p_icing_color,p_shape_key,btrim(coalesce(p_message_text,'')),v_total)
  on conflict(user_id,request_id) do nothing returning id into v_request;
  if v_request is null then
    select id into v_request from public.cake_requests where user_id=v_user and request_id=p_request_id;
  end if;
  return v_request;
end;
$$;

revoke all on function public.submit_cake_request(uuid,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.submit_cake_request(uuid,text,text,text,text,text,text,text,text) to authenticated;
