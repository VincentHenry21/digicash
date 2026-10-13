/* DigiCash budgets: create/edit, progress, history, alerts config. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney, C = window.DCCalc;

  function periodDates(period) {
    var now = new Date(), s, e;
    if (period === 'weekly') {
      var ws = window.DC.prefs().weekStart;
      var day = (now.getDay() - ws + 7) % 7;
      s = new Date(now.getFullYear(), now.getMonth(), now.getDate() - day);
      e = new Date(s); e.setDate(e.getDate() + 6);
    } else if (period === 'yearly') {
      s = new Date(now.getFullYear(), 0, 1); e = new Date(now.getFullYear(), 11, 31);
    } else {
      s = new Date(now.getFullYear(), now.getMonth(), 1); e = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    }
    s.setHours(0, 0, 0, 0); e.setHours(23, 59, 59, 999);
    return { start: s.getTime(), end: e.getTime() };
  }

  function render(s) {
    var d = window.DC.doc();
    var budgets = d.budgets.filter(function (b) { return !b.archivedAt; });
    var html = '<div class="topbar"><h1 style="margin:0">Budgets</h1>' +
      '<button class="iconbtn" id="b-add" aria-label="Add budget">' + I.svg('plus') + '</button></div>';
    if (!budgets.length) {
      html += '<div class="empty"><div class="big">' + I.svg('pie', 44) + '</div><h3>No budgets yet</h3>' +
        '<p>Set a spending limit per category and track it in real time.</p>' +
        '<button class="btn" id="b-first">Create budget</button></div>';
    } else {
      budgets.forEach(function (b) {
        var sp = C.budgetSpending(b, d.transactions);
        var days = Math.max(0, Math.ceil((b.endDate - Date.now()) / 86400000));
        html += '<button class="acct" data-bud="' + b.id + '"><span class="grow"><strong>' + U.esc(b.name) + '</strong><br>' +
          '<span class="meta">' + U.fmt(sp.spent, b.currency) + ' of ' + U.fmt(b.limitMinor, b.currency) +
          ' · ' + days + ' days left</span>' +
          '<div class="progress' + (sp.pct >= 100 ? ' over' : '') + '" style="margin-top:8px"><i style="width:' +
          Math.min(100, sp.pct) + '%"></i></div></span>' +
          '<span class="num" style="font-weight:700">' + sp.pct + '%</span></button>';
      });
    }
    var arch = d.budgets.filter(function (b) { return b.archivedAt; });
    if (arch.length) html += '<p style="color:var(--text3);font-size:0.85rem">' + arch.length + ' archived budget(s).</p>';
    s.innerHTML = html;
    var add = function () { openForm(); };
    document.getElementById('b-add').addEventListener('click', add);
    var f = document.getElementById('b-first');
    if (f) f.addEventListener('click', add);
    s.querySelectorAll('[data-bud]').forEach(function (b) {
      b.addEventListener('click', function () { openDetail(b.getAttribute('data-bud')); });
    });
  }

  function openForm(editId) {
    var d = window.DC.doc();
    var e = editId ? d.budgets.find(function (b) { return b.id === editId; }) : null;
    var prefs = window.DC.prefs();
    var cur = e ? e.currency : prefs.currency;
    var per = e ? e.period : 'monthly';
    var selCats = e ? e.categoryIds.slice() : [];
    var expCats = d.categories.filter(function (c) { return c.type === 'expense'; });

    var sh = U.openSheet('<h2>' + (e ? 'Edit' : 'Create') + ' budget</h2>' +
      '<div class="field"><label>Budget name</label><input id="bf-name" maxlength="40" value="' +
      U.esc(e ? e.name : '') + '" placeholder="e.g. Food October"><div class="err"></div></div>' +
      '<div class="field"><label>Spending limit (' + cur + ')</label>' +
      '<input id="bf-limit" inputmode="decimal" class="num" value="' +
      (e ? M.toMajor(e.limitMinor, e.currency) : '') + '"><div class="err"></div></div>' +
      '<div class="field"><label>Period</label><div class="seg" id="bf-per">' +
      [['weekly', 'Weekly'], ['monthly', 'Monthly'], ['yearly', 'Yearly']].map(function (o) {
        return '<button data-v="' + o[0] + '" aria-selected="' + (per === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="field"><label>Categories (empty = all expenses)</label><div class="catgrid" id="bf-cats">' +
      expCats.map(function (c) {
        return '<button data-c="' + c.id + '" aria-pressed="' + (selCats.indexOf(c.id) !== -1) + '">' +
          U.catChip(c, 19) + '<span>' + U.esc(c.name) + '</span></button>';
      }).join('') + '</div></div>' +
      '<div class="field"><label>Alert at</label><div class="seg" id="bf-th">' +
      [[50, '50%'], [80, '80%'], [100, '100%']].map(function (o) {
        var on = e ? e.thresholds.indexOf(o[0]) !== -1 : o[0] === 80;
        return '<button data-v="' + o[0] + '" aria-selected="' + on + '">' + o[1] + '</button>';
      }).join('') + '</div><div class="hint">Checked when you open the app. In-app notice only.</div></div>' +
      '<button class="btn" id="bf-save" style="width:100%">' + (e ? 'Save changes' : 'Create budget') + '</button>');

    sh.querySelectorAll('#bf-per button').forEach(function (b) {
      b.addEventListener('click', function () {
        per = b.getAttribute('data-v');
        sh.querySelectorAll('#bf-per button').forEach(function (x) { x.setAttribute('aria-selected', 'false'); });
        b.setAttribute('aria-selected', 'true');
      });
    });
    sh.querySelectorAll('#bf-cats button').forEach(function (b) {
      b.addEventListener('click', function () {
        var id = b.getAttribute('data-c');
        var i = selCats.indexOf(id);
        if (i === -1) selCats.push(id); else selCats.splice(i, 1);
        b.setAttribute('aria-pressed', i === -1 ? 'true' : 'false');
      });
    });
    var th = e ? e.thresholds.slice() : [80];
    sh.querySelectorAll('#bf-th button').forEach(function (b) {
      b.addEventListener('click', function () {
        var v = +b.getAttribute('data-v');
        var i = th.indexOf(v);
        if (i === -1) th.push(v); else th.splice(i, 1);
        b.setAttribute('aria-selected', i === -1 ? 'true' : 'false');
      });
    });
    sh.querySelector('#bf-save').addEventListener('click', function () {
      var nm = sh.querySelector('#bf-name');
      if (!nm.value.trim()) { U.fieldError(nm, 'Name the budget.'); return; }
      U.fieldError(nm);
      var li = sh.querySelector('#bf-limit'), limit = 0;
      try { limit = M.parse(li.value, cur); U.fieldError(li); }
      catch (err) { U.fieldError(li, err.message); return; }
      var pd = periodDates(per);
      var rec = {
        name: nm.value.trim(), categoryIds: selCats, limitMinor: limit, currency: cur,
        period: per, startDate: pd.start, endDate: pd.end, thresholds: th.sort(),
        notified: [], updatedAt: Date.now()
      };
      var r;
      if (e) r = window.DC.store.update(function (dd) {
        var b = dd.budgets.find(function (x) { return x.id === e.id; });
        if (b) Object.assign(b, rec);
      });
      else {
        rec.id = window.DCStore.uid('bud'); rec.createdAt = Date.now(); rec.archivedAt = null;
        r = window.DC.store.update(function (dd) { dd.budgets.push(rec); });
      }
      if (r.ok) { U.closeSheet(); U.toast(e ? 'Budget updated' : 'Budget created', 'ok'); U.render(); }
      else U.toast('Save failed: ' + r.error, 'bad');
    });
  }

  function openDetail(id) {
    var d = window.DC.doc();
    var b = d.budgets.find(function (x) { return x.id === id; });
    if (!b) return;
    var sp = C.budgetSpending(b, d.transactions);
    var txs = d.transactions.filter(function (t) {
      return t.type === 'expense' && t.currency === b.currency &&
        t.date >= b.startDate && t.date <= b.endDate &&
        (!b.categoryIds.length || b.categoryIds.indexOf(t.categoryId) !== -1);
    }).sort(function (x, y) { return y.date - x.date; });
    var html = '<h2>' + U.esc(b.name) + '</h2>' +
      '<div class="card"><div class="row"><div class="grow"><div style="font-size:0.85rem;color:var(--text2)">Spent</div>' +
      '<div class="num" style="font-size:1.6rem;font-weight:800">' + U.fmt(sp.spent, b.currency) + '</div>' +
      '<div style="font-size:0.85rem;color:var(--text2)">of ' + U.fmt(b.limitMinor, b.currency) + ' · ' +
      U.fmt(sp.remaining, b.currency) + ' remaining</div></div>' +
      '<span class="num" style="font-weight:700;font-size:1.2rem">' + sp.pct + '%</span></div>' +
      '<div class="progress' + (sp.pct >= 100 ? ' over' : '') + '" style="margin-top:10px"><i style="width:' + Math.min(100, sp.pct) + '%"></i></div>' +
      '<div style="margin-top:10px;font-size:0.85rem;color:var(--text2)">' + U.fmtDate(b.startDate) + ' - ' + U.fmtDate(b.endDate) + '</div></div>' +
      '<div class="row" style="margin:14px 0"><button class="btn btn-ghost btn-sm" id="bd-edit" style="flex:1">Edit</button>' +
      '<button class="btn btn-ghost btn-sm" id="bd-arch" style="flex:1">Archive</button>' +
      '<button class="btn btn-danger btn-sm" id="bd-del" style="flex:1">Delete</button></div>' +
      '<h3>Matching expenses (' + txs.length + ')</h3><div class="card">' +
      (txs.length ? txs.slice(0, 60).map(U.txnRow).join('') : '<div class="empty"><h3>No spending yet</h3><p>Expenses in this budget\'s categories and period will appear here.</p></div>') + '</div>';
    var sh = U.openSheet(html, { noFocus: true });
    U.bindTxnRows(sh);
    sh.querySelector('#bd-edit').addEventListener('click', function () { U.closeSheet(); openForm(id); });
    sh.querySelector('#bd-arch').addEventListener('click', function () {
      window.DC.store.update(function (dd) {
        var x = dd.budgets.find(function (y) { return y.id === id; });
        if (x) x.archivedAt = Date.now();
      });
      U.closeSheet(); U.toast('Budget archived', 'ok'); U.render();
    });
    sh.querySelector('#bd-del').addEventListener('click', function () {
      U.confirmDlg('Delete budget?', 'The budget and its history are removed. Transactions are not affected.', 'Delete').then(function (yes) {
        if (!yes) return;
        window.DC.store.update(function (dd) { dd.budgets = dd.budgets.filter(function (x) { return x.id !== id; }); });
        U.closeSheet(); U.toast('Budget deleted', 'ok'); U.render();
      });
    });
  }

  // Budget threshold alerts: checked on app open, in-app notice, once per period.
  function checkAlerts() {
    var d = window.DC.doc();
    var changed = false;
    d.budgets.forEach(function (b) {
      if (b.archivedAt) return;
      var sp = C.budgetSpending(b, d.transactions);
      (b.thresholds || []).forEach(function (th) {
        if (sp.pct >= th && (b.notified || []).indexOf(th) === -1) {
          b.notified = (b.notified || []).concat([th]);
          changed = true;
          setTimeout(function () {
            U.toast('Budget "' + b.name + '" reached ' + th + '%', th >= 100 ? 'bad' : 'ok');
          }, 1200);
        }
      });
    });
    if (changed) window.DC.save();
  }

  window.DCBudgets = { openForm: openForm, checkAlerts: checkAlerts };
  U.register('budgets', render);
})();
