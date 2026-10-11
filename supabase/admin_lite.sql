-- Apply after live challenge and quest gear setup. Read-only shared-code access.
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

-- This narrowly scoped definer validates the code before reading private data.
-- No player IDs, profiles, credentials, or mutation endpoints are returned.
create or replace function private.sapling_lite_catalog(p_login text, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare stored_hash text;
begin
  if p_login is null or p_code is null or length(p_login) > 100
    or length(p_code) not between 1 and 72 then
    raise exception 'Invalid Admin Lite login or code';
  end if;
  select code_hash into stored_hash from private.sapling_lite_credentials
    where login = lower(trim(p_login));
  if stored_hash is null or extensions.crypt(p_code, stored_hash) <> stored_hash then
    raise exception 'Invalid Admin Lite login or code';
  end if;
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
notify pgrst, 'reload schema';
