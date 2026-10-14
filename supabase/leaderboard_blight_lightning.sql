-- Upgrade existing leaderboard strike usage to support a second Blight strike
-- for each top-three placement. Run this migration, then rerun
-- leaderboard_strike_cooldown.sql to install the updated status and strike RPCs.
alter table private.sapling_leaderboard_lightning_usage
  add column if not exists strike_number smallint not null default 1
  check (strike_number between 1 and 2);

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'private.sapling_leaderboard_lightning_usage'::regclass
      and conname = 'sapling_leaderboard_lightning_usage_pkey'
  ) then
    alter table private.sapling_leaderboard_lightning_usage
      drop constraint sapling_leaderboard_lightning_usage_pkey;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'private.sapling_leaderboard_lightning_usage'::regclass
      and conname = 'sapling_leaderboard_lightning_usage_pkey'
  ) then
    alter table private.sapling_leaderboard_lightning_usage
      add constraint sapling_leaderboard_lightning_usage_pkey
      primary key (player_id, usage_day, board, strike_number);
  end if;
end; $$;

notify pgrst, 'reload schema';
