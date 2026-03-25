// Service Worker para notificações push (CampanhaMT PWA)
// Funciona em background — recebe notificações mesmo com o app fechado.

const CACHE_NAME = 'campanha-mt-v1';

// ── Instalação do Service Worker ──────────────────────────────────────────────
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// ── Recebimento de push do servidor ──────────────────────────────────────────
self.addEventListener('push', (event) => {
  let data = { title: 'CampanhaMT', body: 'Nova atualização disponível.' };

  if (event.data) {
    try {
      data = event.data.json();
    } catch (_) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body ?? '',
    icon: data.icon ?? '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.tag ?? 'campanha-mt',
    renotify: true,
    data: { url: data.url ?? '/' },
    actions: data.actions ?? [],
  };

  event.waitUntil(
    self.registration.showNotification(data.title ?? 'CampanhaMT', options)
  );
});

// ── Clique na notificação → abre/foca o app ──────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = (event.notification.data && event.notification.data.url)
    ? event.notification.data.url
    : '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
