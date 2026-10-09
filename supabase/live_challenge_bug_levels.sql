-- Apply after live_challenge_goals.sql (safe before or after quest_gear.sql).
-- Add current-ownership level goals without replacing quests or completion history.
begin;
alter table public.live_challenges drop constraint if exists live_challenges_target_type_check;
alter table public.live_challenges add constraint live_challenges_target_type_check
  check (target_type in ('banked_sap', 'sap', 'leaf_sap', 'oak_sap', 'apple_sap', 'peach_sap', 'grape_sap', 'maple_sap', 'pine_sap', 'chocolate_sap', 'resin', 'refinery_resin', 'channel', 'expeditions', 'amber', 'rings', 'bugs', 'bug_level'));

create or replace function public.admin_publish_live_challenge(
  p_title text, p_description text, p_goals jsonb, p_duration_hours double precision,
  p_reward_sap double precision, p_reward_resin double precision,
  p_reward_acorns bigint, p_reward_rings bigint, p_reward_amber bigint,
  p_first_bonus_sap double precision, p_first_bonus_resin double precision,
  p_first_bonus_acorns bigint, p_first_bonus_rings bigint, p_first_bonus_amber bigint
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid; clean_title text;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  clean_title := left(trim(coalesce(p_title, '')), 60);
  if clean_title = '' or char_length(trim(coalesce(p_description, ''))) not between 1 and 240
    or p_goals is null or jsonb_typeof(p_goals) <> 'array' or jsonb_array_length(p_goals) < 1 or jsonb_array_length(p_goals) > 8
    or exists (select 1 from jsonb_array_elements(p_goals) g where (g->>'type') is null or (g->>'type') not in ('sap', 'leaf_sap', 'oak_sap', 'apple_sap', 'peach_sap', 'grape_sap', 'maple_sap', 'pine_sap', 'chocolate_sap', 'resin', 'refinery_resin', 'channel', 'expeditions', 'amber', 'rings', 'bugs', 'bug_level') or (g->>'target') is null or (g->>'target')::double precision <= 0 or (g->>'target')::double precision > 1e100 or ((g->>'type') in ('expeditions', 'amber', 'rings', 'bugs', 'bug_level') and (g->>'target')::double precision <> floor((g->>'target')::double precision)))
    or exists (select 1 from jsonb_array_elements(p_goals) g where g->>'type' = 'bug_level' and
      (jsonb_typeof(g->'level') is distinct from 'number' or (g->>'level')::double precision < 1
        or (g->>'level')::double precision > 100 or (g->>'level')::double precision <> floor((g->>'level')::double precision)))
    or p_duration_hours is null or p_duration_hours <= 0 or p_duration_hours > 8760
    or p_reward_sap is null or p_reward_resin is null or p_first_bonus_sap is null or p_first_bonus_resin is null
    or p_reward_acorns is null or p_reward_rings is null or p_reward_amber is null
    or p_first_bonus_acorns is null or p_first_bonus_rings is null or p_first_bonus_amber is null
    or least(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin,
      p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber) < 0
    or greatest(p_reward_sap,p_reward_resin,p_first_bonus_sap,p_first_bonus_resin,
      p_reward_acorns,p_reward_rings,p_reward_amber,p_first_bonus_acorns,p_first_bonus_rings,p_first_bonus_amber) > 1e12 then
    raise exception 'Invalid challenge details';
  end if;
  insert into public.live_challenges(title, description, target_sap, target_type, goals, opens_at, closes_at,
    reward_sap, reward_resin, reward_acorns, reward_rings, reward_amber,
    first_bonus_sap, first_bonus_resin, first_bonus_acorns, first_bonus_rings, first_bonus_amber)
  values(clean_title, trim(p_description), (p_goals->0->>'target')::double precision, p_goals->0->>'type', p_goals, now(),
    now() + make_interval(secs => p_duration_hours * 3600),
    p_reward_sap, p_reward_resin, p_reward_acorns, p_reward_rings, p_reward_amber,
    p_first_bonus_sap, p_first_bonus_resin, p_first_bonus_acorns, p_first_bonus_rings, p_first_bonus_amber)
  returning id into new_id;
  return new_id;
end; $$;

-- Keep publishing admin-only, including calls delegated by the gear publisher.
revoke all on function public.admin_publish_live_challenge(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint) from public, anon, authenticated;
grant execute on function public.admin_publish_live_challenge(text,text,jsonb,double precision,double precision,double precision,bigint,bigint,bigint,double precision,double precision,bigint,bigint,bigint) to authenticated;
commit;
