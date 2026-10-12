-- Apply after leaderboard.sql and admin_weather.sql.
-- Replaces the old automatic winner-targeting job with one player-aimed strike
-- per current top-three placement, per Eastern calendar day.
create schema if not exists private;
create table if not exists private.sapling_leaderboard_lightning_usage (
  player_id uuid not null,
  usage_day date not null,
  board text not null check (board in ('lifetime_sap','lifetime_resin','highest_sap','highest_resin','production_sap','production_resin','gold_leaves')),
  target_id uuid not null,
  used_at timestamptz not null default now(),
  primary key (player_id, usage_day, board),
  check (player_id <> target_id)
);
alter table private.sapling_leaderboard_lightning_usage enable row level security;
revoke all on private.sapling_leaderboard_lightning_usage from public, anon, authenticated;

-- Stop the previously installed midnight job. Its historical day ledger may remain.
do $$
declare scheduled_job record;
begin
  if to_regclass('cron.job') is not null then
    for scheduled_job in select jobid from cron.job where jobname = 'sapling-leaderboard-daily-lightning' loop
      perform cron.unschedule(scheduled_job.jobid);
    end loop;
  end if;
end; $$;
drop function if exists private.queue_leaderboard_daily_lightning();
-- Do not deliver automatic winner strikes already waiting in the shared queue.
delete from public.admin_actions
  where action_type = 'lightning' and acknowledged_at is null
    and message like 'Daily leaderboard lightning:%';

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
  today date := (now() at time zone 'America/New_York')::date;
begin
  if p_player_id is null or p_target_id is null or p_player_id = p_target_id then
    raise exception 'Choose another player to strike';
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
    'select place, display_name from (
       select player_id, display_name, row_number() over (order by %I desc, player_id asc) as place
       from public.leaderboard where fresh_score_reported_at is not null
     ) ranked where player_id = $1', score_column)
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
  return jsonb_build_object('action_id', action_id, 'remaining', 0, 'board', p_board);
end; $$;
revoke all on function public.player_leaderboard_strike(uuid, uuid, text) from public;
grant execute on function public.player_leaderboard_strike(uuid, uuid, text) to anon, authenticated;
notify pgrst, 'reload schema';
