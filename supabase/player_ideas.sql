-- Run after leaderboard.sql. Private inbox for Settings → Suggest a feature.
create table if not exists public.player_ideas (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null,
  display_name text not null check (char_length(display_name) between 1 and 20),
  idea text not null check (char_length(idea) between 5 and 1000),
  created_at timestamptz not null default now(),
  note_synced_at timestamptz
);
create index if not exists player_ideas_player_created on public.player_ideas (player_id, created_at);
alter table public.player_ideas enable row level security;
revoke all on public.player_ideas from public, anon, authenticated;
grant select on public.player_ideas to authenticated;
drop policy if exists player_ideas_admin_read on public.player_ideas;
create policy player_ideas_admin_read on public.player_ideas
  for select to authenticated using (public.is_sapling_admin());

-- Only this validated endpoint may insert. No public table reads or updates.
create or replace function public.submit_player_idea(p_player_id uuid, p_display_name text, p_idea text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare idea_id uuid;
begin
  if p_player_id is null or char_length(btrim(coalesce(p_idea, ''))) not between 5 and 1000
    or char_length(btrim(coalesce(p_display_name, ''))) not between 1 and 20 then
    raise exception 'Invalid idea';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_player_id::text, 0));
  if exists (select 1 from public.player_ideas where player_id = p_player_id and created_at > now() - interval '1 minute')
    or (select count(*) from public.player_ideas where player_id = p_player_id and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'Idea limit reached';
  end if;
  insert into public.player_ideas (player_id, display_name, idea)
    values (p_player_id, btrim(p_display_name), btrim(p_idea)) returning id into idea_id;
  return idea_id;
end; $$;
revoke all on function public.submit_player_idea(uuid, text, text) from public, anon, authenticated;
grant execute on function public.submit_player_idea(uuid, text, text) to anon, authenticated;
