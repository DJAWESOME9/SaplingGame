-- Sapling leaderboard setup for a Supabase project.
-- Run this once in Supabase Dashboard → SQL Editor.

create table if not exists public.leaderboard (
  player_id uuid primary key,
  display_name text not null check (char_length(display_name) between 1 and 20),
  lifetime_sap double precision not null default 0 check (lifetime_sap >= 0),
  lifetime_resin double precision not null default 0 check (lifetime_resin >= 0),
  highest_sap double precision not null default 0 check (highest_sap >= 0),
  highest_resin double precision not null default 0 check (highest_resin >= 0),
  gold_leaves bigint not null default 0 check (gold_leaves >= 0),
  updated_at timestamptz not null default now()
);

alter table public.leaderboard enable row level security;
revoke all on public.leaderboard from anon, authenticated;
grant select on public.leaderboard to anon, authenticated;

drop policy if exists "Leaderboard is public to read" on public.leaderboard;
create policy "Leaderboard is public to read"
  on public.leaderboard for select to anon, authenticated using (true);

create or replace function public.submit_leaderboard_score(
  p_player_id uuid,
  p_display_name text,
  p_lifetime_sap double precision,
  p_lifetime_resin double precision,
  p_highest_sap double precision,
  p_highest_resin double precision,
  p_gold_leaves bigint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_name text;
begin
  if p_player_id is null or p_lifetime_sap is null or p_lifetime_resin is null
     or p_highest_sap is null or p_highest_resin is null or p_gold_leaves is null
     or p_lifetime_sap < 0 or p_lifetime_resin < 0 or p_highest_sap < 0
     or p_highest_resin < 0 or p_gold_leaves < 0 then
    raise exception 'Invalid score';
  end if;
  clean_name := left(regexp_replace(coalesce(p_display_name, ''), '[^[:alnum:] _.-]', '', 'g'), 20);
  if clean_name = '' then clean_name := 'Sapling'; end if;

  insert into public.leaderboard (
    player_id, display_name, lifetime_sap, lifetime_resin,
    highest_sap, highest_resin, gold_leaves
  ) values (
    p_player_id, clean_name, p_lifetime_sap, p_lifetime_resin,
    p_highest_sap, p_highest_resin, p_gold_leaves
  )
  on conflict (player_id) do update
    set display_name = excluded.display_name,
        lifetime_sap = greatest(public.leaderboard.lifetime_sap, excluded.lifetime_sap),
        lifetime_resin = greatest(public.leaderboard.lifetime_resin, excluded.lifetime_resin),
        highest_sap = greatest(public.leaderboard.highest_sap, excluded.highest_sap),
        highest_resin = greatest(public.leaderboard.highest_resin, excluded.highest_resin),
        gold_leaves = greatest(public.leaderboard.gold_leaves, excluded.gold_leaves),
        updated_at = now();
end;
$$;

revoke all on function public.submit_leaderboard_score(uuid, text, double precision, double precision, double precision, double precision, bigint) from public;
grant execute on function public.submit_leaderboard_score(uuid, text, double precision, double precision, double precision, double precision, bigint) to anon, authenticated;

-- This is a casual community leaderboard, not cheat-proof: anonymous clients
-- can still invent player IDs or claim scores. Do not treat scores as prizes.
