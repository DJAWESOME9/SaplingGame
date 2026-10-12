-- Run after leaderboard_daily_lightning.sql to report remaining strikes and
-- enforce a one-minute cooldown between player-sent leaderboard strikes.
create or replace function public.player_leaderboard_strike_status(p_player_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  boards text[] := array['lifetime_sap','lifetime_resin','highest_sap','highest_resin','production_sap','production_resin','gold_leaves'];
  score_columns text[] := array['lifetime_sap','lifetime_resin','current_sap','current_resin','current_sap_production','current_resin_production','gold_leaves'];
  available text[] := array[]::text[];
  latest_used timestamptz;
  today date := (now() at time zone 'America/New_York')::date;
  i integer;
  rank_position bigint;
begin
  if p_player_id is null then raise exception 'Player is unavailable'; end if;
  for i in 1..array_length(boards, 1) loop
    execute format(
      'select place from (select player_id, row_number() over (order by %I desc, player_id asc) as place from public.leaderboard where fresh_score_reported_at is not null) ranked where player_id = $1',
      score_columns[i]) into rank_position using p_player_id;
    if rank_position between 1 and 3 and not exists (
      select 1 from private.sapling_leaderboard_lightning_usage u
      where u.player_id = p_player_id and u.usage_day = today and u.board = boards[i]
    ) then
      available := array_append(available, boards[i]);
    end if;
    rank_position := null;
  end loop;
  select max(used_at) into latest_used
    from private.sapling_leaderboard_lightning_usage where player_id = p_player_id;
  return jsonb_build_object(
    'available_boards', available,
    'remaining', cardinality(available),
    'cooldown_seconds', greatest(0, ceil(extract(epoch from (latest_used + interval '1 minute' - clock_timestamp())))::integer)
  );
end; $$;
revoke all on function public.player_leaderboard_strike_status(uuid) from public;
grant execute on function public.player_leaderboard_strike_status(uuid) to anon, authenticated;

create or replace function public.player_leaderboard_strike(
  p_player_id uuid, p_target_id uuid, p_board text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  score_column text;
  attacker_name text;
  target_name text;
  rank_position bigint;
  action_id uuid;
  latest_used timestamptz;
  today date := (now() at time zone 'America/New_York')::date;
  status jsonb;
begin
  if p_player_id is null or p_target_id is null or p_player_id = p_target_id then
    raise exception 'Choose another player to strike';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_player_id::text, 0));
  select max(used_at) into latest_used
    from private.sapling_leaderboard_lightning_usage where player_id = p_player_id;
  if latest_used is not null and latest_used + interval '1 minute' > clock_timestamp() then
    raise exception 'Wait one minute between leaderboard strikes';
  end if;

  score_column := case p_board
    when 'lifetime_sap' then 'lifetime_sap'
    when 'lifetime_resin' then 'lifetime_resin'
    when 'highest_sap' then 'current_sap'
    when 'highest_resin' then 'current_resin'
    when 'production_sap' then 'current_sap_production'
    when 'production_resin' then 'current_resin_production'
    when 'gold_leaves' then 'gold_leaves'
    else null end;
  if score_column is null then raise exception 'Unknown leaderboard'; end if;

  execute format(
    'select place, display_name from (select player_id, display_name, row_number() over (order by %I desc, player_id asc) as place from public.leaderboard where fresh_score_reported_at is not null) ranked where player_id = $1',
    score_column)
    into rank_position, attacker_name using p_player_id;
  if rank_position is null or rank_position > 3 then
    raise exception 'Only the top three on this leaderboard can send a strike';
  end if;
  select display_name into target_name from public.leaderboard
    where player_id = p_target_id and fresh_score_reported_at is not null;
  if target_name is null then raise exception 'Target player is not on the leaderboard'; end if;

  insert into private.sapling_leaderboard_lightning_usage(player_id, usage_day, board, target_id)
    values (p_player_id, today, p_board, p_target_id)
    on conflict do nothing;
  if not found then raise exception 'Your strike for this leaderboard has already been used today'; end if;

  insert into public.admin_actions(player_id, action_type, weather_level, message)
    values (p_target_id, 'lightning', 1,
      format('Leaderboard strike by %s for #%s on %s', left(attacker_name,20), rank_position, p_board))
    returning id into action_id;
  status := public.player_leaderboard_strike_status(p_player_id);
  return status || jsonb_build_object('action_id', action_id, 'board', p_board);
end; $$;
revoke all on function public.player_leaderboard_strike(uuid, uuid, text) from public;
grant execute on function public.player_leaderboard_strike(uuid, uuid, text) to anon, authenticated;
notify pgrst, 'reload schema';
