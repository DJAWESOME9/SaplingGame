-- Private full-game saves, separate from public leaderboard profiles.
create table if not exists public.cloud_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0),
  save_code text not null check (length(save_code) between 1 and 4000000),
  updated_at timestamptz not null default now()
);
alter table public.cloud_saves enable row level security;
revoke all on public.cloud_saves from anon;
grant select, insert, update on public.cloud_saves to authenticated;
drop policy if exists cloud_save_read on public.cloud_saves;
create policy cloud_save_read on public.cloud_saves for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists cloud_save_insert on public.cloud_saves;
create policy cloud_save_insert on public.cloud_saves for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists cloud_save_update on public.cloud_saves;
create policy cloud_save_update on public.cloud_saves for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create or replace function public.write_cloud_save(expected_revision bigint, new_save_code text)
returns bigint language plpgsql security invoker set search_path = '' as $$
declare next_revision bigint;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if expected_revision is null or expected_revision < 0 then raise exception 'Invalid revision'; end if;
  if expected_revision = 0 then
    insert into public.cloud_saves(user_id, save_code) values (auth.uid(), new_save_code)
      on conflict (user_id) do nothing returning revision into next_revision;
  else
    update public.cloud_saves set save_code = new_save_code, revision = revision + 1, updated_at = now()
      where user_id = auth.uid() and revision = expected_revision returning revision into next_revision;
  end if;
  return next_revision;
end;
$$;
revoke all on function public.write_cloud_save(bigint, text) from public, anon;
grant execute on function public.write_cloud_save(bigint, text) to authenticated;
