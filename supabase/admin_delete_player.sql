-- Run after leaderboard.sql to add or refresh the full-admin account deletion RPC.
-- Safe to rerun on existing installations.

create or replace function public.admin_delete_player(p_player_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player account not found';
  end if;
  insert into public.deleted_players (player_id) values (p_player_id) on conflict do nothing;
  delete from public.admin_actions where player_id = p_player_id;
  insert into public.admin_actions (player_id, action_type) values (p_player_id, 'delete');
  if to_regclass('public.live_challenge_completions') is not null then
    execute 'delete from public.live_challenge_completions where player_id = $1' using p_player_id;
  end if;
  delete from public.leaderboard_names where player_id = p_player_id;
  delete from public.leaderboard where player_id = p_player_id;
  delete from public.player_profiles where player_id = p_player_id;
end; $$;

revoke all on function public.admin_delete_player(uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_player(uuid) to authenticated;

notify pgrst, 'reload schema';
