/* DigiCash app boot: store, global namespace, PIN lock, recurring engine. */
(function () {
  'use strict';

  var store = new window.DCStore.Store();
  store.load();

  function doc() { return store.doc; }
  function prefs() { return store.doc.prefs; }
  function save() { return store.update(function () {}); }

  function seedIfNeeded() {
    var d = doc();
    if (d.categories.length) return;
    var D = window.DCData;
    D.EXPENSE_CATS.forEach(function (c, i) {
      d.categories.push({ id: 'sys_exp_' + i, name: c.name, type: 'expense', icon: c.icon, color: c.color, system: true });
    });
    D.INCOME_CATS.forEach(function (c, i) {
      d.categories.push({ id: 'sys_inc_' + i, name: c.name, type: 'income', icon: c.icon, color: c.color, system: true });
    });
    save();
  }

  // Recurring engine: generate due occurrences as real transactions.
  // Idempotent: template.nextDate only advances past generated dates.
  function runRecurring() {
    var d = doc(), now = Date.now(), changed = false;
    d.recurring.forEach(function (t) {
      if (t.paused) return;
      var guard = 0;
      while (t.nextDate <= now && guard < 60) {
        if (t.endDate && t.nextDate > t.endDate) break;
        d.transactions.push({
          id: window.DCStore.uid('txn'),
          type: t.type, amountMinor: t.amountMinor, currency: t.currency,
          categoryId: t.categoryId, accountId: t.accountId, destAccountId: t.destAccountId || null,
          description: t.description || '', merchant: '', notes: 'Recurring',
          tags: [], date: t.nextDate, createdAt: now, updatedAt: now, recurringId: t.id
        });
        t.nextDate = window.DCCalc.advanceDate(t.nextDate, t.freq, t.interval || 1);
        changed = true; guard++;
      }
    });
    if (changed) save();
  }

  // PIN lock (WebCrypto SHA-256; real hashing, PIN never stored in plain text)
  function sha256hex(str) {
    var buf = new TextEncoder().encode('digicash-pin:' + str);
    return crypto.subtle.digest('SHA-256', buf).then(function (h) {
      return Array.from(new Uint8Array(h)).map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
    });
  }

  function showLock() {
    document.getElementById('tabbar').style.display = 'none';
    var s = document.getElementById('screen');
    s.innerHTML = '<div class="ob-step" style="padding-top:80px">' +
      '<img class="logo" src="./assets/icons/icon-512.png" alt="DigiCash">' +
      '<h2>Enter PIN</h2><p>DigiCash is locked.</p>' +
      '<div class="field" style="max-width:220px;margin:18px auto">' +
      '<input id="pin-in" type="password" inputmode="numeric" maxlength="8" autocomplete="off" ' +
      'style="text-align:center;font-size:1.6rem;letter-spacing:0.4em" aria-label="PIN"></div>' +
      '<div class="err" id="pin-err" style="color:var(--expense);display:none">Wrong PIN. Try again.</div></div>';
    var inp = document.getElementById('pin-in');
    inp.focus();
    inp.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      sha256hex(inp.value).then(function (h) {
        if (h === prefs().pinHash) {
          document.getElementById('tabbar').style.display = '';
          window.DCUI.go('home', {}, true);
        } else {
          document.getElementById('pin-err').style.display = 'block';
          inp.value = ''; inp.focus();
        }
      });
    });
  }

  function applyTheme() {
    var t = prefs().theme;
    var dark = t === 'dark' || (t === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', dark ? '#0a0a0d' : '#f4f4f6');
  }

  window.DC = {
    store: store, doc: doc, prefs: prefs, save: save,
    seedIfNeeded: seedIfNeeded, runRecurring: runRecurring,
    sha256hex: sha256hex, showLock: showLock, applyTheme: applyTheme
  };

  document.addEventListener('DOMContentLoaded', function () {
    seedIfNeeded();
    runRecurring();
    applyTheme();
    store.on(function () { if (window.DCUI.name()) window.DCUI.render(); });
    if (!prefs().onboardingDone) { window.DCOnboarding.start(); return; }
    if (prefs().pinHash && prefs().lockOnLaunch) { showLock(); return; }
    window.DCUI.go('home', {}, true);
  });
})();
