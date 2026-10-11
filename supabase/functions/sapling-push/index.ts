import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info, x-push-admin-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (request.method !== 'POST') return respond({ error: 'POST required' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const adminToken = Deno.env.get('PUSH_ADMIN_TOKEN');
  const vapidPublic = Deno.env.get('VAPID_PUBLIC_KEY');
  const vapidPrivate = Deno.env.get('VAPID_PRIVATE_KEY');
  const vapidSubject = Deno.env.get('VAPID_SUBJECT') || 'mailto:support@sapling.game';
  if (!url || !serviceKey || !adminToken || !vapidPublic || !vapidPrivate) return respond({ error: 'Push service is not configured' }, 503);

  const db = createClient(url, serviceKey, { auth: { persistSession: false } });
  try {
    const payload = await request.json();
    // Supabase gateway JWT verification is enabled for this function. The VAPID
    // public key is public by design; serving it here avoids putting it in source.
    if (payload.action === 'publicKey') return respond({ publicKey: vapidPublic });
    if (payload.action === 'send') {
      if (request.headers.get('x-push-admin-token') !== adminToken) return respond({ error: 'Not authorized' }, 401);
      const title = String(payload.title || '').trim().slice(0, 80);
      const body = String(payload.body || '').trim().slice(0, 240);
      const targetUrl = String(payload.url || './');
      const siteUrl = new URL(Deno.env.get('SITE_URL') || 'https://sapling-game.invalid');
      let parsedTarget: URL;
      try { parsedTarget = new URL(targetUrl, siteUrl); }
      catch { return respond({ error: 'Invalid notification URL' }, 400); }
      if (!title || !body || parsedTarget.origin !== siteUrl.origin) return respond({ error: 'Provide a title, message, and same-site path' }, 400);
      const { data: rows, error } = await db.from('web_push_subscriptions').select('endpoint_hash,subscription');
      if (error) throw error;
      webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate);
      let sent = 0, removed = 0, failed = 0;
      const message = JSON.stringify({ title, body, url: parsedTarget.href, tag: `sapling-${Date.now()}` });
      for (const row of rows || []) {
        try { await webpush.sendNotification(row.subscription, message); sent++; }
        catch (error) {
          if (error?.statusCode === 404 || error?.statusCode === 410) {
            await db.from('web_push_subscriptions').delete().eq('endpoint_hash', row.endpoint_hash); removed++;
          } else failed++;
        }
      }
      return respond({ sent, removed, failed, total: rows?.length || 0 });
    }

    const playerId = String(payload.playerId || '');
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(playerId)) return respond({ error: 'Invalid player id' }, 400);
    const subscription = payload.subscription;
    const endpoint = typeof subscription?.endpoint === 'string' ? subscription.endpoint : '';
    if (payload.action === 'subscribe') {
      if (!endpoint.startsWith('https://') || endpoint.length > 4096) return respond({ error: 'Invalid subscription endpoint' }, 400);
      const { error } = await db.rpc('store_web_push_subscription', { p_player_id: playerId, p_endpoint: endpoint, p_subscription: subscription });
      if (error) throw error;
      return respond({ ok: true });
    }
    if (payload.action === 'unsubscribe') {
      if (!endpoint.startsWith('https://')) return respond({ error: 'Invalid subscription endpoint' }, 400);
      const { error } = await db.rpc('delete_web_push_subscription', { p_player_id: playerId, p_endpoint: endpoint });
      if (error) throw error;
      return respond({ ok: true });
    }
    return respond({ error: 'Unknown action' }, 400);
  } catch (error) {
    console.error('sapling-push:', error?.message || error);
    return respond({ error: 'Push request failed' }, 500);
  }
});
