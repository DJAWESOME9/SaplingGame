-- Apply after admin_lite.sql. Shared 100,000 sap allowance; unused sap does not carry over.
create table if not exists private.sapling_lite_sap_usage (
  login text not null references private.sapling_lite_credentials(login) on delete cascade,
  usage_day date not null,
  sap integer not null check (sap between 1 and 100000),
  primary key (login, usage_day)
);
alter table private.sapling_lite_sap_usage enable row level security;
revoke all on private.sapling_lite_sap_usage from public, anon, authenticated;

-- Only player IDs and display names are exposed for selecting a sap target.
create or replace function private.sapling_lite_sap_status(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lite_login text; today date := (now() at time zone 'America/New_York')::date;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  return jsonb_build_object(
    'remaining', 100000 - coalesce((select sap from private.sapling_lite_sap_usage
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
declare lite_login text; today date := (now() at time zone 'America/New_York')::date;
  used integer; action_id uuid;
begin
  lite_login := private.sapling_lite_login(p_login, p_code);
  if p_player_id is null or not exists (select 1 from public.player_profiles where player_id = p_player_id) then
    raise exception 'Player not found';
  end if;
  if p_amount is null or p_amount not between 1 and 100000 then
    raise exception 'Sap amount must be a whole number between 1 and 100,000';
  end if;
  -- Atomic upsert serializes concurrent requests across tabs/devices.
  insert into private.sapling_lite_sap_usage as usage (login, usage_day, sap)
    values (lite_login, today, p_amount)
    on conflict (login, usage_day) do update set sap = usage.sap + p_amount
      where usage.sap + p_amount <= 100000
    returning sap into used;
  if used is null then raise exception 'Daily limit reached: Admin Lite can give 100,000 sap per day'; end if;
  insert into public.admin_actions (player_id, action_type, sap_delta, message)
    values (p_player_id, 'balance', p_amount, 'A sap gift from Admin Lite.') returning id into action_id;
  return jsonb_build_object('action_id', action_id, 'remaining', 100000 - used,
    'resets_at', (today + 1)::timestamp at time zone 'America/New_York');
end; $$;
revoke all on function private.sapling_lite_queue_sap(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function private.sapling_lite_queue_sap(text,text,uuid,integer) to anon, authenticated;

create or replace function public.admin_lite_sap_status(p_login text, p_code text)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_lite_sap_status(p_login, p_code);
$$;
create or replace function public.admin_lite_queue_sap(p_login text, p_code text, p_player_id uuid, p_amount integer)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.sapling_lite_queue_sap(p_login, p_code, p_player_id, p_amount);
$$;
revoke all on function public.admin_lite_sap_status(text,text),
  public.admin_lite_queue_sap(text,text,uuid,integer) from public, anon, authenticated;
grant execute on function public.admin_lite_sap_status(text,text),
  public.admin_lite_queue_sap(text,text,uuid,integer) to anon, authenticated;
notify pgrst, 'reload schema';
