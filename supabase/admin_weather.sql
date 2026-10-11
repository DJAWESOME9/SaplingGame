-- Run after leaderboard.sql (safe to rerun on existing installations).
-- Weather uses the existing private action queue and player claim/ack RPCs.
begin;
alter table public.admin_actions add column if not exists weather_level integer not null default 2 check (weather_level between 1 and 5);
alter table public.admin_actions drop constraint if exists admin_actions_action_type_check;
alter table public.admin_actions add constraint admin_actions_action_type_check
  check (action_type in ('balance', 'reset', 'delete', 'rain', 'lightning'));

drop function if exists public.admin_queue_weather(uuid, text, text);
create or replace function public.admin_queue_weather(
  p_player_id uuid, p_weather text, p_message text default '', p_level integer default 2
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_player_id is null or p_weather is null or p_weather not in ('rain', 'lightning')
    or p_level is null or p_level not between 1 and 5
    or length(coalesce(p_message, '')) > 500 then
    raise exception 'Invalid weather action';
  end if;
  if not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  insert into public.admin_actions (player_id, action_type, message, weather_level)
    values (p_player_id, p_weather, coalesce(p_message, ''), p_level) returning id into new_id;
  return new_id;
end; $$;
revoke all on function public.admin_queue_weather(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.admin_queue_weather(uuid, text, text, integer) to authenticated;

drop function if exists public.player_pending_actions(uuid);
create function public.player_pending_actions(p_player_id uuid)
returns table(id uuid, action_type text, sap_delta double precision, resin_delta double precision, acorns_delta double precision, rings_delta double precision, amber_delta double precision, message text, weather_level integer)
language sql security definer set search_path = '' as $$
  select a.id, a.action_type, a.sap_delta, a.resin_delta, a.acorns_delta, a.rings_delta, a.amber_delta, a.message, a.weather_level
  from public.admin_actions a where a.player_id = p_player_id and a.acknowledged_at is null
  order by a.created_at limit 20;
$$;
revoke all on function public.player_pending_actions(uuid) from public, anon, authenticated;
grant execute on function public.player_pending_actions(uuid) to anon, authenticated;
commit;
