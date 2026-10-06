# Online leaderboard setup

Sapling's optional leaderboard uses Supabase's free Postgres and REST API. The game remains playable without a Supabase project; the leaderboard has its own 🌿 button beside Stats and Achievements.

## Configure Supabase

1. Create a Supabase project and open **SQL Editor**.
2. Run [`../supabase/leaderboard.sql`](../supabase/leaderboard.sql).
3. Run [`../supabase/live_challenges.sql`](../supabase/live_challenges.sql) after the leaderboard setup to enable live challenges.
4. Run [`../supabase/live_challenge_leaf_sap.sql`](../supabase/live_challenge_leaf_sap.sql) to enable leaf-produced sap goals and real-time event progress.
5. Run [`../supabase/live_challenge_server_clock.sql`](../supabase/live_challenge_server_clock.sql) to return the database clock with active events for countdown alignment.
6. Run [`../supabase/admin_messages.sql`](../supabase/admin_messages.sql) to enable player-facing admin messages. Run this after `leaderboard.sql` on existing projects too.
7. Copy the project's URL and **anon/public key** from Project Settings → API. Never put a `service_role` key in the game.
8. Edit [`../leaderboard-config.js`](../leaderboard-config.js) and set the project URL and **anon/public** key. This file is loaded by both the game and admin dashboard. Never put a `service_role` key in it.
9. The migration allowlists `djdavidfreeman@gmail.com` for admin access. Open `admin.html`, create/sign in to a Supabase Auth account with that email, and confirm the email if Supabase prompts you.
10. Publish the repository root to GitHub Pages. Players enter a display name and select a category. The seven boards rank lifetime sap and resin gained, current sap and resin bank balances, current sap and resin production per second, and gold leaves clicked. Scores submit when the game opens, periodically during play, and after a tree is cut. Blight saves can compete and appear with a copper tint; hacked saves are excluded.

Each browser receives a random local player ID. The client hides leaderboard submissions for saves marked as hacked. The database function keeps lifetime and gold-leaf records from decreasing; current bank balances and production rates update on each submission and can go down. Current rankings show only players who have submitted the relevant values from an updated game. Until they return, their current values are unknown and they are absent from those tabs. Lifetime totals count all positive resource gains, including starting resources, gold leaves, challenge rewards, and admin grants. Existing saves initialize their private production totals from their old lifetime counters and raise earned totals to at least their recorded balance or highest balance. Older unrecorded gains cannot be reconstructed exactly. Historical highest balances persist across tree cuts in separate columns for stats and legacy clients; older peak production rates remain in separate legacy columns. Install the updated SQL setup to activate the current boards; until then, the game keeps the other boards updating through the prior submission function.

## Admin player controls

Open `admin.html` and sign in with the Supabase Auth account you allowlisted. Admins can search and inspect player profiles, including current balances, per-tree and lifetime production, peak rates, gold leaves, playtime, offline time, tree count, rings, species, node count, and last online. Last online is the most recent successful game check-in, separate from the profile's account update time. Existing profiles show “Not recorded yet” until their next check-in after the SQL update. The dashboard can queue sap/resin grants or deductions with an optional message, and reset a player's progress. The recipient sees the applied amount and message in a popup that stays pending until dismissed.

Sapling has no account system or cloud saves today. The player ID is stored in that browser's local storage, so a row represents a browser profile, not a verified person or a synced cross-device account. Online play reports a profile roughly once per minute. Balance changes and resets are picked up on the next check-in; the player must have the game open and online. A reset clears that browser's run and meta progression and zeros its recorded leaderboard/profile metrics. It cannot erase other browsers' local saves for the same person.

Admin pages are protected by Supabase Auth and the `admin_emails` database allowlist. A link to `admin.html` is visible in Settings, but it grants no access by itself. The anonymous/public API key in `leaderboard-config.js` is not an admin secret. Do not add a service-role key to client files.

## Live challenges

After applying both live-challenge SQL files, an allowlisted admin can publish a challenge in `admin.html` with either a banked-sap goal or a leaf-produced-sap goal, duration, base reward, and first-finisher bonus. Publishing starts the clock immediately using Supabase timestamps, so the deadline keeps running while players are offline. Leaf goals count production at leaf nodes (not sap spent or rewards); eligible offline production is included using the game's normal offline rate and cap. Active events appear in the draggable, minimizable HUD bar and under Settings → Live Challenges. Completion adds an achievement to the Challenges category and grants the configured reward. Supabase serializes claims per event and gives the first accepted completion the additional bonus. The player progress meter is local to each browser save; completion eligibility is reported by the browser, so it is not tamper-proof.

Challenge claims use the same browser-reported game state as the leaderboard and are suitable for casual in-game rewards, not cash or other high-value prizes. A modified client can falsify its current sap amount. The database determines which submitted claim arrived first, but it cannot independently verify gameplay in this static browser game.

## Trust and privacy

This is a casual leaderboard and support tool, not a secure competition. A static browser game cannot prove a claimed score or telemetry; a modified client can invent profile values or player IDs. The SQL strips most punctuation from names but does not cryptographically verify gameplay. Do not use scores for prizes or publish personal information. Supabase's free projects can pause after inactivity, so the first request after a pause may be unavailable until the project resumes.
