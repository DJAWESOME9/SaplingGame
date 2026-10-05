# Online leaderboard setup

Sapling's optional leaderboard uses Supabase's free Postgres and REST API. The game remains playable without a Supabase project; the panel appears in Settings and reports that it is not configured.

## Configure Supabase

1. Create a Supabase project and open **SQL Editor**.
2. Run [`../supabase/leaderboard.sql`](../supabase/leaderboard.sql).
3. Copy the project's URL and **anon/public key** from Project Settings → API. Never put a `service_role` key in the game.
4. Edit [`../leaderboard-config.js`](../leaderboard-config.js) and set the project URL and **anon/public** key. This file is loaded by both the game and admin dashboard. Never put a `service_role` key in it.
5. The migration allowlists `djdavidfreeman@gmail.com` for admin access. Open `admin.html`, create/sign in to a Supabase Auth account with that email, and confirm the email if Supabase prompts you.
6. Publish the repository root to GitHub Pages. Players open Settings, enter a display name, and select a category. The five boards rank lifetime sap made, lifetime resin made, highest sap production, highest resin production, and gold leaves clicked. Scores submit when a tree is cut; use **Refresh leaderboard** to reload the selected board.

Each browser receives a random local player ID. The client hides leaderboard submissions for saves marked as hacked or Blight. The database function keeps each submitted personal best from decreasing. Peak production values are measured per second and shown as rates.

## Admin player controls

Open `admin.html` and sign in with the Supabase Auth account you allowlisted. Admins can search and inspect player profiles, including current balances, per-tree and lifetime production, peak rates, gold leaves, playtime, offline time, tree count, rings, species, node count, and last check-in. The dashboard can queue sap/resin grants or deductions and reset a player's progress.

Sapling has no account system or cloud saves today. The player ID is stored in that browser's local storage, so a row represents a browser profile, not a verified person or a synced cross-device account. Online play reports a profile roughly once per minute. Balance changes and resets are picked up on the next check-in; the player must have the game open and online. A reset clears that browser's run and meta progression and zeros its recorded leaderboard/profile metrics. It cannot erase other browsers' local saves for the same person.

Admin pages are protected by Supabase Auth and the `admin_users` database allowlist. A link to `admin.html` is visible in Settings, but it grants no access by itself. The anonymous/public API key in `leaderboard-config.js` is not an admin secret. Do not add a service-role key to client files.

## Trust and privacy

This is a casual leaderboard and support tool, not a secure competition. A static browser game cannot prove a claimed score or telemetry; a modified client can invent profile values or player IDs. The SQL strips most punctuation from names but does not cryptographically verify gameplay. Do not use scores for prizes or publish personal information. Supabase's free projects can pause after inactivity, so the first request after a pause may be unavailable until the project resumes.
