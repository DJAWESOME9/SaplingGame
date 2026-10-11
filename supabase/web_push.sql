-- Optional web-push subscriptions. Run in Supabase SQL Editor.
create table if not exists public.web_push_subscriptions (
  endpoint_hash text primary key check (length(endpoint_hash) = 64),
  player_id uuid not null,
  endpoint text not null,
  subscription jsonb not null check (jsonb_typeof(subscription) = 'object'),
  updated_at timestamptz not null default now()
);
create index if not exists web_push_subscriptions_player_idx on public.web_push_subscriptions(player_id);
alter table public.web_push_subscriptions enable row level security;
revoke all on public.web_push_subscriptions from public, anon, authenticated;

create or replace function public.store_web_push_subscription(p_player_id uuid, p_endpoint text, p_subscription jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_player_id is null or p_endpoint is null or length(p_endpoint) > 4096
     or jsonb_typeof(p_subscription) <> 'object'
     or p_subscription->>'endpoint' is distinct from p_endpoint
     or length(coalesce(p_subscription#>>'{keys,p256dh}','')) < 20
     or length(coalesce(p_subscription#>>'{keys,auth}','')) < 10 then
    raise exception 'Invalid push subscription';
  end if;
  insert into public.web_push_subscriptions(endpoint_hash, player_id, endpoint, subscription)
  values (encode(extensions.digest(convert_to(p_endpoint, 'UTF8'), 'sha256'), 'hex'), p_player_id, p_endpoint, p_subscription)
  on conflict (endpoint_hash) do update set player_id = excluded.player_id, endpoint = excluded.endpoint,
    subscription = excluded.subscription, updated_at = now();
end;
$$;
revoke all on function public.store_web_push_subscription(uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.store_web_push_subscription(uuid,text,jsonb) to service_role;

create or replace function public.delete_web_push_subscription(p_player_id uuid, p_endpoint text)
returns void language sql security definer set search_path = '' as $$
  delete from public.web_push_subscriptions where player_id = p_player_id and endpoint = p_endpoint;
$$;
revoke all on function public.delete_web_push_subscription(uuid,text) from public, anon, authenticated;
grant execute on function public.delete_web_push_subscription(uuid,text) to service_role;
