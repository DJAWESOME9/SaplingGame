/* Bump this name whenever the app shell or its assets change. */
const CACHE_NAME = 'sapling-shell-2026-10-11-4';
const APP_SHELL = ['./', './index.html', './manifest.webmanifest', './bookmark-icon.svg', './favicon.png', './apple-touch-icon.png', './sethatubby.png'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => key.startsWith('sapling-shell-') && key !== CACHE_NAME).map(key => caches.delete(key))
  )).then(() => self.clients.claim()));
});

self.addEventListener('message', event => {
  if (event.data?.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('push', event => {
  let data = {};
  try { data = event.data?.json() || {}; } catch (_) { data = { body: event.data?.text() || '' }; }
  event.waitUntil(self.registration.showNotification(data.title || 'Sapling', {
    body: data.body || 'There is news from your grove.',
    icon: './apple-touch-icon.png',
    badge: './favicon.png',
    tag: data.tag || 'sapling-announcement',
    data: { url: data.url || './' }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './', self.registration.scope).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
    const existing = clients.find(client => client.url.startsWith(self.registration.scope));
    if (existing) return existing.navigate(target).then(() => existing.focus());
    return self.clients.openWindow(target);
  }));
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.includes('/rest/') || url.pathname.includes('/auth/')) return;

  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).then(response => {
      if (response.ok) caches.open(CACHE_NAME).then(cache => cache.put('./index.html', response.clone()));
      return response;
    }).catch(() => caches.match('./index.html')));
    return;
  }

  event.respondWith(caches.match(request).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      if (response.ok && response.type === 'basic') caches.open(CACHE_NAME).then(cache => cache.put(request, response.clone()));
      return response;
    });
  }));
});
