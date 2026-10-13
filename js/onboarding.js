/* DigiCash onboarding: welcome, currency, starting balance, privacy, done. */
(function () {
  'use strict';
  var U = window.DCUI, M = window.DCMoney;

  var state = { step: 0, currency: 'MMK', digits: 'western', weekStart: 1, theme: 'dark', openingMinor: 0 };

  var STEPS = 5;

  function dots() {
    var h = '<div class="ob-dots">';
    for (var i = 0; i < STEPS; i++) h += '<i class="' + (i === state.step ? 'on' : '') + '"></i>';
    return h + '</div>';
  }

  function render() {
    document.getElementById('tabbar').style.display = 'none';
    var s = document.getElementById('screen');
    [welcome, currencyStep, balanceStep, privacyStep, doneStep][state.step](s);
    window.scrollTo(0, 0);
  }

  function nav(s, backLabel) {
    return '<div class="ob-nav">' +
      (state.step > 0 ? '<button class="btn btn-ghost" id="ob-back">' + (backLabel || 'Back') + '</button>' : '') +
      '<button class="btn" id="ob-next">Continue</button></div>';
  }

  function bindBack() {
    var b = document.getElementById('ob-back');
    if (b) b.addEventListener('click', function () { state.step--; render(); });
  }

  function welcome(s) {
    s.innerHTML = '<div class="ob-hero">' +
      '<div class="ob-glow" aria-hidden="true"></div>' +
      '<img class="ob-logo" src="./assets/logo-transparent.png" alt="DigiCash logo">' +
      '<h1>Welcome to DigiCash</h1>' +
      '<p>The best way to manage your money.<br>Private by default. Your data never leaves this device.</p>' +
      '<button class="btn-white" id="ob-next">Get Started</button>' +
      '<p class="ob-fine">Free forever · No account · Works offline</p>' +
      '</div>' + dots();
    document.getElementById('ob-next').addEventListener('click', function () { state.step = 1; render(); });
  }

  function currencyStep(s) {
    var codes = ['MMK', 'USD', 'EUR', 'GBP', 'SGD', 'THB'];
    s.innerHTML = '<div class="ob-step"><h1>Your currency</h1>' +
      '<p>Choose your primary currency. Every new account uses it unless you pick another.</p>' +
      '<div class="curpick">' + codes.map(function (c) {
        var cur = M.currency(c);
        return '<button data-cur="' + c + '" aria-pressed="' + (state.currency === c) + '">' +
          '<div class="code">' + c + '</div><div class="nm">' + cur.name + '</div></button>';
      }).join('') + '</div>' +
      '<div class="field" style="text-align:left;margin-top:18px"><label>Number style</label><div class="seg" role="group" aria-label="Number style">' +
      '<button data-dg="western" aria-selected="' + (state.digits === 'western') + '">Western (0-9)</button>' +
      '<button data-dg="myanmar" aria-selected="' + (state.digits === 'myanmar') + '">Myanmar (၀-၉)</button></div></div>' +
      '<div class="field" style="text-align:left"><label>Week starts on</label><div class="seg" role="group" aria-label="Week start">' +
      '<button data-ws="0" aria-selected="' + (state.weekStart === 0) + '">Sunday</button>' +
      '<button data-ws="1" aria-selected="' + (state.weekStart === 1) + '">Monday</button></div></div>' +
      dots() + nav(s) + '</div>';
    s.querySelectorAll('[data-cur]').forEach(function (b) {
      b.addEventListener('click', function () { state.currency = b.getAttribute('data-cur'); render(); });
    });
    s.querySelectorAll('[data-dg]').forEach(function (b) {
      b.addEventListener('click', function () { state.digits = b.getAttribute('data-dg'); render(); });
    });
    s.querySelectorAll('[data-ws]').forEach(function (b) {
      b.addEventListener('click', function () { state.weekStart = +b.getAttribute('data-ws'); render(); });
    });
    bindBack();
    document.getElementById('ob-next').addEventListener('click', function () { state.step = 2; render(); });
  }

  function balanceStep(s) {
    s.innerHTML = '<div class="ob-step"><h1>Starting balance</h1>' +
      '<p>Enter the cash you have right now, or start from zero. A starting balance is recorded as an opening-balance record, never as income.</p>' +
      '<div class="field" style="text-align:left;max-width:300px;margin:0 auto">' +
      '<label>Amount (' + state.currency + ')</label>' +
      '<input id="ob-amt" inputmode="decimal" placeholder="0" class="num" style="font-size:1.5rem;text-align:center">' +
      '<div class="err"></div></div>' +
      dots() + nav(s, 'Back') + '</div>';
    bindBack();
    document.getElementById('ob-next').addEventListener('click', function () {
      var inp = document.getElementById('ob-amt');
      var raw = inp.value.trim();
      if (!raw) { state.openingMinor = 0; state.step = 3; render(); return; }
      try { state.openingMinor = M.parse(raw, state.currency); }
      catch (e) { U.fieldError(inp, e.message); return; }
      state.step = 3; render();
    });
  }

  function privacyStep(s) {
    s.innerHTML = '<div class="ob-step" style="text-align:left"><h1 style="text-align:center">Privacy</h1>' +
      '<div class="card"><div class="kv"><span class="k">Where is data stored?</span><span class="v">This device only</span></div>' +
      '<div class="kv"><span class="k">Cloud sync</span><span class="v">Not available</span></div>' +
      '<div class="kv"><span class="k">Bank connections</span><span class="v">Not available</span></div>' +
      '<div class="kv"><span class="k">Accounts</span><span class="v">Manual records</span></div>' +
      '<div class="kv"><span class="k">Analytics / ads SDKs</span><span class="v">None</span></div>' +
      '<div class="kv"><span class="k">App lock</span><span class="v">Optional PIN in Settings</span></div></div>' +
      '<p style="text-align:center">DigiCash works fully offline. Nothing is uploaded, tracked, or shared.</p>' +
      dots() + nav(s) + '</div>';
    bindBack();
    document.getElementById('ob-next').addEventListener('click', function () { state.step = 4; render(); });
  }

  function doneStep(s) {
    s.innerHTML = '<div class="ob-hero">' +
      '<div class="ob-glow" aria-hidden="true"></div>' +
      '<img class="ob-logo" src="./assets/logo-transparent.png" alt="DigiCash logo">' +
      '<h1>You are set</h1>' +
      '<p>Your ' + state.currency + ' wallet is ready.<br>Add your first transaction whenever you like.</p>' +
      '<button class="btn-white" id="ob-next">Open DigiCash</button>' +
      '</div>' + dots();
    document.getElementById('ob-next').addEventListener('click', finish);
  }

  function finish() {
    var r = window.DC.store.update(function (d) {
      d.prefs.currency = state.currency;
      d.prefs.digits = state.digits;
      d.prefs.weekStart = state.weekStart;
      d.prefs.theme = state.theme;
      d.prefs.onboardingDone = true;
      // Default cash account in the chosen currency
      var accId = window.DCStore.uid('acc');
      d.accounts.push({
        id: accId, name: 'Cash', type: 'cash', currency: state.currency,
        openingMinor: 0, createdAt: Date.now(), updatedAt: Date.now()
      });
      if (state.openingMinor > 0) {
        d.transactions.push({
          id: window.DCStore.uid('txn'), type: 'opening', amountMinor: state.openingMinor,
          currency: state.currency, categoryId: null, accountId: accId, destAccountId: null,
          description: 'Opening balance', merchant: '', notes: '', tags: [],
          date: Date.now(), createdAt: Date.now(), updatedAt: Date.now()
        });
      }
    });
    document.getElementById('tabbar').style.display = '';
    if (!r.ok) U.toast('Could not save setup: ' + r.error, 'bad');
    window.DC.applyTheme();
    U.go('home', {}, true);
  }

  window.DCOnboarding = { start: function () { state.step = 0; render(); } };
})();
