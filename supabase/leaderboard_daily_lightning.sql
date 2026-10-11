-- Apply after leaderboard.sql and admin_weather.sql. Runs only as database owner.
create schema if not exists private;
create extension if not exists pg_cron;

create table if not exists private.sapling_leaderboard_lightning_days (
  strike_day date primary key,
  queued_at timestamptz not null default now(),
  strikes integer not null default 0
);
alter table private.sapling_leaderboard_lightning_days enable row level security;
revoke all on private.sapling_leaderboard_lightning_days from public, anon, authenticated;

create or replace function private.queue_leaderboard_daily_lightning()
returns integer language plpgsql security invoker set search_path = '' as $$
declare
  today date := (now() at time zone 'America/New_York')::date;
  claimed date;
  queued integer;
begin
  -- One snapshot per Eastern date; concurrent calls serialize on the daily key.
  -- This marker and all queued strikes commit together or roll back together.
  insert into private.sapling_leaderboard_lightning_days(strike_day)
    values (today) on conflict do nothing returning strike_day into claimed;
  if claimed is null then return 0; end if;

  with scores as (
    select l.player_id, b.board, b.label, b.score
    from public.leaderboard l
    cross join lateral (values
      ('lifetime_sap', 'Lifetime sap', l.lifetime_sap),
      ('lifetime_resin', 'Lifetime resin', l.lifetime_resin),
      ('production_sap', 'Sap production', l.current_sap_production),
      ('production_resin', 'Resin production', l.current_resin_production),
      ('highest_sap', 'Current sap', l.current_sap),
      ('highest_resin', 'Current resin', l.current_resin),
      ('gold_leaves', 'Gold leaves', l.gold_leaves::double precision)
    ) b(board, label, score)
    where l.fresh_score_reported_at is not null
  ), ranked as (
    select *, row_number() over (partition by board order by score desc, player_id) as place
    from scores
  )
  insert into public.admin_actions(player_id, action_type, weather_level, message)
    select player_id, 'lightning', 1,
      format('Daily leaderboard lightning: #%s in %s on %s (Eastern). One strike per top-three placement.', place, label, today)
    from ranked where place <= 3 order by board, place;
  get diagnostics queued = row_count;
  update private.sapling_leaderboard_lightning_days set strikes = queued where strike_day = today;
  return queued;
end; $$;
revoke all on function private.queue_leaderboard_daily_lightning() from public, anon, authenticated;

-- Midnight Eastern is 04:00 UTC in summer and 05:00 UTC in winter.
-- The Eastern-hour guard handles daylight saving without a second daily run.
select cron.schedule('sapling-leaderboard-daily-lightning', '0 4,5 * * *',
  $$select private.queue_leaderboard_daily_lightning()
    where extract(hour from now() at time zone 'America/New_York') = 0;$$);
