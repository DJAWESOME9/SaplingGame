-- Run after leaderboard.sql and cloud_saves.sql. Browser UUIDs remain the
-- legacy profile credential; linking requires a verified account session.
create schema if not exists private;
create table if not exists private.sapling_account_players (
  user_id uuid primary key references auth.users(id) on delete cascade,
  player_id uuid not null unique
);
create table if not exists private.sapling_account_devices (
  player_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade
);
alter table private.sapling_account_players enable row level security;
alter table private.sapling_account_devices enable row level security;
revoke all on private.sapling_account_players, private.sapling_account_devices from public, anon, authenticated;

-- Keep historical device records, including quests and admin actions, intact.
-- Old clients cannot make a linked duplicate reappear in the public rankings.
create or replace function private.sapling_hide_linked_score()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from private.sapling_account_devices d
    join private.sapling_account_players a using (user_id)
    where d.player_id = new.player_id and a.player_id <> new.player_id) then
    new.fresh_score_reported_at := null;
  elsif tg_op = 'UPDATE' and new.fresh_score_reported_at is not null
    and exists (select 1 from private.sapling_account_players where player_id = new.player_id) then
    new.lifetime_sap := greatest(old.lifetime_sap, new.lifetime_sap);
    new.lifetime_resin := greatest(old.lifetime_resin, new.lifetime_resin);
    new.gold_leaves := greatest(old.gold_leaves, new.gold_leaves);
  end if;
  return new;
end; $$;
revoke all on function private.sapling_hide_linked_score() from public, anon, authenticated;
drop trigger if exists sapling_hide_linked_score on public.leaderboard;
create trigger sapling_hide_linked_score before insert or update on public.leaderboard
for each row execute function private.sapling_hide_linked_score();

-- Definer access is needed only for private identity mapping and existing
-- server-owned name/score records. Never accept a caller-supplied account ID.
create or replace function public.link_account_leaderboard(p_device_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  canonical uuid;
  owner_id uuid;
  username text;
begin
  if uid is null then raise exception 'Sign in required'; end if;
  if p_device_id is null then raise exception 'Device ID required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  insert into private.sapling_account_devices(player_id, user_id)
    values (p_device_id, uid) on conflict (player_id) do nothing;
  select user_id into owner_id from private.sapling_account_devices where player_id = p_device_id;
  if owner_id <> uid then raise exception 'This browser profile is linked to another account'; end if;
  if exists (select 1 from public.deleted_players where player_id = p_device_id) then
    raise exception 'Player profile deleted';
  end if;
  insert into private.sapling_account_players(user_id, player_id)
    values (uid, p_device_id) on conflict (user_id) do nothing;
  select player_id into canonical from private.sapling_account_players where user_id = uid;
  if exists (select 1 from public.deleted_players where player_id = canonical) then
    raise exception 'Player profile deleted';
  end if;
  if canonical <> p_device_id then
    insert into public.leaderboard(player_id, display_name)
      select canonical, display_name from public.leaderboard where player_id = p_device_id
      on conflict (player_id) do nothing;
    -- Preserve personal records without double-counting synchronized progress.
    update public.leaderboard c set
      lifetime_sap = greatest(c.lifetime_sap, d.lifetime_sap),
      lifetime_resin = greatest(c.lifetime_resin, d.lifetime_resin),
      highest_sap = greatest(c.highest_sap, d.highest_sap),
      highest_resin = greatest(c.highest_resin, d.highest_resin),
      highest_held_sap = greatest(c.highest_held_sap, d.highest_held_sap),
      highest_held_resin = greatest(c.highest_held_resin, d.highest_held_resin),
      production_sap = greatest(c.production_sap, d.production_sap),
      production_resin = greatest(c.production_resin, d.production_resin),
      gold_leaves = greatest(c.gold_leaves, d.gold_leaves)
      from public.leaderboard d where c.player_id = canonical and d.player_id = p_device_id;
    update public.leaderboard set fresh_score_reported_at = null where player_id = p_device_id;
    if not exists (select 1 from public.leaderboard_names where player_id = canonical) then
      update public.leaderboard_names set player_id = canonical where player_id = p_device_id;
    end if;
  end if;
  select display_name into username from public.leaderboard_names where player_id = canonical;
  return jsonb_build_object('player_id', canonical, 'display_name', username);
end; $$;
revoke all on function public.link_account_leaderboard(uuid) from public, anon;
grant execute on function public.link_account_leaderboard(uuid) to authenticated;
