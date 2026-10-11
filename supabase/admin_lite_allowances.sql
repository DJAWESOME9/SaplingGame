-- Apply after admin_lite_sap_removal.sql. Extra allowance expires at midnight Eastern.
begin;
create table if not exists private.sapling_lite_allowance_grants (
  login text not null references private.sapling_lite_credentials(login) on delete cascade,
  usage_day date not null,
  kind text not null check (kind in ('sap', 'sap_removal', 'lightning')),
  amount integer not null check (amount between 1 and 1000000000),
  primary key (login, usage_day, kind)
);
alter table private.sapling_lite_allowance_grants enable row level security;
revoke all on private.sapling_lite_allowance_grants from public, anon, authenticated;

create or replace function private.sapling_lite_daily_limit(p_login text, p_kind text, p_day date)
returns integer language sql security invoker set search_path = '' as $$
  select (case when p_kind = 'lightning' then 3 else 100000 end) +
    coalesce((select amount from private.sapling_lite_allowance_grants
      where login = p_login and kind = p_kind and usage_day = p_day), 0);
$$;
revoke all on function private.sapling_lite_daily_limit(text,text,date) from public, anon, authenticated;

create or replace function private.sapling_admin_lite_allowances()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare today date := (now() at time zone 'America/New_York')::date;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  return jsonb_build_object('resets_at', (today + 1)::timestamp at time zone 'America/New_York',
    'allowances', coalesce((select jsonb_agg(jsonb_build_object(
      'login', c.login, 'kind', k.kind,
      'total', private.sapling_lite_daily_limit(c.login, k.kind, today),
      'remaining', private.sapling_lite_daily_limit(c.login, k.kind, today) -
        case k.kind
          when 'sap' then coalesce((select sap from private.sapling_lite_sap_usage where login=c.login and usage_day=today),0)
          when 'sap_removal' then coalesce((select sap from private.sapling_lite_sap_removal_usage where login=c.login and usage_day=today),0)
          else coalesce((select strikes from private.sapling_lite_lightning_usage where login=c.login and usage_day=today),0)
        end
    ) order by c.login, k.kind) from private.sapling_lite_credentials c
      cross join (values ('sap'), ('sap_removal'), ('lightning')) k(kind)), '[]'::jsonb));
end; $$;
revoke all on function private.sapling_admin_lite_allowances() from public, anon, authenticated;
grant execute on function private.sapling_admin_lite_allowances() to authenticated;

create or replace function private.sapling_admin_grant_lite_allowance(p_login text, p_kind text, p_amount integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare today date := (now() at time zone 'America/New_York')::date;
  lite_login text := lower(trim(p_login)); added integer;
begin
  if not public.is_sapling_admin() then raise exception 'Administrator access required'; end if;
  if p_kind is null or p_kind not in ('sap', 'sap_removal', 'lightning')
    or p_amount is null or p_amount not between 1 and 1000000000 then
    raise exception 'Choose an allowance and a positive whole amount up to 1,000,000,000';
  end if;
  if lite_login is null or not exists (select 1 from private.sapling_lite_credentials where login=lite_login) then
    raise exception 'Admin Lite login not found';
  end if;
  insert into private.sapling_lite_allowance_grants as g (login, usage_day, kind, amount)
    values (lite_login, today, p_kind, p_amount)
    on conflict (login, usage_day, kind) do update set amount = g.amount + p_amount
      where g.amount::bigint + p_amount <= 1000000000
    returning amount into added;
  if added is null then raise exception 'Extra allowance cannot exceed 1,000,000,000 per type per day'; end if;
  return private.sapling_admin_lite_allowances();
end; $$;
revoke all on function private.sapling_admin_grant_lite_allowance(text,text,integer) from public, anon, authenticated;
grant execute on function private.sapling_admin_grant_lite_allowance(text,text,integer) to authenticated;

create or replace function public.admin_lite_allowances()
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_admin_lite_allowances();
$$;
create or replace function public.admin_grant_lite_allowance(p_login text, p_kind text, p_amount integer)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_admin_grant_lite_allowance(p_login, p_kind, p_amount);
$$;
revoke all on function public.admin_lite_allowances(), public.admin_grant_lite_allowance(text,text,integer) from public, anon, authenticated;
grant execute on function public.admin_lite_allowances(), public.admin_grant_lite_allowance(text,text,integer) to authenticated;

alter table private.sapling_lite_sap_usage drop constraint if exists sapling_lite_sap_usage_sap_check;
alter table private.sapling_lite_sap_usage add constraint sapling_lite_sap_usage_sap_check check (sap between 1 and 1000100000);
create or replace function private.sapling_lite_sap_status(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'sap', today);
  return jsonb_build_object(
    'total', daily_limit, 'remaining', daily_limit - coalesce((select sap from private.sapling_lite_sap_usage
      where login = lite_login and usage_day = today), 0),
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York',
    'players', coalesce((select jsonb_agg(jsonb_build_object('player_id', player_id,
      'display_name', display_name) order by lower(display_name), player_id)
      from public.player_profiles), '[]'::jsonb)
  );
end; $$;
revoke all on function private.sapling_lite_sap_status(text,text) from public, anon, authenticated;
grant execute on function private.sapling_lite_sap_status(text,text) to anon, authenticated;

create or replace function private.sapling_lite_queue_sap(p_login text, p_code text, p_player_id uuid, p_amount integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
  used integer; action_id uuid;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'sap', today);
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  if p_amount is null or p_amount not between 1 and daily_limit then
    raise exception 'Sap amount must be a positive whole number within today’s allowance';
  end if;
  -- Atomic upsert serializes concurrent requests across tabs/devices.
  insert into private.sapling_lite_sap_usage as usage (login, usage_day, sap)
    values (lite_login, today, p_amount)
    on conflict (login, usage_day) do update set sap = usage.sap + p_amount
      where usage.sap + p_amount <= daily_limit
    returning sap into used;
  if used is null then raise exception 'Daily sap gift allowance reached'; end if;
  insert into public.admin_actions (player_id, action_type, sap_delta, message)
    values (p_player_id, 'balance', p_amount, 'A sap gift from Admin Lite.') returning id into action_id;
  return jsonb_build_object('action_id', action_id, 'total', daily_limit, 'remaining', daily_limit - used,
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York');
end; $$;
revoke all on function private.sapling_lite_queue_sap(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function private.sapling_lite_queue_sap(text,text,uuid,integer) to anon, authenticated;


alter table private.sapling_lite_sap_removal_usage drop constraint if exists sapling_lite_sap_removal_usage_sap_check;
alter table private.sapling_lite_sap_removal_usage add constraint sapling_lite_sap_removal_usage_sap_check check (sap between 1 and 1000100000);
create or replace function private.sapling_lite_sap_removal_status(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'sap_removal', today);
  return jsonb_build_object(
    'total', daily_limit, 'remaining', daily_limit - coalesce((select sap from private.sapling_lite_sap_removal_usage
      where login = lite_login and usage_day = today), 0),
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York',
    'players', coalesce((select jsonb_agg(jsonb_build_object('player_id', player_id,
      'display_name', display_name) order by lower(display_name), player_id)
      from public.player_profiles), '[]'::jsonb)
  );
end; $$;
revoke all on function private.sapling_lite_sap_removal_status(text,text) from public, anon, authenticated;
grant execute on function private.sapling_lite_sap_removal_status(text,text) to anon, authenticated;

create or replace function private.sapling_lite_queue_sap_removal(p_login text, p_code text, p_player_id uuid, p_amount integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
  used integer; action_id uuid;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'sap_removal', today);
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  if p_amount is null or p_amount not between 1 and daily_limit then
    raise exception 'Sap amount must be a positive whole number within today’s allowance';
  end if;
  -- Atomic upsert serializes concurrent requests across tabs/devices.
  insert into private.sapling_lite_sap_removal_usage as usage (login, usage_day, sap)
    values (lite_login, today, p_amount)
    on conflict (login, usage_day) do update set sap = usage.sap + p_amount
      where usage.sap + p_amount <= daily_limit
    returning sap into used;
  if used is null then raise exception 'Daily sap removal allowance reached'; end if;
  insert into public.admin_actions (player_id, action_type, sap_delta, message)
    values (p_player_id, 'balance', -p_amount, 'Sap removed by Admin Lite.') returning id into action_id;
  return jsonb_build_object('action_id', action_id, 'total', daily_limit, 'remaining', daily_limit - used,
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York');
end; $$;
revoke all on function private.sapling_lite_queue_sap_removal(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function private.sapling_lite_queue_sap_removal(text,text,uuid,integer) to anon, authenticated;


alter table private.sapling_lite_lightning_usage drop constraint if exists sapling_lite_lightning_usage_strikes_check;
alter table private.sapling_lite_lightning_usage add constraint sapling_lite_lightning_usage_strikes_check check (strikes between 1 and 1000000003);
create or replace function private.sapling_lite_lightning_status(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'lightning', today);
  return jsonb_build_object(
    'total', daily_limit, 'remaining', daily_limit - coalesce((select strikes from private.sapling_lite_lightning_usage
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
declare lite_login text; today date := (now() at time zone 'America/New_York')::date; daily_limit integer;
  used integer; action_id uuid;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  daily_limit := private.sapling_lite_daily_limit(lite_login, 'lightning', today);
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  -- Atomic upsert serializes concurrent requests across tabs/devices.
  insert into private.sapling_lite_lightning_usage as usage (login, usage_day, strikes)
    values (lite_login, today, 1)
    on conflict (login, usage_day) do update set strikes = usage.strikes + 1
      where usage.strikes < daily_limit
    returning strikes into used;
  if used is null then raise exception 'Daily lightning allowance reached'; end if;
  insert into public.admin_actions (player_id, action_type, weather_level)
    values (p_player_id, 'lightning', 1) returning id into action_id;
  return jsonb_build_object('action_id', action_id, 'total', daily_limit, 'remaining', daily_limit - used,
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York');
end; $$;
revoke all on function private.sapling_lite_queue_lightning(text,text,uuid) from public, anon, authenticated;
grant execute on function private.sapling_lite_queue_lightning(text,text,uuid) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
