# Online leaderboard setup

Sapling's optional leaderboard uses Supabase's free Postgres and REST API. The game remains playable without a Supabase project; the panel appears in Settings and reports that it is not configured.

## Configure Supabase

1. Create a Supabase project and open **SQL Editor**.
2. Run [`../supabase/leaderboard.sql`](../supabase/leaderboard.sql).
3. Copy the project's URL and **anon/public key** from Project Settings → API. Never put a `service_role` key in the game.
4. Before the existing Sapling script in `index.html`, add this configuration:

   ```html
   <script>
     window.SAPLING_LEADERBOARD = {
       url: 'https://YOUR-PROJECT.supabase.co',
       anonKey: 'YOUR_PUBLIC_ANON_KEY'
     };
   </script>
   ```

5. Publish the updated `index.html` to GitHub Pages. Open Settings, enter a display name, and select a category. The five boards rank lifetime sap made, lifetime resin made, highest sap production, highest resin production, and gold leaves clicked. Scores submit when a tree is cut; use **Refresh leaderboard** to reload the selected board.

Each browser receives a random local player ID. The client hides submissions for saves marked as hacked or Blight. The database function keeps each submitted personal best from decreasing. Peak production values are measured per second and shown as rates.

## Trust and privacy

This is a casual leaderboard, not a secure competition. A static browser game cannot prove a claimed score; a modified client can call the public function directly and invent a score or ID. The SQL limits writes to one row per submitted ID and strips most punctuation from names, but it does not cryptographically verify gameplay. Do not use scores for prizes or publish personal information. Supabase's free projects can pause after inactivity, so the first request after a pause may be unavailable until the project resumes.
