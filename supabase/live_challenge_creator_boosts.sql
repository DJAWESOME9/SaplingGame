-- Apply after quest_gear.sql. Adds expanded client-tracked quest goals and timed boost rewards.
-- Existing quest records and completion history remain unchanged.
begin;
alter table public.live_challenges
  add column if not exists reward_boost jsonb not null default 'null'::jsonb,
  add column if not exists first_bonus_boost jsonb not null default 'null'::jsonb;
alter table public.live_challenge_completions
  add column if not exists reward_boost jsonb not null default 'null'::jsonb;
alter table public.live_challenges drop constraint if exists live_challenges_target_type_check;
alter table public.live_challenges add constraint live_challenges_target_type_check check (target_type in (
  'banked_sap','sap','leaf_sap','oak_sap','apple_sap','peach_sap','grape_sap','maple_sap','pine_sap','chocolate_sap',
  'resin','refinery_resin','channel','expeditions','amber','rings','bugs','bug_level','grafts','upgrade_type','tree_height','node_count','acorns','leaf_rate','idle_sap'
));

create or replace function public.admin_publish_live_challenge(
  p_title text,p_description text,p_goals jsonb,p_duration_hours double precision,p_reward_sap double precision,p_reward_resin double precision,
  p_reward_acorns bigint,p_reward_rings bigint,p_reward_amber bigint,p_first_bonus_sap double precision,p_first_bonus_resin double precision,
  p_first_bonus_acorns bigint,p_first_bonus_rings bigint,p_first_bonus_amber bigint
) returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid; clean_title text;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  clean_title:=left(trim(coalesce(p_title,'')),60);
  if clean_title='' or char_length(trim(coalesce(p_description,''))) not between 1 and 240
    or p_goals is null or jsonb_typeof(p_goals)<>'array' or jsonb_array_length(p_goals)<1 or jsonb_array_length(p_goals)>8
    or exists(select 1 from jsonb_array_elements(p_goals) g where (g->>'type') not in ('sap','leaf_sap','oak_sap','apple_sap','peach_sap','grape_sap','maple_sap','pine_sap','chocolate_sap','leaf_rate','idle_sap','resin','refinery_resin','channel','expeditions','amber','rings','bugs','bug_level','grafts','upgrade_type','tree_height','node_count','acorns') or coalesce((g->>'target')::double precision,0)<=0 or (g->>'target')::double precision>1e100)
    or exists(select 1 from jsonb_array_elements(p_goals) g where (g->>'type') in ('expeditions','amber','rings','bugs','bug_level','grafts','upgrade_type','node_count','acorns') and (g->>'target')::double precision<>floor((g->>'target')::double precision))
    or exists(select 1 from jsonb_array_elements(p_goals) g where g->>'type'='bug_level' and (coalesce((g->>'level')::int,0)<1 or (g->>'level')::int>100))
    or exists(select 1 from jsonb_array_elements(p_goals) g where g->>'type'='upgrade_type' and (g->>'node_type') not in ('leaf','amp','ref','cap','funnel'))
    or p_duration_hours is null or p_duration_hours<=0 or p_duration_hours>8760
    or least(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin,p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber)<0
    or greatest(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin,p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber)>1e12 then raise exception 'Invalid challenge details'; end if;
  insert into public.live_challenges(title,description,target_sap,target_type,goals,opens_at,closes_at,reward_sap,reward_resin,reward_acorns,reward_rings,reward_amber,first_bonus_sap,first_bonus_resin,first_bonus_acorns,first_bonus_rings,first_bonus_amber)
  values(clean_title,trim(p_description),(p_goals->0->>'target')::double precision,p_goals->0->>'type',p_goals,now(),now()+make_interval(secs=>p_duration_hours*3600),p_reward_sap,p_reward_resin,p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_sap,p_first_bonus_resin,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber) returning id into new_id;
  return new_id;
end; $$;

drop function if exists public.get_live_challenges(uuid);
create function public.get_live_challenges(p_player_id uuid)
returns table(
  id uuid,title text,description text,target_sap double precision,target_type text,goals jsonb,
  opens_at timestamptz,closes_at timestamptz,reward_sap double precision,reward_resin double precision,
  reward_acorns bigint,reward_rings bigint,reward_amber bigint,first_bonus_sap double precision,first_bonus_resin double precision,
  first_bonus_acorns bigint,first_bonus_rings bigint,first_bonus_amber bigint,first_finisher text,completion_count bigint,
  player_completed boolean,server_now timestamptz,reward_gear jsonb,first_bonus_gear jsonb,reward_boost jsonb,first_bonus_boost jsonb
)
language sql stable security definer set search_path = '' as $$
  select c.id,c.title,c.description,c.target_sap,c.target_type,
    case when jsonb_array_length(c.goals)>0 then c.goals else jsonb_build_array(jsonb_build_object('type',c.target_type,'target',c.target_sap)) end,
    c.opens_at,c.closes_at,c.reward_sap,c.reward_resin,c.reward_acorns,c.reward_rings,c.reward_amber,
    c.first_bonus_sap,c.first_bonus_resin,c.first_bonus_acorns,c.first_bonus_rings,c.first_bonus_amber,
    (select x.display_name from public.live_challenge_completions x where x.challenge_id=c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id=c.id),
    exists(select 1 from public.live_challenge_completions x where x.challenge_id=c.id and x.player_id=p_player_id),now(),
    c.reward_gear,c.first_bonus_gear,c.reward_boost,c.first_bonus_boost
  from public.live_challenges c where c.ended_at is null and c.opens_at<=now() and c.closes_at>now() order by c.opens_at desc;
$$;

drop function if exists public.claim_live_challenge(uuid,uuid,text,jsonb);
create function public.claim_live_challenge(p_challenge_id uuid,p_player_id uuid,p_display_name text,p_progress jsonb)
returns table(already_completed boolean,first_finisher boolean,reward_sap double precision,reward_resin double precision,
  reward_acorns bigint,reward_rings bigint,reward_amber bigint,reward_gear jsonb,reward_boost jsonb)
language plpgsql security definer set search_path = '' as $$
declare c public.live_challenges%rowtype; prior public.live_challenge_completions%rowtype; first_claim boolean; clean_name text;
begin
  if p_challenge_id is null or p_player_id is null or p_progress is null or jsonb_typeof(p_progress)<>'array' then raise exception 'Invalid completion'; end if;
  select * into c from public.live_challenges where id=p_challenge_id for update;
  if not found then raise exception 'Challenge not found'; end if;
  select * into prior from public.live_challenge_completions x where x.challenge_id=p_challenge_id and x.player_id=p_player_id;
  if found then return query select true,prior.is_first,prior.reward_sap,prior.reward_resin,prior.reward_acorns,prior.reward_rings,prior.reward_amber,prior.reward_gear,prior.reward_boost; return; end if;
  if c.ended_at is not null or now()<c.opens_at or now()>=c.closes_at then raise exception 'Challenge is closed'; end if;
  if exists(select 1 from jsonb_array_elements(case when jsonb_array_length(c.goals)>0 then c.goals else jsonb_build_array(jsonb_build_object('type',c.target_type,'target',c.target_sap)) end) with ordinality g(goal,idx)
    where coalesce((p_progress->((g.idx-1)::int))::double precision,0)<(g.goal->>'target')::double precision) then raise exception 'Target not reached'; end if;
  first_claim:=not exists(select 1 from public.live_challenge_completions x where x.challenge_id=c.id);
  clean_name:=left(regexp_replace(coalesce(p_display_name,''),'[^[:alnum:] _.-]','','g'),20); if clean_name='' then clean_name:='Sapling'; end if;
  insert into public.live_challenge_completions(challenge_id,player_id,display_name,is_first,reward_sap,reward_resin,reward_acorns,reward_rings,reward_amber,reward_gear,reward_boost)
  values(c.id,p_player_id,clean_name,first_claim,c.reward_sap+case when first_claim then c.first_bonus_sap else 0 end,
    c.reward_resin+case when first_claim then c.first_bonus_resin else 0 end,
    c.reward_acorns+case when first_claim then c.first_bonus_acorns else 0 end,
    c.reward_rings+case when first_claim then c.first_bonus_rings else 0 end,
    c.reward_amber+case when first_claim then c.first_bonus_amber else 0 end,
    c.reward_gear||case when first_claim then c.first_bonus_gear else '[]'::jsonb end,
    case when first_claim and c.first_bonus_boost<>'null'::jsonb then jsonb_build_array(c.reward_boost,c.first_bonus_boost) else case when c.reward_boost='null'::jsonb then '[]'::jsonb else jsonb_build_array(c.reward_boost) end end);
  return query select false,first_claim,c.reward_sap+case when first_claim then c.first_bonus_sap else 0 end,
    c.reward_resin+case when first_claim then c.first_bonus_resin else 0 end,
    c.reward_acorns+case when first_claim then c.first_bonus_acorns else 0 end,
    c.reward_rings+case when first_claim then c.first_bonus_rings else 0 end,
    c.reward_amber+case when first_claim then c.first_bonus_amber else 0 end,
    c.reward_gear||case when first_claim then c.first_bonus_gear else '[]'::jsonb end,
    case when first_claim and c.first_bonus_boost<>'null'::jsonb then jsonb_build_array(c.reward_boost,c.first_bonus_boost) else case when c.reward_boost='null'::jsonb then '[]'::jsonb else jsonb_build_array(c.reward_boost) end end;
end; $$;

drop function if exists public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid);
drop function if exists public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid,jsonb,jsonb);
create function public.admin_publish_gear_quest(
  p_title text,p_description text,p_goals jsonb,p_duration_hours double precision,p_reward_sap double precision,p_reward_resin double precision,
  p_reward_acorns bigint,p_reward_rings bigint,p_reward_amber bigint,p_first_bonus_sap double precision,p_first_bonus_resin double precision,
  p_first_bonus_acorns bigint,p_first_bonus_rings bigint,p_first_bonus_amber bigint,p_reward_gear uuid,p_first_bonus_gear uuid,
  p_reward_boost jsonb default null,p_first_bonus_boost jsonb default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare quest_id uuid; reward_items jsonb:='[]'::jsonb; bonus_items jsonb:='[]'::jsonb;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_reward_boost is not null and (p_reward_boost->>'type' not in ('leaf','capacity','amplifier') or coalesce((p_reward_boost->>'mult')::double precision,0)<=1 or coalesce((p_reward_boost->>'mult')::double precision,101)>100 or coalesce((p_reward_boost->>'duration')::double precision,0)<=0 or coalesce((p_reward_boost->>'duration')::double precision,604801)>604800) then raise exception 'Invalid boost reward'; end if;
  if p_first_bonus_boost is not null and (p_first_bonus_boost->>'type' not in ('leaf','capacity','amplifier') or coalesce((p_first_bonus_boost->>'mult')::double precision,0)<=1 or coalesce((p_first_bonus_boost->>'mult')::double precision,101)>100 or coalesce((p_first_bonus_boost->>'duration')::double precision,0)<=0 or coalesce((p_first_bonus_boost->>'duration')::double precision,604801)>604800) then raise exception 'Invalid first finisher boost'; end if;
  if p_reward_gear is not null then select jsonb_build_array(jsonb_build_object('name',name,'slot',slot,'hp',hp,'attack',attack,'defense',defense)) into reward_items from public.quest_gear where id=p_reward_gear; if reward_items is null then raise exception 'Reward gear not found'; end if; end if;
  if p_first_bonus_gear is not null then select jsonb_build_array(jsonb_build_object('name',name,'slot',slot,'hp',hp,'attack',attack,'defense',defense)) into bonus_items from public.quest_gear where id=p_first_bonus_gear; if bonus_items is null then raise exception 'Bonus gear not found'; end if; end if;
  quest_id:=public.admin_publish_live_challenge(p_title,p_description,p_goals,p_duration_hours,p_reward_sap,p_reward_resin,p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_sap,p_first_bonus_resin,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber);
  update public.live_challenges set reward_gear=reward_items,first_bonus_gear=bonus_items,reward_boost=coalesce(p_reward_boost,'null'::jsonb),first_bonus_boost=coalesce(p_first_bonus_boost,'null'::jsonb) where id=quest_id;
  return quest_id;
end; $$;
revoke all on function public.get_live_challenges(uuid),public.claim_live_challenge(uuid,uuid,text,jsonb),public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.admin_publish_live_challenge(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint) from public,anon,authenticated;
grant execute on function public.get_live_challenges(uuid),public.claim_live_challenge(uuid,uuid,text,jsonb) to anon,authenticated;
grant execute on function public.admin_publish_gear_quest(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint,uuid,uuid,jsonb,jsonb) to authenticated;
grant execute on function public.admin_publish_live_challenge(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
