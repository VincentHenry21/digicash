/* DigiCash accounts: list, create, edit, archive, detail with history. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney, C = window.DCCalc;

  var ACCT_COLORS = { cash: '#39d98a', bank: '#4aa8ff', savings: '#b44ad1', ewallet: '#ff9f43' };

  function render(s) {
    var d = window.DC.doc();
    var accts = d.accounts.filter(function (a) { return !a.archivedAt; });
    var balances = C.allBalances(accts, d.transactions);
    var html = '<div class="topbar"><button class="iconbtn" id="a-back" aria-label="Back">' + I.svg('back') +
      '</button><h1 style="margin:0">Accounts</h1>' +
      '<button class="iconbtn" id="a-add" aria-label="Add account">' + I.svg('plus') + '</button></div>';
    if (!accts.length) {
      html += '<div class="empty"><div class="big">' + I.svg('wallet', 44) + '</div><h3>No accounts</h3>' +
        '<p>Create your first account to start tracking money.</p>' +
        '<button class="btn" id="a-first">Add account</button></div>';
    } else {
      accts.forEach(function (a) {
        var b = balances[a.id] || 0;
        var col = ACCT_COLORS[a.type] || '#9ba79f';
        html += '<button class="acct" data-acct="' + a.id + '"><span class="ic" style="background:' + col + '22;color:' + col + '">' +
          I.svg(U.acctIcon(a.type), 22) + '</span><span class="grow"><strong>' + U.esc(a.name) + '</strong><br>' +
          '<span class="meta">' + typeName(a.type) + ' · ' + a.currency + '</span></span>' +
          '<span class="amt num" style="font-weight:700">' + U.fmt(b, a.currency) + '</span></button>';
      });
    }
    var arch = d.accounts.filter(function (a) { return a.archivedAt; });
    if (arch.length) {
      html += '<div class="sect-head"><h2>Archived</h2></div>';
      arch.forEach(function (a) {
        html += '<button class="acct" data-acct="' + a.id + '" style="opacity:0.65"><span class="ic" style="background:#9ba79f22;color:#9ba79f">' +
          I.svg(U.acctIcon(a.type), 22) + '</span><span class="grow"><strong>' + U.esc(a.name) + '</strong><br>' +
          '<span class="meta">Archived · history kept</span></span></button>';
      });
    }
    s.innerHTML = html;
    document.getElementById('a-back').addEventListener('click', U.back);
    var add = function () { openForm(); };
    document.getElementById('a-add').addEventListener('click', add);
    var f = document.getElementById('a-first');
    if (f) f.addEventListener('click', add);
    s.querySelectorAll('[data-acct]').forEach(function (b) {
      b.addEventListener('click', function () { openDetail(b.getAttribute('data-acct')); });
    });
  }

  function typeName(t) {
    var m = { cash: 'Cash', bank: 'Bank Account', savings: 'Savings', ewallet: 'E-Wallet' };
    return m[t] || t;
  }

  function openForm(editId) {
    var d = window.DC.doc();
    var e = editId ? d.accounts.find(function (a) { return a.id === editId; }) : null;
    var prefs = window.DC.prefs();
    var D = window.DCData;
    var selType = e ? e.type : 'cash';
    var selCur = e ? e.currency : prefs.currency;
    var sh = U.openSheet('<h2>' + (e ? 'Edit' : 'Add') + ' account</h2>' +
      '<div class="field"><label>Account name</label><input id="af-name" maxlength="40" value="' +
      U.esc(e ? e.name : '') + '" placeholder="e.g. Cash, KBZPay"><div class="err"></div></div>' +
      '<div class="field"><label>Account type</label><div class="seg" id="af-type">' +
      D.ACCOUNT_TYPES.map(function (t) {
        return '<button data-v="' + t.id + '" aria-selected="' + (selType === t.id) + '">' + t.name + '</button>';
      }).join('') + '</div><div class="hint" id="af-tdesc"></div></div>' +
      '<div class="field" id="af-preset-wrap" style="display:none"><label>E-wallet</label><select id="af-preset">' +
      D.EWALLET_PRESETS.map(function (p) { return '<option>' + p + '</option>'; }).join('') +
      '<option>Other</option></select><div class="hint">Generic category only. DigiCash has no live wallet connection.</div></div>' +
      '<div class="field"><label>Currency</label><select id="af-cur">' +
      Object.keys(M.CURRENCIES).map(function (c) {
        return '<option value="' + c + '"' + (selCur === c ? ' selected' : '') + '>' + c + ' · ' + M.currency(c).name + '</option>';
      }).join('') + '</select></div>' +
      (e ? '' : '<div class="field"><label>Opening balance (optional)</label>' +
        '<input id="af-open" inputmode="decimal" class="num" placeholder="0"><div class="err"></div>' +
        '<div class="hint">Recorded as an opening-balance entry, never as income.</div></div>') +
      '<button class="btn" id="af-save" style="width:100%">' + (e ? 'Save changes' : 'Add account') + '</button>');
    var tdesc = sh.querySelector('#af-tdesc');
    function syncType() {
      var t = D.ACCOUNT_TYPES.find(function (x) { return x.id === selType; });
      tdesc.textContent = t ? t.desc : '';
      sh.querySelector('#af-preset-wrap').style.display = selType === 'ewallet' ? '' : 'none';
    }
    sh.querySelectorAll('#af-type button').forEach(function (b) {
      b.addEventListener('click', function () {
        selType = b.getAttribute('data-v');
        sh.querySelectorAll('#af-type button').forEach(function (x) { x.setAttribute('aria-selected', 'false'); });
        b.setAttribute('aria-selected', 'true');
        if (selType === 'ewallet' && !e) {
          var nm = sh.querySelector('#af-name');
          if (!nm.value) nm.value = sh.querySelector('#af-preset').value;
        }
        syncType();
      });
    });
    sh.querySelector('#af-preset').addEventListener('change', function (ev) {
      var nm = sh.querySelector('#af-name');
      if (!nm.value || D.EWALLET_PRESETS.indexOf(nm.value) !== -1) nm.value = ev.target.value === 'Other' ? '' : ev.target.value;
    });
    syncType();
    sh.querySelector('#af-save').addEventListener('click', function () {
      var nm = sh.querySelector('#af-name');
      var name = nm.value.trim();
      if (!name) { U.fieldError(nm, 'Give the account a name.'); return; }
      U.fieldError(nm);
      var cur = sh.querySelector('#af-cur').value;
      var openMinor = 0;
      var oi = sh.querySelector('#af-open');
      if (oi && oi.value.trim()) {
        try { openMinor = M.parse(oi.value, cur); U.fieldError(oi); }
        catch (err) { U.fieldError(oi, err.message); return; }
      }
      var r;
      if (e) {
        r = window.DC.store.update(function (dd) {
          var a = dd.accounts.find(function (x) { return x.id === e.id; });
          if (a) { a.name = name; a.type = selType; a.currency = cur; a.updatedAt = Date.now(); }
        });
      } else {
        var accId = window.DCStore.uid('acc');
        r = window.DC.store.update(function (dd) {
          dd.accounts.push({ id: accId, name: name, type: selType, currency: cur, openingMinor: 0, createdAt: Date.now(), updatedAt: Date.now() });
          if (openMinor > 0) {
            dd.transactions.push({
              id: window.DCStore.uid('txn'), type: 'opening', amountMinor: openMinor, currency: cur,
              categoryId: null, accountId: accId, destAccountId: null, description: 'Opening balance',
              merchant: '', notes: '', tags: [], date: Date.now(), createdAt: Date.now(), updatedAt: Date.now()
            });
          }
        });
      }
      if (r.ok) { U.closeSheet(); U.toast(e ? 'Account updated' : 'Account added', 'ok'); U.render(); }
      else U.toast('Save failed: ' + r.error, 'bad');
    });
  }

  function openDetail(id) {
    var d = window.DC.doc();
    var a = d.accounts.find(function (x) { return x.id === id; });
    if (!a) return;
    var bal = C.accountBalance(a, d.transactions);
    var txs = d.transactions.filter(function (t) { return t.accountId === id || t.destAccountId === id; })
      .sort(function (x, y) { return y.date - x.date; });
    var col = ACCT_COLORS[a.type] || '#9ba79f';
    var html = '<h2>' + U.esc(a.name) + '</h2>' +
      '<div class="row" style="margin-bottom:10px"><span class="ic" style="width:52px;height:52px;border-radius:16px;background:' + col + '22;color:' + col + ';display:flex;align-items:center;justify-content:center">' +
      I.svg(U.acctIcon(a.type), 26) + '</span><div class="grow"><div style="font-size:0.85rem;color:var(--text2)">' +
      typeName(a.type) + ' · ' + a.currency + (a.archivedAt ? ' · Archived' : '') + '</div>' +
      '<div class="num" style="font-size:1.7rem;font-weight:800">' + U.fmt(bal, a.currency) + '</div></div></div>' +
      '<div class="row" style="margin:14px 0">' +
      '<button class="btn btn-ghost btn-sm" id="ad-edit" style="flex:1">Edit</button>' +
      (a.archivedAt
        ? '<button class="btn btn-ghost btn-sm" id="ad-unarch" style="flex:1">Restore</button>'
        : '<button class="btn btn-ghost btn-sm" id="ad-arch" style="flex:1">Archive</button>') +
      '</div>' +
      '<h3>History (' + txs.length + ')</h3><div class="card">' +
      (txs.length ? txs.slice(0, 100).map(U.txnRow).join('') : '<div class="empty"><h3>No records</h3><p>Transactions for this account will appear here.</p></div>') +
      '</div><p style="font-size:0.8rem">Archived accounts keep all history. Balances always derive from records.</p>';
    var sh = U.openSheet(html, { noFocus: true });
    U.bindTxnRows(sh);
    sh.querySelector('#ad-edit').addEventListener('click', function () { U.closeSheet(); openForm(id); });
    var arch = sh.querySelector('#ad-arch');
    if (arch) arch.addEventListener('click', function () {
      window.DC.store.update(function (dd) {
        var x = dd.accounts.find(function (y) { return y.id === id; });
        if (x) x.archivedAt = Date.now();
      });
      U.closeSheet(); U.toast('Account archived', 'ok'); U.render();
    });
    var un = sh.querySelector('#ad-unarch');
    if (un) un.addEventListener('click', function () {
      window.DC.store.update(function (dd) {
        var x = dd.accounts.find(function (y) { return y.id === id; });
        if (x) x.archivedAt = null;
      });
      U.closeSheet(); U.toast('Account restored', 'ok'); U.render();
    });
  }

  window.DCAccounts = { openForm: openForm, openDetail: openDetail };
  U.register('accounts', render);
})();
