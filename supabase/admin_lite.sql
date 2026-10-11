-- Apply after live challenge, quest gear, and admin_weather.sql setup.
-- Shared-code catalog access plus three lightning strikes per Eastern calendar day.
-- The bcrypt hash is intentionally used instead of storing the access code.
create schema if not exists private;
create table if not exists private.sapling_lite_credentials (
  login text primary key,
  code_hash text not null
);
alter table private.sapling_lite_credentials enable row level security;
revoke all on private.sapling_lite_credentials from public, anon, authenticated;
insert into private.sapling_lite_credentials(login, code_hash)
values ('adminlite', '$2a$10$rf.ugv6.7FBh.PqXEfQwZ.5L4qklnj4TnoxH2aMzbDH5K3OsjTEA2')
on conflict (login) do nothing;

create table if not exists private.sapling_lite_lightning_usage (
  login text not null references private.sapling_lite_credentials(login) on delete cascade,
  usage_day date not null,
  strikes integer not null check (strikes between 1 and 3),
  primary key (login, usage_day)
);
alter table private.sapling_lite_lightning_usage enable row level security;
revoke all on private.sapling_lite_lightning_usage from public, anon, authenticated;

-- Shared-code authorization is independent of full administrator Auth/allowlisting.
create or replace function private.sapling_lite_login(p_login text, p_code text)
returns text language plpgsql security definer set search_path = '' as $$
declare stored_hash text; normalized_login text := lower(trim(p_login));
begin
  if p_login is null or p_code is null or length(p_login) > 100
    or length(p_code) not between 1 and 72 then
    raise exception 'Invalid Admin Lite login or code';
  end if;
  select code_hash into stored_hash from private.sapling_lite_credentials
    where login = normalized_login;
  if stored_hash is null or extensions.crypt(p_code, stored_hash) <> stored_hash then
    raise exception 'Invalid Admin Lite login or code';
  end if;
  return normalized_login;
end; $$;
revoke all on function private.sapling_lite_login(text,text) from public, anon, authenticated;

-- This catalog returns no private profile stats or credentials.
create or replace function private.sapling_lite_catalog(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform private.sapling_lite_login(p_login, p_code);
  return jsonb_build_object(
    'challenges', coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object(
      'first_finisher', (select x.display_name from public.live_challenge_completions x
        where x.challenge_id = c.id and x.is_first order by x.completed_at limit 1),
      'completion_count', (select count(*) from public.live_challenge_completions x where x.challenge_id = c.id)
    ) order by c.created_at desc) from public.live_challenges c), '[]'::jsonb),
    'gear', coalesce((select jsonb_agg(to_jsonb(g) order by g.created_at desc) from public.quest_gear g), '[]'::jsonb)
  );
end; $$;
revoke all on function private.sapling_lite_catalog(text,text) from public, anon, authenticated;
grant usage on schema private to anon, authenticated;
grant execute on function private.sapling_lite_catalog(text,text) to anon, authenticated;

create or replace function public.admin_lite_catalog(p_login text, p_code text)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_lite_catalog(p_login, p_code);
$$;
revoke all on function public.admin_lite_catalog(text,text) from public, anon, authenticated;
grant execute on function public.admin_lite_catalog(text,text) to anon, authenticated;
-- Only player IDs and display names are exposed for selecting a lightning target.
create or replace function private.sapling_lite_lightning_status(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  return jsonb_build_object(
    'remaining', 3 - coalesce((select strikes from private.sapling_lite_lightning_usage
      where login = lite_login and usage_day = today), 0),
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York',
    'players', coalesce((select jsonb_agg(jsonb_build_object('player_id', player_id,
      'display_name', display_name) order by lower(display_name), player_id)
      from public.player_profiles), '[]'::jsonb)
  );
end; $$;
revoke all on function private.sapling_lite_lightning_status(text,text) from public, anon, authenticated;
grant execute on function private.sapling_lite_lightning_status(text,text) to anon, authenticated;

create or replace function private.sapling_lite_queue_lightning(p_login text, p_code text, p_player_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date;
  used integer; action_id uuid;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  -- Atomic upsert serializes concurrent requests across tabs/devices.
  insert into private.sapling_lite_lightning_usage as usage (login, usage_day, strikes)
    values (lite_login, today, 1)
    on conflict (login, usage_day) do update set strikes = usage.strikes + 1
      where usage.strikes < 3
    returning strikes into used;
  if used is null then raise exception 'Daily limit reached: Admin Lite can send 3 lightning strikes per day'; end if;
  insert into public.admin_actions (player_id, action_type, weather_level)
    values (p_player_id, 'lightning', 1) returning id into action_id;
  return jsonb_build_object('action_id', action_id, 'remaining', 3 - used,
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York');
end; $$;
revoke all on function private.sapling_lite_queue_lightning(text,text,uuid) from public, anon, authenticated;
grant execute on function private.sapling_lite_queue_lightning(text,text,uuid) to anon, authenticated;

create or replace function public.admin_lite_lightning_status(p_login text, p_code text)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_lite_lightning_status(p_login, p_code);
$$;
create or replace function public.admin_lite_queue_lightning(p_login text, p_code text, p_player_id uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_lite_queue_lightning(p_login, p_code, p_player_id);
$$;
revoke all on function public.admin_lite_lightning_status(text,text),
  public.admin_lite_queue_lightning(text,text,uuid) from public, anon, authenticated;
grant execute on function public.admin_lite_lightning_status(text,text),
  public.admin_lite_queue_lightning(text,text,uuid) to anon, authenticated;
notify pgrst, 'reload schema';
