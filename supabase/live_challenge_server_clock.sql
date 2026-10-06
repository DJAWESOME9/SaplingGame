-- Return database time with active challenges so browser timers and progress
-- windows stay aligned with the server-issued open/close timestamps.
drop function if exists public.get_live_challenges(uuid);
create function public.get_live_challenges(p_player_id uuid)
returns table(
  id uuid, title text, description text, target_sap double precision, target_type text,
  opens_at timestamptz, closes_at timestamptz,
  reward_sap double precision, reward_resin double precision,
  first_bonus_sap double precision, first_bonus_resin double precision,
  first_finisher text, completion_count bigint, player_completed boolean,
  server_now timestamptz
)
language sql stable security definer set search_path = '' as $$
  select c.id, c.title, c.description, c.target_sap, c.target_type, c.opens_at, c.closes_at,
    c.reward_sap, c.reward_resin, c.first_bonus_sap, c.first_bonus_resin,
    (select x.display_name from public.live_challenge_completions x
      where x.challenge_id = c.id and x.is_first limit 1),
    (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id),
    exists(select 1 from public.live_challenge_completions x
      where x.challenge_id = c.id and x.player_id = p_player_id),
    now()
  from public.live_challenges c
  where c.ended_at is null and c.opens_at <= now() and c.closes_at > now()
  order by c.opens_at desc;
$$;
revoke all on function public.get_live_challenges(uuid) from public, anon, authenticated;
grant execute on function public.get_live_challenges(uuid) to anon, authenticated;
