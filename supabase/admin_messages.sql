-- Run after leaderboard.sql to add optional player-facing balance messages.
alter table public.admin_actions add column if not exists message text not null default '';
alter table public.admin_actions add column if not exists acorns_delta double precision not null default 0;
alter table public.admin_actions add column if not exists rings_delta double precision not null default 0;
alter table public.admin_actions add column if not exists amber_delta double precision not null default 0;

drop function if exists public.player_pending_actions(uuid);
create function public.player_pending_actions(p_player_id uuid)
returns table(id uuid, action_type text, sap_delta double precision, resin_delta double precision, acorns_delta double precision, rings_delta double precision, amber_delta double precision, message text)
language sql security definer set search_path = '' as $$
  select a.id, a.action_type, a.sap_delta, a.resin_delta, a.acorns_delta, a.rings_delta, a.amber_delta, a.message
  from public.admin_actions a where a.player_id = p_player_id and a.acknowledged_at is null
  order by a.created_at limit 20;
$$;

drop function if exists public.admin_apply_action_with_message(uuid, text, double precision, double precision, text);
drop function if exists public.admin_apply_action_with_message(uuid, text, double precision, double precision, double precision, double precision, double precision, text);
create function public.admin_apply_action_with_message(
  p_player_id uuid, p_action_type text, p_sap_delta double precision,
  p_resin_delta double precision, p_acorns_delta double precision,
  p_rings_delta double precision, p_amber_delta double precision, p_message text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_player_id is null or p_action_type is distinct from 'balance'
    or p_sap_delta is null or p_resin_delta is null or p_acorns_delta is null
    or p_rings_delta is null or p_amber_delta is null
    or (p_sap_delta = 0 and p_resin_delta = 0 and p_acorns_delta = 0 and p_rings_delta = 0 and p_amber_delta = 0)
    or abs(p_sap_delta) > 1e100 or abs(p_resin_delta) > 1e100
    or abs(p_acorns_delta) > 1e100 or abs(p_rings_delta) > 1e100 or abs(p_amber_delta) > 1e100
    or length(coalesce(p_message, '')) > 500 then
    raise exception 'Invalid balance action';
  end if;
  insert into public.admin_actions (player_id, action_type, sap_delta, resin_delta, acorns_delta, rings_delta, amber_delta, message)
    values (p_player_id, 'balance', p_sap_delta, p_resin_delta, p_acorns_delta, p_rings_delta, p_amber_delta, coalesce(p_message, ''))
    returning id into new_id;
  return new_id;
end; $$;

revoke all on function public.player_pending_actions(uuid),
  public.admin_apply_action_with_message(uuid, text, double precision, double precision, double precision, double precision, double precision, text)
  from public, anon, authenticated;
grant execute on function public.player_pending_actions(uuid) to anon, authenticated;
grant execute on function public.admin_apply_action_with_message(uuid, text, double precision, double precision, double precision, double precision, double precision, text) to authenticated;
