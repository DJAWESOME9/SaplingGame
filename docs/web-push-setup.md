# Web push setup

Web push does not require Apple Developer membership or an app-store listing.
Supabase Edge Functions include 500,000 monthly invocations on the Free plan;
Pro includes 2 million, then usage beyond its quota is billed. Supabase also
requires an active project plan for the project's database/runtime, so check
the existing project's billing before assuming the total service is free.

## One-time setup

1. In Supabase SQL Editor, run [`../supabase/web_push.sql`](../supabase/web_push.sql).
2. Generate a VAPID key pair with `npx web-push generate-vapid-keys`. Treat the
   private key as a secret; do not commit it or paste it into the game.
3. Set these Supabase Edge Function secrets (Dashboard → Edge Functions →
   Secrets, or `supabase secrets set`):

   - `VAPID_PUBLIC_KEY`
   - `VAPID_PRIVATE_KEY`
   - `VAPID_SUBJECT` (a contact such as `mailto:you@example.com`)
   - `PUSH_ADMIN_TOKEN` (a long random value kept only by the operator)
   - `SITE_URL` (the deployed game origin, e.g. `https://example.github.io`; used to restrict notification click destinations)

4. Deploy `supabase/functions/sapling-push` to the existing project. For
   example, from the repository root: `supabase functions deploy sapling-push`.
5. Copy the VAPID **public** key to `vapidPublicKey` in `leaderboard-config.js`
   and deploy the site. This is public client configuration; never put the
   private key or admin token there.
6. Players install Sapling (required on iPhone/iPad), open Settings, and choose
   **Enable notifications**. Permission is requested only after that tap.

The function accepts `subscribe` and `unsubscribe` from the game using the
existing public Supabase key. Sending requires the `send` action plus the
`x-push-admin-token` secret header, so never add an announcement form to the
public game. Example operator request (use the project's public anon key in
both headers and keep the admin token private):

```sh
curl 'https://PROJECT_REF.supabase.co/functions/v1/sapling-push' \
  -H 'apikey: PUBLIC_ANON_KEY' \
  -H 'Authorization: Bearer PUBLIC_ANON_KEY' \
  -H 'x-push-admin-token: PUSH_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  --data '{"action":"send","title":"News from the grove","body":"A new Sapling update is available."}'
```

The sender removes subscriptions when push providers report them expired. Keep
notifications occasional and useful; users can unsubscribe from the game
Settings or revoke permission in their browser/device settings.
