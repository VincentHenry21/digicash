/* DigiCash UI framework: router, sheets, toasts, formatting helpers, charts. */
(function () {
  'use strict';
  var I = window.DCIcons, M = window.DCMoney;

  var screen = document.getElementById('screen');
  var tabbar = document.getElementById('tabbar');
  var sheetRoot = document.getElementById('sheet-root');
  var toastRoot = document.getElementById('toast-root');

  var routes = {};
  var current = null;
  var history = [];

  function fmt(minor, code, opts) {
    var prefs = window.DC.prefs();
    return M.format(minor, code || prefs.currency, Object.assign({ digits: prefs.digits }, opts));
  }
  function fmtSigned(minor, code, type) {
    var s = fmt(Math.abs(minor), code);
    if (type === 'income' || type === 'refund') return '+ ' + s;
    if (type === 'expense') return '- ' + s;
    return s;
  }
  function fmtDate(ms) {
    return new Date(ms).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
  }
  function fmtDateTime(ms) {
    return new Date(ms).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) + ', ' +
      new Date(ms).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function catById(id) {
    var c = window.DC.doc().categories.find(function (x) { return x.id === id; });
    return c || { name: 'Uncategorized', icon: 'dots', color: 'gray' };
  }
  function acctById(id) {
    return window.DC.doc().accounts.find(function (x) { return x.id === id; });
  }
  function catChip(cat, size) {
    var col = I.COLORS[cat.color] || I.COLORS.gray;
    return '<span class="ic" style="background:' + col + '22;color:' + col + '">' + I.svg(cat.icon, size || 20) + '</span>';
  }
  function acctIcon(type) {
    return { cash: 'cash', bank: 'bank', savings: 'wallet', ewallet: 'phone' }[type] || 'wallet';
  }

  function txnRow(t) {
    var cat = t.type === 'transfer' ? { name: 'Transfer', icon: 'swap', color: 'purple' } : catById(t.categoryId);
    var acct = acctById(t.accountId);
    var cls = (t.type === 'income' || t.type === 'refund') ? 'in' : 'out';
    var amt = t.type === 'transfer' ? fmt(t.amountMinor, t.currency)
      : fmtSigned(t.amountMinor, t.currency, t.type);
    var title = t.description || (t.type === 'transfer'
      ? 'Transfer to ' + (acctById(t.destAccountId) || {}).name
      : cat.name);
    return '<button class="txn" data-txn="' + t.id + '">' + catChip(cat) +
      '<span class="grow"><span class="title">' + esc(title) + '</span><br>' +
      '<span class="meta">' + fmtDate(t.date) + (acct ? ' · ' + esc(acct.name) : '') +
      (t.type === 'refund' ? ' · Refund' : '') + '</span></span>' +
      '<span class="amt num ' + cls + '">' + esc(amt) + '</span></button>';
  }

  function bindTxnRows(root) {
    (root || screen).querySelectorAll('[data-txn]').forEach(function (el) {
      el.addEventListener('click', function () { window.DCTxn.openDetail(el.getAttribute('data-txn')); });
    });
  }

  // --- router ---
  function register(name, fn) { routes[name] = fn; }
  var routeChanged = false;
  function go(name, params, replace) {
    if (current && !replace) history.push({ name: current, params: currentParams });
    bubbleNext = (current !== null && current !== name);
    routeChanged = bubbleNext;
    current = name; currentParams = params || {};
    render();
    window.scrollTo(0, 0);
  }
  var currentParams = {};
  function back() {
    var prev = history.pop();
    if (prev) { current = prev.name; currentParams = prev.params; render(); }
    else go('home', {}, true);
  }
  function render() {
    var fn = routes[current] || routes.home;
    screen.innerHTML = '';
    fn(screen, currentParams);
    if (routeChanged && !reduceMotion) {
      screen.classList.remove('enter');
      void screen.offsetWidth; // restart the entrance animation
      screen.classList.add('enter');
    }
    routeChanged = false;
    renderTabbar();
    bindTxnRows(screen);
    flashNewTxn();
  }
  // Set after a successful save; the next render animates the new row in.
  var _newTxnId = null;
  function noteNewTxn(id) { _newTxnId = id; }
  function flashNewTxn() {
    if (!_newTxnId) return;
    var el = screen.querySelector('[data-txn="' + _newTxnId + '"]');
    _newTxnId = null;
    if (el && !reduceMotion) {
      el.classList.add('txn-new');
      setTimeout(function () { el.classList.remove('txn-new'); }, 650);
    }
  }

  // Animate a row out, then re-render (used by delete).
  function removeTxnAnimated(id) {
    var el = screen.querySelector('[data-txn="' + id + '"]');
    if (el && !reduceMotion) {
      el.classList.add('txn-out');
      setTimeout(function () { render(); }, 270);
    } else {
      render();
    }
  }

  function params() { return currentParams; }
  function name() { return current; }

  var TABS = [
    { id: 'home', label: 'Home', icon: 'home' },
    { id: 'transactions', label: 'Activity', icon: 'list' },
    { id: 'add', label: 'Add', icon: 'plus', fab: true },
    { id: 'budgets', label: 'Budgets', icon: 'pie' },
    { id: 'insights', label: 'Insights', icon: 'chart' }
  ];
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var bubbleNext = false; // animate bubble on the next tabbar render

  function renderTabbar() {
    var bubble = tabbar.querySelector('.bubble');
    if (!bubble) {
      bubble = document.createElement('div');
      bubble.className = 'bubble';
      bubble.setAttribute('aria-hidden', 'true');
    }
    tabbar.innerHTML = '';
    tabbar.appendChild(bubble);
    TABS.forEach(function (t) {
      var b = document.createElement('button');
      if (t.fab) {
        b.className = 'fab';
        b.setAttribute('data-tab', 'add');
        b.setAttribute('aria-label', 'Add transaction');
        b.innerHTML = I.svg('plus', 26);
      } else {
        b.setAttribute('data-tab', t.id);
        b.setAttribute('aria-label', t.label);
        if (current === t.id) b.setAttribute('aria-current', 'page');
        b.innerHTML = I.svg(t.icon, 22) + '<span class="lbl">' + t.label + '</span>';
      }
      b.addEventListener('click', function () {
        var id = b.getAttribute('data-tab');
        if (id === 'add') window.DCTxn.openForm();
        else go(id, {}, true);
      });
      tabbar.appendChild(b);
    });
    positionBubble(bubbleNext);
    bubbleNext = false;
    if (!renderTabbar._rz) {
      renderTabbar._rz = true;
      window.addEventListener('resize', function () { positionBubble(false); });
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(function () { positionBubble(false); });
      }
    }
  }

  // Sliding bubble: tracks the active tab. Mid-flight it stretches slightly,
  // like the reference bubble-menu motion. Pure transform, no layout thrash.
  function positionBubble(animate) {
    var bubble = tabbar.querySelector('.bubble');
    var active = tabbar.querySelector('button[aria-current="page"]');
    if (!bubble || !active) return;
    var x = active.offsetLeft, w = active.offsetWidth;
    var px = bubble._x;
    bubble._x = x; bubble._w = w;
    if (!animate || reduceMotion || px === undefined) {
      try { bubble.getAnimations().forEach(function (a) { a.cancel(); }); } catch (e) {}
      bubble.style.width = w + 'px';
      bubble.style.transform = 'translateX(' + x + 'px)';
      return;
    }
    bubble.style.width = w + 'px';
    var midX = (px + x) / 2;
    var stretch = 1 + Math.min(0.22, Math.abs(x - px) / 900);
    try {
      bubble.animate([
        { transform: 'translateX(' + px + 'px) scaleX(1)' },
        { transform: 'translateX(' + midX + 'px) scaleX(' + stretch.toFixed(3) + ')', offset: 0.55 },
        { transform: 'translateX(' + x + 'px) scaleX(1)' }
      ], { duration: 340, easing: 'cubic-bezier(0.32,0.72,0,1)', fill: 'forwards' });
    } catch (e) {
      bubble.style.transform = 'translateX(' + x + 'px)';
    }
  }

  // --- sheet ---
  function openSheet(html, opts) {
    opts = opts || {};
    closeSheet();
    var bd = document.createElement('div');
    bd.className = 'sheet-backdrop';
    var sh = document.createElement('div');
    sh.className = 'sheet'; sh.setAttribute('role', 'dialog'); sh.setAttribute('aria-modal', 'true');
    sh.innerHTML = '<div class="grab"></div>' +
      (opts.sticky ? '' : '<button class="sheet-x" aria-label="Close">') +
      (opts.sticky ? '' : I.svg('x', 18) + '</button>') + html;
    sheetRoot.appendChild(bd); sheetRoot.appendChild(sh);
    requestAnimationFrame(function () { bd.classList.add('open'); sh.classList.add('open'); });
    bd.addEventListener('click', function () { if (!opts.sticky) closeSheet(); });
    var x = sh.querySelector('.sheet-x');
    if (x) x.addEventListener('click', closeSheet);
    if (!opts.sticky && !openSheet._esc) {
      openSheet._esc = true;
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && sheetRoot.querySelector('.sheet')) closeSheet();
      });
    }
    var f = sh.querySelector('input,select,textarea,button');
    if (f && !opts.noFocus) setTimeout(function () { try { f.focus({ preventScroll: true }); } catch (e) {} }, 320);
    return sh;
  }
  function closeSheet() { sheetRoot.innerHTML = ''; }
  function sheetEl() { return sheetRoot.querySelector('.sheet'); }

  function toast(msg, kind) {
    var t = document.createElement('div');
    t.className = 'toast' + (kind ? ' ' + kind : '');
    t.textContent = msg;
    toastRoot.appendChild(t);
    setTimeout(function () { t.style.opacity = '0'; t.style.transition = 'opacity .3s'; }, 2400);
    setTimeout(function () { t.remove(); }, 2800);
  }

  function confirmDlg(title, body, okLabel) {
    return new Promise(function (resolve) {
      var sh = openSheet(
        '<h2>' + esc(title) + '</h2><p>' + esc(body) + '</p>' +
        '<div class="row" style="margin-top:18px"><button class="btn btn-ghost" id="cf-no" style="flex:1">Cancel</button>' +
        '<button class="btn btn-danger" id="cf-yes" style="flex:1">' + esc(okLabel || 'Delete') + '</button></div>',
        { sticky: true, noFocus: true });
      sh.querySelector('#cf-no').addEventListener('click', function () { closeSheet(); resolve(false); });
      sh.querySelector('#cf-yes').addEventListener('click', function () { closeSheet(); resolve(true); });
    });
  }

  function fieldError(input, msg) {
    var f = input.closest('.field');
    if (!f) return;
    if (msg) { f.classList.add('invalid'); var e = f.querySelector('.err'); if (e) e.textContent = msg; }
    else f.classList.remove('invalid');
  }

  // --- canvas charts (real data only) ---
  function drawBars(canvas, series, opts) {
    // series: [{label, income, expense}] in minor units; opts: {currency}
    opts = opts || {};
    var dpr = window.devicePixelRatio || 1;
    var w = canvas.clientWidth, h = canvas.clientHeight;
    canvas.width = w * dpr; canvas.height = h * dpr;
    var ctx = canvas.getContext('2d'); ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);
    if (!series.length) return;
    var max = 1;
    series.forEach(function (s) { max = Math.max(max, s.income, s.expense); });
    var n = series.length, gap = 8;
    var bw = Math.min(34, (w - gap * (n - 1)) / n);
    var base = h - 22;
    series.forEach(function (s, i) {
      var x = i * ((w - bw) / Math.max(1, n - 1)) || 0;
      if (n === 1) x = (w - bw) / 2;
      var ih = (s.income / max) * (base - 10), eh = (s.expense / max) * (base - 10);
      var dark = document.documentElement.getAttribute('data-theme') !== 'light';
      ctx.fillStyle = '#39d98a';
      roundBar(ctx, x, base - ih, bw / 2 - 2, ih);
      ctx.fillStyle = '#9409b6';
      roundBar(ctx, x + bw / 2 + 2, base - eh, bw / 2 - 2, eh);
      ctx.fillStyle = dark ? '#6b726d' : '#8a8f94';
      ctx.font = '10px ' + getComputedStyle(document.body).fontFamily;
      ctx.textAlign = 'center';
      ctx.fillText(s.label, x + bw / 2, h - 6);
    });
    function roundBar(c, x, y, ww, hh) {
      if (hh <= 0) return;
      var r = Math.min(4, ww / 2);
      c.beginPath();
      c.moveTo(x, y + hh);
      c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y);
      c.lineTo(x + ww - r, y); c.quadraticCurveTo(x + ww, y, x + ww, y + r);
      c.lineTo(x + ww, y + hh); c.closePath(); c.fill();
    }
  }

  function drawDonut(canvas, slices) {
    // slices: [{label, value, color}]
    var dpr = window.devicePixelRatio || 1;
    var w = canvas.clientWidth, h = canvas.clientHeight;
    canvas.width = w * dpr; canvas.height = h * dpr;
    var ctx = canvas.getContext('2d'); ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);
    var total = slices.reduce(function (a, s) { return a + s.value; }, 0);
    if (!total) return;
    var cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 8, ir = r * 0.62;
    var a = -Math.PI / 2;
    slices.forEach(function (s) {
      var a2 = a + (s.value / total) * Math.PI * 2;
      ctx.beginPath(); ctx.arc(cx, cy, r, a, a2); ctx.arc(cx, cy, ir, a2, a, true);
      ctx.closePath(); ctx.fillStyle = s.color; ctx.fill();
      a = a2;
    });
  }

  window.DCUI = {
    register: register, go: go, back: back, params: params, name: name, render: render,
    openSheet: openSheet, closeSheet: closeSheet, sheetEl: sheetEl,
    toast: toast, confirmDlg: confirmDlg, fieldError: fieldError,
    fmt: fmt, fmtSigned: fmtSigned, fmtDate: fmtDate, fmtDateTime: fmtDateTime, esc: esc,
    catById: catById, acctById: acctById, catChip: catChip, acctIcon: acctIcon,
    txnRow: txnRow, bindTxnRows: bindTxnRows, noteNewTxn: noteNewTxn,
    removeTxnAnimated: removeTxnAnimated, reduceMotion: reduceMotion,
    drawBars: drawBars, drawDonut: drawDonut
  };
})();
