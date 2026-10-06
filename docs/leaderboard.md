# Online leaderboard setup

Sapling's optional leaderboard uses Supabase's free Postgres and REST API. The game remains playable without a Supabase project; the leaderboard has its own 🌿 button beside Stats and Achievements.

## Configure Supabase

1. Create a Supabase project and open **SQL Editor**.
2. Run [`../supabase/leaderboard.sql`](../supabase/leaderboard.sql).
3. Run [`../supabase/live_challenges.sql`](../supabase/live_challenges.sql) after the leaderboard setup to enable live challenges.
4. Copy the project's URL and **anon/public key** from Project Settings → API. Never put a `service_role` key in the game.
5. Edit [`../leaderboard-config.js`](../leaderboard-config.js) and set the project URL and **anon/public** key. This file is loaded by both the game and admin dashboard. Never put a `service_role` key in it.
6. The migration allowlists `djdavidfreeman@gmail.com` for admin access. Open `admin.html`, create/sign in to a Supabase Auth account with that email, and confirm the email if Supabase prompts you.
7. Publish the repository root to GitHub Pages. Players enter a display name and select a category. The five boards rank lifetime sap made, lifetime resin made, highest sap balance ever held, highest resin balance ever held, and gold leaves clicked. Scores submit when the game opens, periodically during play, and after a tree is cut. Blight saves can compete and appear with a copper tint; hacked saves are excluded.

Each browser receives a random local player ID. The client hides leaderboard submissions for saves marked as hacked. The database function keeps each submitted personal best from decreasing. Highest balance records persist across tree cuts. Existing saves start their highest balance record from their current balance; older peak production scores remain in separate legacy columns. Install the updated SQL setup to activate the two highest-balance boards. Until then, the game keeps the lifetime and gold-leaf boards updated through the prior submission function and shows a pending message for the balance boards.

## Admin player controls

Open `admin.html` and sign in with the Supabase Auth account you allowlisted. Admins can search and inspect player profiles, including current balances, per-tree and lifetime production, peak rates, gold leaves, playtime, offline time, tree count, rings, species, node count, and last check-in. The dashboard can queue sap/resin grants or deductions and reset a player's progress.

Sapling has no account system or cloud saves today. The player ID is stored in that browser's local storage, so a row represents a browser profile, not a verified person or a synced cross-device account. Online play reports a profile roughly once per minute. Balance changes and resets are picked up on the next check-in; the player must have the game open and online. A reset clears that browser's run and meta progression and zeros its recorded leaderboard/profile metrics. It cannot erase other browsers' local saves for the same person.

Admin pages are protected by Supabase Auth and the `admin_emails` database allowlist. A link to `admin.html` is visible in Settings, but it grants no access by itself. The anonymous/public API key in `leaderboard-config.js` is not an admin secret. Do not add a service-role key to client files.

## Live challenges

After applying `live_challenges.sql`, an allowlisted admin can publish a challenge in `admin.html` with a title, player-facing description, sap target, active duration, base sap/resin reward, and an additional first-finisher bonus. Publishing starts it immediately. Players see active events under Settings → Live Challenges. When their current sap balance reaches the target, the game submits completion automatically. Each completion adds an achievement to the Challenges category and grants the configured in-game reward. Supabase serializes claims per event and awards the additional bonus to the first accepted completion.

Challenge claims use the same browser-reported game state as the leaderboard and are suitable for casual in-game rewards, not cash or other high-value prizes. A modified client can falsify its current sap amount. The database determines which submitted claim arrived first, but it cannot independently verify gameplay in this static browser game.

## Trust and privacy

This is a casual leaderboard and support tool, not a secure competition. A static browser game cannot prove a claimed score or telemetry; a modified client can invent profile values or player IDs. The SQL strips most punctuation from names but does not cryptographically verify gameplay. Do not use scores for prizes or publish personal information. Supabase's free projects can pause after inactivity, so the first request after a pause may be unavailable until the project resumes.
