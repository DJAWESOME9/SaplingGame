-- Live Sapling challenges. Apply after leaderboard.sql.
create table if not exists public.live_challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 60),
  description text not null check (char_length(description) between 1 and 240),
  target_sap double precision not null check (target_sap > 0),
  opens_at timestamptz not null default now(),
  closes_at timestamptz not null,
  ended_at timestamptz,
  reward_sap double precision not null default 0 check (reward_sap >= 0),
  reward_resin double precision not null default 0 check (reward_resin >= 0),
  first_bonus_sap double precision not null default 0 check (first_bonus_sap >= 0),
  first_bonus_resin double precision not null default 0 check (first_bonus_resin >= 0),
  created_at timestamptz not null default now(),
  check (closes_at > opens_at)
);
create table if not exists public.live_challenge_completions (
  challenge_id uuid not null references public.live_challenges(id) on delete cascade,
  player_id uuid not null,
  display_name text not null,
  completed_at timestamptz not null default now(),
  is_first boolean not null default false,
  reward_sap double precision not null default 0,
  reward_resin double precision not null default 0,
  primary key (challenge_id, player_id)
);
create index if not exists live_challenge_completions_first_idx
  on public.live_challenge_completions (challenge_id, completed_at);

alter table public.live_challenges enable row level security;
alter table public.live_challenge_completions enable row level security;
revoke all on public.live_challenges, public.live_challenge_completions from anon, authenticated;

create or replace function public.get_live_challenges(p_player_id uuid)
returns table(
  id uuid, title text, description text, target_sap double precision,
  opens_at timestamptz, closes_at timestamptz,
  reward_sap double precision, reward_resin double precision,
  first_bonus_sap double precision, first_bonus_resin double precision,
  first_finisher text, completion_count bigint, player_completed boolean
)
language sql stable security definer set search_path = '' as $$
  select c.id, c.title, c.description, c.target_sap, c.opens_at, c.closes_at,
    c.reward_sap, c.reward_resin, c.first_bonus_sap, c.first_bonus_resin,
    (select x.display_name from public.live_challenge_completions x
      where x.challenge_id = c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id),
    exists(select 1 from public.live_challenge_completions x
      where x.challenge_id = c.id and x.player_id = p_player_id)
  from public.live_challenges c
  where c.ended_at is null and c.opens_at <= now() and c.closes_at > now()
  order by c.opens_at desc;
$$;

create or replace function public.claim_live_challenge(
  p_challenge_id uuid, p_player_id uuid, p_display_name text, p_current_sap double precision
)
returns table(already_completed boolean, first_finisher boolean, reward_sap double precision, reward_resin double precision)
language plpgsql security definer set search_path = '' as $$
declare c public.live_challenges%rowtype; prior public.live_challenge_completions%rowtype;
  first_claim boolean; clean_name text; total_sap double precision; total_resin double precision;
begin
  if p_challenge_id is null or p_player_id is null or p_current_sap is null
    or p_current_sap < 0 or p_current_sap > 1e100 then raise exception 'Invalid completion'; end if;
  select * into c from public.live_challenges where id = p_challenge_id for update;
  if not found then raise exception 'Challenge not found'; end if;
  select * into prior from public.live_challenge_completions x
    where x.challenge_id = p_challenge_id and x.player_id = p_player_id;
  if found then
    return query select true, prior.is_first, prior.reward_sap, prior.reward_resin;
    return;
  end if;
  if c.ended_at is not null or now() < c.opens_at or now() >= c.closes_at then raise exception 'Challenge is closed'; end if;
  if p_current_sap < c.target_sap then raise exception 'Target not reached'; end if;
  first_claim := not exists(select 1 from public.live_challenge_completions x where x.challenge_id = c.id);
  clean_name := left(regexp_replace(coalesce(p_display_name, ''), '[^[:alnum:] _.-]', '', 'g'), 20);
  if clean_name = '' then clean_name := 'Sapling'; end if;
  total_sap := c.reward_sap + case when first_claim then c.first_bonus_sap else 0 end;
  total_resin := c.reward_resin + case when first_claim then c.first_bonus_resin else 0 end;
  insert into public.live_challenge_completions(challenge_id, player_id, display_name, is_first, reward_sap, reward_resin)
    values(c.id, p_player_id, clean_name, first_claim, total_sap, total_resin);
  return query select false, first_claim, total_sap, total_resin;
end; $$;

create or replace function public.admin_list_live_challenges()
returns table(
  id uuid, title text, description text, target_sap double precision,
  opens_at timestamptz, closes_at timestamptz, ended_at timestamptz,
  reward_sap double precision, reward_resin double precision,
  first_bonus_sap double precision, first_bonus_resin double precision,
  first_finisher text, completion_count bigint
)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  return query select c.id, c.title, c.description, c.target_sap, c.opens_at, c.closes_at, c.ended_at,
    c.reward_sap, c.reward_resin, c.first_bonus_sap, c.first_bonus_resin,
    (select x.display_name from public.live_challenge_completions x where x.challenge_id = c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id)
  from public.live_challenges c order by c.created_at desc limit 100;
end; $$;

create or replace function public.admin_publish_live_challenge(
  p_title text, p_description text, p_target_sap double precision,
  p_duration_hours double precision, p_reward_sap double precision default 0,
  p_reward_resin double precision default 0,
  p_first_bonus_sap double precision default 0, p_first_bonus_resin double precision default 0
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid; clean_title text;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  clean_title := left(trim(coalesce(p_title, '')), 60);
  if clean_title = '' or char_length(trim(coalesce(p_description, ''))) not between 1 and 240
    or p_target_sap is null or p_target_sap <= 0 or p_target_sap > 1e100
    or p_duration_hours is null or p_duration_hours <= 0 or p_duration_hours > 8760
    or p_reward_sap is null or p_reward_resin is null or p_first_bonus_sap is null or p_first_bonus_resin is null
    or least(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin) < 0
    or greatest(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin) > 1e100 then
    raise exception 'Invalid challenge details';
  end if;
  insert into public.live_challenges(title, description, target_sap, opens_at, closes_at,
    reward_sap, reward_resin, first_bonus_sap, first_bonus_resin)
  values(clean_title, trim(p_description), p_target_sap, now(), now() + make_interval(secs => p_duration_hours * 3600),
    p_reward_sap, p_reward_resin, p_first_bonus_sap, p_first_bonus_resin)
  returning id into new_id;
  return new_id;
end; $$;

create or replace function public.admin_end_live_challenge(p_challenge_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  update public.live_challenges set ended_at = now() where id = p_challenge_id and ended_at is null;
end; $$;

revoke all on function public.get_live_challenges(uuid), public.claim_live_challenge(uuid,uuid,text,double precision), public.admin_list_live_challenges(), public.admin_publish_live_challenge(text,text,double precision,double precision,double precision,double precision,double precision,double precision), public.admin_end_live_challenge(uuid) from public, anon, authenticated;
grant execute on function public.get_live_challenges(uuid), public.claim_live_challenge(uuid,uuid,text,double precision) to anon, authenticated;
grant execute on function public.admin_list_live_challenges(), public.admin_publish_live_challenge(text,text,double precision,double precision,double precision,double precision,double precision,double precision), public.admin_end_live_challenge(uuid) to authenticated;
