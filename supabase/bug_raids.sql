-- Bug raid support. Run after leaderboard.sql, account_leaderboard.sql,
-- and admin_messages.sql. Raids use linked accounts and recent reported balances.
create schema if not exists private;

create table if not exists private.sapling_bug_raid_state (
  player_id uuid primary key,
  defender_count integer not null default 0 check (defender_count between 0 and 4),
  last_raid_at timestamptz,
  highest_bug_level integer not null default 1 check (highest_bug_level between 1 and 100),
  bug_level_reported_at timestamptz
);
alter table private.sapling_bug_raid_state add column if not exists highest_bug_level integer not null default 1;
alter table private.sapling_bug_raid_state add column if not exists bug_level_reported_at timestamptz;
create table if not exists private.sapling_bug_raid_bugs (
  player_id uuid not null,
  bug_id uuid not null,
  training_started_at timestamptz not null default now(),
  trained_at timestamptz not null,
  primary key (player_id, bug_id)
);
create table if not exists private.sapling_bug_raid_events (
  id bigint generated always as identity primary key,
  attacker_id uuid not null,
  target_id uuid not null,
  resource text not null check (resource in ('sap','resin')),
  amount double precision not null check (amount >= 0),
  created_at timestamptz not null default now()
);
create table if not exists private.sapling_bug_raid_trips (
  player_id uuid primary key,
  bug_id uuid not null,
  target_id uuid not null,
  resource text not null check (resource in ('sap','resin')),
  started_at timestamptz not null default now()
);
alter table private.sapling_bug_raid_state enable row level security;
alter table private.sapling_bug_raid_bugs enable row level security;
alter table private.sapling_bug_raid_events enable row level security;
alter table private.sapling_bug_raid_trips enable row level security;
revoke all on private.sapling_bug_raid_state, private.sapling_bug_raid_bugs,
  private.sapling_bug_raid_events, private.sapling_bug_raid_trips from public, anon, authenticated;

create or replace function public.report_bug_raid_level(p_player_id uuid,p_highest_bug_level integer)
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  if p_highest_bug_level not between 1 and 100 then raise exception 'Invalid bug level'; end if;
  insert into private.sapling_bug_raid_state(player_id,highest_bug_level,bug_level_reported_at)
    values(p_player_id,p_highest_bug_level,now())
    on conflict(player_id) do update set highest_bug_level=excluded.highest_bug_level,bug_level_reported_at=now();
end; $$;
revoke all on function public.report_bug_raid_level(uuid,integer) from public,anon;
grant execute on function public.report_bug_raid_level(uuid,integer) to authenticated;

create or replace function public.get_bug_raid_targets(p_player_id uuid)
returns table(player_id uuid,display_name text,highest_bug_level integer)
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  return query
    select l.player_id,n.display_name,s.highest_bug_level
    from public.leaderboard l
    join public.leaderboard_names n on n.player_id=l.player_id
    join private.sapling_bug_raid_state s on s.player_id=l.player_id
    where l.player_id<>p_player_id
      and l.current_balance_reported_at>now()-interval '5 minutes'
      and l.fresh_score_reported_at>now()-interval '5 minutes'
      and s.bug_level_reported_at>now()-interval '24 hours'
    order by n.display_name asc limit 100;
end; $$;
revoke all on function public.get_bug_raid_targets(uuid) from public,anon;
grant execute on function public.get_bug_raid_targets(uuid) to authenticated;

create or replace function public.start_bug_raid_training(p_player_id uuid,p_bug_id uuid)
returns timestamptz language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); done_at timestamptz; reported_sap double precision; reported_resin double precision;
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  if p_bug_id is null then raise exception 'Bug required'; end if;
  if exists(select 1 from private.sapling_bug_raid_bugs b where b.player_id=p_player_id and b.bug_id=p_bug_id and b.trained_at<=now()) then
    raise exception 'This bug is already raid trained';
  end if;
  if exists(select 1 from private.sapling_bug_raid_bugs b where b.player_id=p_player_id and b.bug_id=p_bug_id and b.trained_at>now()) then
    raise exception 'This bug is already training';
  end if;
  select l.current_sap,l.current_resin into reported_sap,reported_resin
    from public.leaderboard l where l.player_id=p_player_id
      and l.current_balance_reported_at>now()-interval '5 minutes' for update;
  if not found then raise exception 'Submit a recent online balance before training'; end if;
  if reported_sap<500 or reported_resin<250 then raise exception 'Need 500 sap and 250 resin to train'; end if;
  update public.leaderboard l set current_sap=l.current_sap-500,current_resin=l.current_resin-250,
    current_balance_reported_at=now(),updated_at=now() where player_id=p_player_id;
  insert into public.admin_actions(player_id,action_type,sap_delta,resin_delta,message)
    values(p_player_id,'balance',-500,-250,'Raid training started: 500 sap and 250 resin spent.');
  insert into private.sapling_bug_raid_bugs(player_id,bug_id,training_started_at,trained_at)
  values(p_player_id,p_bug_id,now(),now()+interval '5 minutes')
  on conflict(player_id,bug_id) do update set training_started_at=excluded.training_started_at,trained_at=excluded.trained_at
  returning trained_at into done_at;
  return done_at;
end; $$;
revoke all on function public.start_bug_raid_training(uuid,uuid) from public,anon;
grant execute on function public.start_bug_raid_training(uuid,uuid) to authenticated;

create or replace function public.set_bug_defenders(p_player_id uuid,p_defender_count integer)
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  if p_defender_count not between 0 and 4 then raise exception 'Invalid defender count'; end if;
  insert into private.sapling_bug_raid_state(player_id,defender_count) values(p_player_id,p_defender_count)
  on conflict(player_id) do update set defender_count=excluded.defender_count;
end; $$;
revoke all on function public.set_bug_defenders(uuid,integer) from public,anon;
grant execute on function public.set_bug_defenders(uuid,integer) to authenticated;

drop function if exists public.start_bug_raid(uuid,uuid,uuid,text);
create or replace function public.start_bug_raid(p_player_id uuid,p_bug_id uuid,p_target_id uuid,p_resource text,p_bug_level integer)
returns timestamptz language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  started timestamptz := now();
  raid_lock timestamptz;
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  if p_player_id is null or p_target_id is null or p_player_id=p_target_id then raise exception 'Choose another player'; end if;
  if p_resource is null or p_resource not in ('sap','resin') or p_bug_id is null then raise exception 'Invalid raid'; end if;
  if p_bug_level not between 1 and 100 then raise exception 'Invalid bug level'; end if;
  if not exists(select 1 from private.sapling_bug_raid_bugs b where b.player_id=p_player_id and b.bug_id=p_bug_id and b.trained_at<=now()) then
    raise exception 'This bug has not completed raid training';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_player_id::text,21));
  select s.last_raid_at into raid_lock from private.sapling_bug_raid_state s where s.player_id=p_player_id for update;
  if raid_lock is not null and raid_lock>now()-interval '30 minutes' then raise exception 'Your bugs need more time to recover'; end if;
  if exists(select 1 from private.sapling_bug_raid_trips t where t.player_id=p_player_id) then raise exception 'A bug is already on a raid'; end if;
  if not exists(select 1 from public.leaderboard l join private.sapling_bug_raid_state s on s.player_id=l.player_id
    where l.player_id=p_target_id and l.current_balance_reported_at>now()-interval '5 minutes' and l.fresh_score_reported_at>now()-interval '5 minutes'
      and s.bug_level_reported_at>now()-interval '24 hours' and abs(s.highest_bug_level-p_bug_level)<=3) then
    raise exception 'That player is no longer near this bug’s level';
  end if;
  insert into private.sapling_bug_raid_trips(player_id,bug_id,target_id,resource,started_at)
    values(p_player_id,p_bug_id,p_target_id,p_resource,started);
  return started;
end; $$;
revoke all on function public.start_bug_raid(uuid,uuid,uuid,text,integer) from public,anon;
grant execute on function public.start_bug_raid(uuid,uuid,uuid,text,integer) to authenticated;

create or replace function public.get_bug_raid_trip(p_player_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); trip private.sapling_bug_raid_trips%rowtype; raid private.sapling_bug_raid_state%rowtype;
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  select * into raid from private.sapling_bug_raid_state s where s.player_id=p_player_id;
  select * into trip from private.sapling_bug_raid_trips t where t.player_id=p_player_id;
  if not found then return jsonb_build_object('trip',null,'last_raid_at',raid.last_raid_at); end if;
  return jsonb_build_object('trip',jsonb_build_object('bug_id',trip.bug_id,'target_id',trip.target_id,'resource',trip.resource,'started_at',trip.started_at),'last_raid_at',raid.last_raid_at);
end; $$;
revoke all on function public.get_bug_raid_trip(uuid) from public,anon;
grant execute on function public.get_bug_raid_trip(uuid) to authenticated;

drop function if exists public.resolve_bug_raid(uuid,uuid,uuid,text);
create or replace function public.resolve_bug_raid(p_player_id uuid,p_bug_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  trip private.sapling_bug_raid_trips%rowtype;
  target_id uuid;
  resource text;
  balance double precision;
  amount double precision;
  defense integer := 0;
  target_name text;
  attacker_name text;
  raid_lock timestamptz;
begin
  if uid is null or not exists(select 1 from private.sapling_account_players a where a.user_id=uid and a.player_id=p_player_id) then
    raise exception 'Linked account required';
  end if;
  if p_bug_id is null then raise exception 'Bug required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_player_id::text,21));
  select * into trip from private.sapling_bug_raid_trips t where t.player_id=p_player_id for update;
  if not found or trip.bug_id<>p_bug_id then raise exception 'No matching raid is underway'; end if;
  if trip.started_at>now()-interval '60 seconds' then raise exception 'Your bug is still travelling'; end if;
  target_id:=trip.target_id; resource:=trip.resource;
  delete from private.sapling_bug_raid_trips where player_id=p_player_id;
  select s.last_raid_at into raid_lock from private.sapling_bug_raid_state s where s.player_id=p_player_id for update;
  if raid_lock is not null and raid_lock>now()-interval '30 minutes' then raise exception 'Your bugs need more time to recover'; end if;
  select n.display_name into target_name from public.leaderboard_names n where n.player_id=target_id;
  select n.display_name into attacker_name from public.leaderboard_names n where n.player_id=p_player_id;
  if target_name is null or attacker_name is null then raise exception 'A player name is not available'; end if;
  if not exists(select 1 from public.leaderboard l where l.player_id=target_id and l.current_balance_reported_at>now()-interval '5 minutes' and l.fresh_score_reported_at>now()-interval '5 minutes') then
    insert into private.sapling_bug_raid_state(player_id,last_raid_at) values(p_player_id,now())
      on conflict(player_id) do update set last_raid_at=now();
    return jsonb_build_object('success',false,'amount',0,'resource',resource,'target',target_name,'message','Target went offline during the trip');
  end if;
  if resource='sap' then
    select l.current_sap into balance from public.leaderboard l where l.player_id=target_id for update;
  else
    select l.current_resin into balance from public.leaderboard l where l.player_id=target_id for update;
  end if;
  select coalesce(s.defender_count,0) into defense from private.sapling_bug_raid_state s where s.player_id=target_id;
  amount:=least(2500,greatest(0,balance)*0.02*(1-least(4,coalesce(defense,0))*0.15));
  amount:=floor(amount);
  if amount>0 then
    if resource='sap' then
      update public.leaderboard set current_sap=current_sap-amount,current_balance_reported_at=now(),updated_at=now() where player_id=target_id;
      update public.leaderboard set current_sap=current_sap+amount,current_balance_reported_at=now(),updated_at=now() where player_id=p_player_id;
      insert into public.admin_actions(player_id,action_type,sap_delta,message) values
        (target_id,'balance',-amount,'An opposing bug raided your grove. Assigned hub defenders reduce the loss.'),
        (p_player_id,'balance',amount,'Your trained bug returned from a raid with stolen sap.');
    else
      update public.leaderboard set current_resin=current_resin-amount,current_balance_reported_at=now(),updated_at=now() where player_id=target_id;
      update public.leaderboard set current_resin=current_resin+amount,current_balance_reported_at=now(),updated_at=now() where player_id=p_player_id;
      insert into public.admin_actions(player_id,action_type,resin_delta,message) values
        (target_id,'balance',-amount,'An opposing bug raided your grove. Assigned hub defenders reduce the loss.'),
        (p_player_id,'balance',amount,'Your trained bug returned from a raid with stolen resin.');
    end if;
  end if;
  insert into private.sapling_bug_raid_state(player_id,last_raid_at) values(p_player_id,now())
    on conflict(player_id) do update set last_raid_at=now();
  insert into private.sapling_bug_raid_events(attacker_id,target_id,resource,amount) values(p_player_id,target_id,resource,amount);
  return jsonb_build_object('success',amount>0,'amount',amount,'resource',resource,'target',target_name,'message',case when amount>0 then 'Raid complete' else 'No resources could be taken' end);
end; $$;
revoke all on function public.resolve_bug_raid(uuid,uuid) from public,anon;
grant execute on function public.resolve_bug_raid(uuid,uuid) to authenticated;
