-- Apply after live_challenge_goals.sql. Quest gear is snapshotted at publication.
-- Existing quests/completions receive empty gear rewards; no progress is changed.
alter table public.live_challenges
  add column if not exists reward_gear jsonb not null default '[]'::jsonb,
  add column if not exists first_bonus_gear jsonb not null default '[]'::jsonb;
alter table public.live_challenge_completions
  add column if not exists reward_gear jsonb not null default '[]'::jsonb;
create table if not exists public.quest_gear (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  slot text not null check (slot in ('weapon','armor','charm')),
  hp integer not null check (hp between -10000 and 10000),
  attack integer not null check (attack between -10000 and 10000),
  defense integer not null check (defense between -10000 and 10000),
  created_at timestamptz not null default now()
);
-- Widen existing catalogs too; rerunning this script preserves gear and quest snapshots.
alter table public.quest_gear
  drop constraint if exists quest_gear_hp_check,
  drop constraint if exists quest_gear_attack_check,
  drop constraint if exists quest_gear_defense_check;
alter table public.quest_gear
  add constraint quest_gear_hp_check check (hp between -10000 and 10000),
  add constraint quest_gear_attack_check check (attack between -10000 and 10000),
  add constraint quest_gear_defense_check check (defense between -10000 and 10000);
alter table public.quest_gear enable row level security;
revoke all on public.quest_gear from public, anon, authenticated;
grant select on public.quest_gear to authenticated;
drop policy if exists quest_gear_admin_read on public.quest_gear;
create policy quest_gear_admin_read on public.quest_gear for select to authenticated using (public.is_sapling_admin());
create or replace function public.admin_create_quest_gear(p_name text,p_slot text,p_hp integer,p_attack integer,p_defense integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare gear_id uuid;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  insert into public.quest_gear(name,slot,hp,attack,defense) values(trim(p_name),p_slot,p_hp,p_attack,p_defense) returning id into gear_id;
  return gear_id;
end; $$;
drop function if exists public.get_live_challenges(uuid);
create function public.get_live_challenges(p_player_id uuid)
returns table(
  id uuid, title text, description text, target_sap double precision, target_type text, goals jsonb,
  opens_at timestamptz, closes_at timestamptz,
  reward_sap double precision, reward_resin double precision,
  reward_acorns bigint, reward_rings bigint, reward_amber bigint,
  first_bonus_sap double precision, first_bonus_resin double precision,
  first_bonus_acorns bigint, first_bonus_rings bigint, first_bonus_amber bigint,
  first_finisher text, completion_count bigint, player_completed boolean, server_now timestamptz, reward_gear jsonb, first_bonus_gear jsonb
)
language sql stable security definer set search_path = '' as $$
  select c.id, c.title, c.description, c.target_sap, c.target_type,
    case when jsonb_array_length(c.goals) > 0 then c.goals else jsonb_build_array(jsonb_build_object('type', c.target_type, 'target', c.target_sap)) end,
    c.opens_at, c.closes_at,
    c.reward_sap, c.reward_resin, c.reward_acorns, c.reward_rings, c.reward_amber,
    c.first_bonus_sap, c.first_bonus_resin, c.first_bonus_acorns, c.first_bonus_rings, c.first_bonus_amber,
    (select x.display_name from public.live_challenge_completions x where x.challenge_id = c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id),
    exists(select 1 from public.live_challenge_completions x where x.challenge_id = c.id and x.player_id = p_player_id), now(), c.reward_gear, c.first_bonus_gear
  from public.live_challenges c
  where c.ended_at is null and c.opens_at <= now() and c.closes_at > now()
  order by c.opens_at desc;
$$;

drop function if exists public.claim_live_challenge(uuid,uuid,text,double precision);
drop function if exists public.claim_live_challenge(uuid,uuid,text,jsonb);
create function public.claim_live_challenge(
  p_challenge_id uuid, p_player_id uuid, p_display_name text, p_progress jsonb
)
returns table(already_completed boolean, first_finisher boolean, reward_sap double precision, reward_resin double precision,
  reward_acorns bigint, reward_rings bigint, reward_amber bigint, reward_gear jsonb)
language plpgsql security definer set search_path = '' as $$
declare c public.live_challenges%rowtype; prior public.live_challenge_completions%rowtype;
  first_claim boolean; clean_name text; total_sap double precision; total_resin double precision;
  total_acorns bigint; total_rings bigint; total_amber bigint; total_gear jsonb;
begin
  if p_challenge_id is null or p_player_id is null or p_progress is null or jsonb_typeof(p_progress) <> 'array' then raise exception 'Invalid completion'; end if;
  select * into c from public.live_challenges where id = p_challenge_id for update;
  if not found then raise exception 'Challenge not found'; end if;
  select * into prior from public.live_challenge_completions x
    where x.challenge_id = p_challenge_id and x.player_id = p_player_id;
  if found then
    return query select true, prior.is_first, prior.reward_sap, prior.reward_resin,
      prior.reward_acorns, prior.reward_rings, prior.reward_amber, prior.reward_gear;
    return;
  end if;
  if c.ended_at is not null or now() < c.opens_at or now() >= c.closes_at then raise exception 'Challenge is closed'; end if;
  if exists (select 1 from jsonb_array_elements(case when jsonb_array_length(c.goals) > 0 then c.goals else jsonb_build_array(jsonb_build_object('type', c.target_type, 'target', c.target_sap)) end) with ordinality g(goal, idx)
    where coalesce((p_progress -> ((g.idx - 1)::int))::double precision, 0) < (g.goal ->> 'target')::double precision) then raise exception 'Target not reached'; end if;
  first_claim := not exists(select 1 from public.live_challenge_completions x where x.challenge_id = c.id);
  clean_name := left(regexp_replace(coalesce(p_display_name, ''), '[^[:alnum:] _.-]', '', 'g'), 20);
  if clean_name = '' then clean_name := 'Sapling'; end if;
  total_sap := c.reward_sap + case when first_claim then c.first_bonus_sap else 0 end;
  total_resin := c.reward_resin + case when first_claim then c.first_bonus_resin else 0 end;
  total_acorns := c.reward_acorns + case when first_claim then c.first_bonus_acorns else 0 end;
  total_rings := c.reward_rings + case when first_claim then c.first_bonus_rings else 0 end;
  total_amber := c.reward_amber + case when first_claim then c.first_bonus_amber else 0 end;
  total_gear := c.reward_gear || case when first_claim then c.first_bonus_gear else '[]'::jsonb end;
  insert into public.live_challenge_completions(challenge_id, player_id, display_name, is_first,
    reward_sap, reward_resin, reward_acorns, reward_rings, reward_amber, reward_gear)
    values(c.id, p_player_id, clean_name, first_claim, total_sap, total_resin, total_acorns, total_rings, total_amber, total_gear);
  return query select false, first_claim, total_sap, total_resin, total_acorns, total_rings, total_amber, total_gear;
end; $$;

drop function if exists public.admin_list_live_challenges();
create function public.admin_list_live_challenges()
returns table(
  id uuid, title text, description text, target_sap double precision, target_type text, goals jsonb,
  opens_at timestamptz, closes_at timestamptz, ended_at timestamptz,
  reward_sap double precision, reward_resin double precision,
  reward_acorns bigint, reward_rings bigint, reward_amber bigint,
  first_bonus_sap double precision, first_bonus_resin double precision,
  first_bonus_acorns bigint, first_bonus_rings bigint, first_bonus_amber bigint,
  first_finisher text, completion_count bigint, reward_gear jsonb, first_bonus_gear jsonb
)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  return query select c.id, c.title, c.description, c.target_sap, c.target_type, c.goals, c.opens_at, c.closes_at, c.ended_at,
    c.reward_sap, c.reward_resin, c.reward_acorns, c.reward_rings, c.reward_amber,
    c.first_bonus_sap, c.first_bonus_resin, c.first_bonus_acorns, c.first_bonus_rings, c.first_bonus_amber,
    (select x.display_name from public.live_challenge_completions x where x.challenge_id = c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id), c.reward_gear, c.first_bonus_gear
  from public.live_challenges c order by c.created_at desc limit 100;
end; $$;


-- Keep the existing publisher available to older admin clients; the new wrapper
-- calls it so all existing goal, duration, reward and admin checks still apply.
create or replace function public.admin_publish_gear_quest(
  p_title text, p_description text, p_goals jsonb, p_duration_hours double precision,
  p_reward_sap double precision, p_reward_resin double precision,
  p_reward_acorns bigint, p_reward_rings bigint, p_reward_amber bigint,
  p_first_bonus_sap double precision, p_first_bonus_resin double precision,
  p_first_bonus_acorns bigint, p_first_bonus_rings bigint, p_first_bonus_amber bigint,
  p_reward_gear uuid default null, p_first_bonus_gear uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare quest_id uuid; reward jsonb := '[]'::jsonb; bonus jsonb := '[]'::jsonb;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_reward_gear is not null then
    select jsonb_build_array(to_jsonb(g) - 'created_at') into reward from public.quest_gear g where g.id=p_reward_gear;
    if reward is null then raise exception 'Reward gear not found'; end if;
  end if;
  if p_first_bonus_gear is not null then
    select jsonb_build_array(to_jsonb(g) - 'created_at') into bonus from public.quest_gear g where g.id=p_first_bonus_gear;
    if bonus is null then raise exception 'Bonus gear not found'; end if;
  end if;
  quest_id := public.admin_publish_live_challenge(p_title,p_description,p_goals,p_duration_hours,
    p_reward_sap,p_reward_resin,p_reward_acorns,p_reward_rings,p_reward_amber,
    p_first_bonus_sap,p_first_bonus_resin,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber);
  update public.live_challenges set reward_gear=reward, first_bonus_gear=bonus where id=quest_id;
  return quest_id;
end; $$;
revoke all on function public.admin_create_quest_gear(text,text,integer,integer,integer),
  public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid),
  public.get_live_challenges(uuid), public.claim_live_challenge(uuid,uuid,text,jsonb), public.admin_list_live_challenges()
  from public, anon, authenticated;
grant execute on function public.get_live_challenges(uuid), public.claim_live_challenge(uuid,uuid,text,jsonb) to anon, authenticated;
grant execute on function public.admin_create_quest_gear(text,text,integer,integer,integer),
  public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid),
  public.admin_list_live_challenges() to authenticated;
notify pgrst, 'reload schema';
