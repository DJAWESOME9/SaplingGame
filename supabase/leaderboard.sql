-- Sapling leaderboard setup for a Supabase project.
-- Run this once in Supabase Dashboard → SQL Editor.

create table if not exists public.leaderboard (
  player_id uuid primary key,
  display_name text not null check (char_length(display_name) between 1 and 20),
  lifetime_sap double precision not null default 0 check (lifetime_sap >= 0),
  lifetime_resin double precision not null default 0 check (lifetime_resin >= 0),
  highest_sap double precision not null default 0 check (highest_sap >= 0),
  highest_resin double precision not null default 0 check (highest_resin >= 0),
  highest_held_sap double precision not null default 0 check (highest_held_sap >= 0),
  highest_held_resin double precision not null default 0 check (highest_held_resin >= 0),
  gold_leaves bigint not null default 0 check (gold_leaves >= 0),
  is_blight boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Additive migration for projects that ran an earlier leaderboard version.
alter table public.leaderboard add column if not exists lifetime_sap double precision not null default 0;
alter table public.leaderboard add column if not exists lifetime_resin double precision not null default 0;
alter table public.leaderboard add column if not exists highest_sap double precision not null default 0;
alter table public.leaderboard add column if not exists highest_resin double precision not null default 0;
alter table public.leaderboard add column if not exists highest_held_sap double precision not null default 0;
alter table public.leaderboard add column if not exists highest_held_resin double precision not null default 0;
alter table public.leaderboard add column if not exists gold_leaves bigint not null default 0;
alter table public.leaderboard add column if not exists trees_felled integer not null default 0;
alter table public.leaderboard add column if not exists total_rings bigint not null default 0;
alter table public.leaderboard add column if not exists is_blight boolean not null default false;

alter table public.leaderboard enable row level security;
revoke all on public.leaderboard from anon, authenticated;
grant select on public.leaderboard to anon, authenticated;

drop policy if exists "Leaderboard is public to read" on public.leaderboard;
create policy "Leaderboard is public to read"
  on public.leaderboard for select to anon, authenticated using (true);

drop function if exists public.submit_leaderboard_score(uuid, text, integer, bigint);
drop function if exists public.submit_leaderboard_score(uuid, text, double precision, double precision, double precision, double precision, bigint);
create or replace function public.submit_leaderboard_balance_score(
  p_player_id uuid,
  p_display_name text,
  p_lifetime_sap double precision,
  p_lifetime_resin double precision,
  p_highest_held_sap double precision,
  p_highest_held_resin double precision,
  p_gold_leaves bigint,
  p_is_blight boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_name text;
begin
  if p_player_id is null or p_lifetime_sap is null or p_lifetime_resin is null
     or p_highest_held_sap is null or p_highest_held_resin is null or p_gold_leaves is null
     or p_lifetime_sap < 0 or p_lifetime_resin < 0 or p_highest_held_sap < 0
     or p_highest_held_resin < 0 or p_gold_leaves < 0 or p_is_blight is null then
    raise exception 'Invalid score';
  end if;
  clean_name := left(regexp_replace(coalesce(p_display_name, ''), '[^[:alnum:] _.-]', '', 'g'), 20);
  if clean_name = '' then clean_name := 'Sapling'; end if;

  insert into public.leaderboard (
    player_id, display_name, lifetime_sap, lifetime_resin,
    highest_held_sap, highest_held_resin, gold_leaves, is_blight
  ) values (
    p_player_id, clean_name, p_lifetime_sap, p_lifetime_resin,
    p_highest_held_sap, p_highest_held_resin, p_gold_leaves, p_is_blight
  )
  on conflict (player_id) do update
    set display_name = excluded.display_name,
        lifetime_sap = greatest(public.leaderboard.lifetime_sap, excluded.lifetime_sap),
        lifetime_resin = greatest(public.leaderboard.lifetime_resin, excluded.lifetime_resin),
        highest_held_sap = greatest(public.leaderboard.highest_held_sap, excluded.highest_held_sap),
        highest_held_resin = greatest(public.leaderboard.highest_held_resin, excluded.highest_held_resin),
        gold_leaves = greatest(public.leaderboard.gold_leaves, excluded.gold_leaves),
        is_blight = excluded.is_blight,
        updated_at = now();
end;
$$;

revoke all on function public.submit_leaderboard_balance_score(uuid, text, double precision, double precision, double precision, double precision, bigint, boolean) from public;
grant execute on function public.submit_leaderboard_balance_score(uuid, text, double precision, double precision, double precision, double precision, bigint, boolean) to anon, authenticated;

-- Private player telemetry and administrator action queue.
create table if not exists public.player_profiles (
  player_id uuid primary key,
  display_name text not null default 'Sapling',
  tree_sap double precision not null default 0,
  tree_resin double precision not null default 0,
  lifetime_sap double precision not null default 0,
  lifetime_resin double precision not null default 0,
  current_sap double precision not null default 0,
  current_resin double precision not null default 0,
  peak_sap double precision not null default 0,
  peak_resin double precision not null default 0,
  peak_base_sap double precision not null default 0,
  peak_base_resin double precision not null default 0,
  gold_leaves bigint not null default 0,
  play_ms double precision not null default 0,
  offline_ms double precision not null default 0,
  trees_felled integer not null default 0,
  rings double precision not null default 0,
  species text not null default 'oak',
  node_count integer not null default 0,
  last_online_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.player_profiles add column if not exists peak_base_sap double precision not null default 0;
alter table public.player_profiles add column if not exists peak_base_resin double precision not null default 0;
alter table public.player_profiles add column if not exists last_online_at timestamptz;
create table if not exists public.admin_emails (
  email text primary key check (email = lower(email)),
  added_at timestamptz not null default now()
);
insert into public.admin_emails(email) values ('djdavidfreeman@gmail.com') on conflict (email) do nothing;
create table if not exists public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null,
  action_type text not null check (action_type in ('balance', 'reset')),
  sap_delta double precision not null default 0,
  resin_delta double precision not null default 0,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz
);
create index if not exists admin_actions_pending_player_idx
  on public.admin_actions (player_id, created_at) where acknowledged_at is null;

alter table public.player_profiles enable row level security;
alter table public.admin_emails enable row level security;
alter table public.admin_actions enable row level security;
revoke all on public.player_profiles, public.admin_emails, public.admin_actions from anon, authenticated;

create or replace function public.submit_player_snapshot(
  p_player_id uuid, p_display_name text, p_tree_sap double precision, p_tree_resin double precision,
  p_lifetime_sap double precision, p_lifetime_resin double precision,
  p_current_sap double precision, p_current_resin double precision,
  p_peak_sap double precision, p_peak_resin double precision,
  p_peak_base_sap double precision, p_peak_base_resin double precision,
  p_gold_leaves bigint,
  p_play_ms double precision, p_offline_ms double precision, p_trees_felled integer,
  p_rings double precision, p_species text, p_node_count integer
)
returns void language plpgsql security definer set search_path = '' as $$
declare clean_name text;
begin
  if p_player_id is null or p_tree_sap is null or p_tree_resin is null or p_lifetime_sap is null
    or p_lifetime_resin is null or p_current_sap is null or p_current_resin is null
    or p_peak_sap is null or p_peak_resin is null or p_peak_base_sap is null
    or p_peak_base_resin is null or p_gold_leaves is null or p_play_ms is null
    or p_offline_ms is null or p_trees_felled is null or p_rings is null or p_node_count is null
    or p_tree_sap < 0 or p_tree_resin < 0 or p_lifetime_sap < 0
    or p_lifetime_resin < 0 or p_current_sap < 0 or p_current_resin < 0
    or p_peak_sap < 0 or p_peak_resin < 0 or p_peak_base_sap < 0 or p_peak_base_resin < 0
    or p_gold_leaves < 0 or p_play_ms < 0
    or p_offline_ms < 0 or p_trees_felled < 0 or p_rings < 0 or p_node_count < 0 then
    raise exception 'Invalid player snapshot';
  end if;
  clean_name := left(regexp_replace(coalesce(p_display_name, ''), '[^[:alnum:] _.-]', '', 'g'), 20);
  if clean_name = '' then clean_name := 'Sapling'; end if;
  insert into public.player_profiles (
    player_id, display_name, tree_sap, tree_resin, lifetime_sap, lifetime_resin,
    current_sap, current_resin, peak_sap, peak_resin, peak_base_sap, peak_base_resin, gold_leaves, play_ms,
    offline_ms, trees_felled, rings, species, node_count, last_online_at
  ) values (
    p_player_id, clean_name, p_tree_sap, p_tree_resin, p_lifetime_sap, p_lifetime_resin,
    p_current_sap, p_current_resin, p_peak_sap, p_peak_resin, p_peak_base_sap, p_peak_base_resin, p_gold_leaves, p_play_ms,
    p_offline_ms, p_trees_felled, p_rings, left(coalesce(p_species, 'oak'), 20), p_node_count, now()
  ) on conflict (player_id) do update set
    display_name = excluded.display_name, tree_sap = excluded.tree_sap, tree_resin = excluded.tree_resin,
    lifetime_sap = greatest(public.player_profiles.lifetime_sap, excluded.lifetime_sap),
    lifetime_resin = greatest(public.player_profiles.lifetime_resin, excluded.lifetime_resin),
    current_sap = excluded.current_sap, current_resin = excluded.current_resin,
    peak_sap = greatest(public.player_profiles.peak_sap, excluded.peak_sap),
    peak_resin = greatest(public.player_profiles.peak_resin, excluded.peak_resin),
    peak_base_sap = greatest(public.player_profiles.peak_base_sap, excluded.peak_base_sap),
    peak_base_resin = greatest(public.player_profiles.peak_base_resin, excluded.peak_base_resin),
    gold_leaves = greatest(public.player_profiles.gold_leaves, excluded.gold_leaves),
    play_ms = greatest(public.player_profiles.play_ms, excluded.play_ms),
    offline_ms = greatest(public.player_profiles.offline_ms, excluded.offline_ms),
    trees_felled = greatest(public.player_profiles.trees_felled, excluded.trees_felled),
    rings = greatest(public.player_profiles.rings, excluded.rings),
    species = excluded.species, node_count = excluded.node_count,
    last_online_at = now(), updated_at = now();
end; $$;

create or replace function public.player_pending_actions(p_player_id uuid)
returns table(id uuid, action_type text, sap_delta double precision, resin_delta double precision)
language sql security definer set search_path = '' as $$
  select a.id, a.action_type, a.sap_delta, a.resin_delta
  from public.admin_actions a where a.player_id = p_player_id and a.acknowledged_at is null
  order by a.created_at limit 20;
$$;
create or replace function public.player_ack_admin_action(p_player_id uuid, p_action_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.admin_actions set acknowledged_at = now()
  where id = p_action_id and player_id = p_player_id and acknowledged_at is null;
$$;

create or replace function public.is_sapling_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.admin_emails e join auth.users u on lower(u.email) = e.email
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
create or replace function public.admin_list_players()
returns setof public.player_profiles language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  return query select * from public.player_profiles order by updated_at desc limit 500;
end; $$;
create or replace function public.admin_apply_action(
  p_player_id uuid, p_action_type text, p_sap_delta double precision default 0,
  p_resin_delta double precision default 0
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_action_type is null or p_action_type not in ('balance', 'reset') or p_player_id is null
    or p_sap_delta is null or p_resin_delta is null then raise exception 'Invalid action'; end if;
  if p_action_type = 'reset' then
    insert into public.admin_actions (player_id, action_type) values (p_player_id, 'reset') returning id into new_id;
    update public.player_profiles set
      tree_sap = 0, tree_resin = 0, lifetime_sap = 0, lifetime_resin = 0,
      current_sap = 0, current_resin = 0, peak_sap = 0, peak_resin = 0,
      peak_base_sap = 0, peak_base_resin = 0, gold_leaves = 0, play_ms = 0,
      offline_ms = 0, trees_felled = 0, rings = 0, node_count = 0, species = 'oak', updated_at = now()
      where player_id = p_player_id;
    update public.leaderboard set
      lifetime_sap = 0, lifetime_resin = 0, highest_sap = 0,
      highest_resin = 0, highest_held_sap = 0, highest_held_resin = 0,
      gold_leaves = 0, trees_felled = 0, total_rings = 0,
      updated_at = now() where player_id = p_player_id;
  else
    if abs(p_sap_delta) > 1e100 or abs(p_resin_delta) > 1e100 then raise exception 'Amount too large'; end if;
    insert into public.admin_actions (player_id, action_type, sap_delta, resin_delta)
      values (p_player_id, 'balance', p_sap_delta, p_resin_delta) returning id into new_id;
  end if;
  return new_id;
end; $$;

revoke all on function public.submit_player_snapshot(uuid, text, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, bigint, double precision, double precision, integer, double precision, text, integer) from public;
grant execute on function public.submit_player_snapshot(uuid, text, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, bigint, double precision, double precision, integer, double precision, text, integer) to anon, authenticated;
revoke all on function public.player_pending_actions(uuid), public.player_ack_admin_action(uuid, uuid), public.is_sapling_admin(), public.admin_list_players(), public.admin_apply_action(uuid, text, double precision, double precision) from public, anon, authenticated;
grant execute on function public.player_pending_actions(uuid), public.player_ack_admin_action(uuid, uuid) to anon, authenticated;
grant execute on function public.is_sapling_admin(), public.admin_list_players(), public.admin_apply_action(uuid, text, double precision, double precision) to authenticated;

-- This is a casual community leaderboard, not cheat-proof: anonymous clients
-- can still invent player IDs or claim scores. Do not treat scores as prizes.
