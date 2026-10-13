/* DigiCash service worker: offline-first app shell. Only caches successful responses. */
var V = 'digicash-v1';
var SHELL = [
  './', './index.html', './manifest.json',
  './css/tokens.css', './css/base.css', './css/components.css', './css/screens.css',
  './js/money.js', './js/store.js', './js/data.js', './js/calc.js', './js/icons.js',
  './js/ui.js', './js/onboarding.js', './js/home.js', './js/transactions.js',
  './js/accounts.js', './js/budgets.js', './js/goals.js', './js/insights.js',
  './js/recurring.js', './js/settings.js', './js/app.js',
  './assets/icons/icon-192.png', './assets/icons/icon-512.png'
];
self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(V).then(function (c) { return c.addAll(SHELL); }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k !== V; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});
self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(function (hit) {
      return hit || fetch(e.request).then(function (res) {
        if (res && res.ok) {
          var copy = res.clone();
          caches.open(V).then(function (c) { c.put(e.request, copy); });
        }
        return res;
      });
    })
  );
});
