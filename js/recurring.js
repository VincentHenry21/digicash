/* DigiCash recurring transactions: templates, pause/resume, history. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney;

  var FREQS = [['daily', 'Daily'], ['weekly', 'Weekly'], ['monthly', 'Monthly'], ['yearly', 'Yearly']];

  function render(s) {
    var d = window.DC.doc();
    var html = '<div class="topbar"><button class="iconbtn" id="r-back" aria-label="Back">' + I.svg('back') +
      '</button><h1 style="margin:0">Recurring</h1>' +
      '<button class="iconbtn" id="r-add" aria-label="Add recurring">' + I.svg('plus') + '</button></div>' +
      '<p>Scheduled templates generate real transactions when they come due. A scheduled entry is never recorded as confirmed bank activity, only as your own manual record.</p>';
    if (!d.recurring.length) {
      html += '<div class="empty"><div class="big">' + I.svg('repeat', 44) + '</div><h3>No recurring entries</h3>' +
        '<p>Set up repeating income or expenses like salary or phone bills.</p>' +
        '<button class="btn" id="r-first">Add recurring</button></div>';
    } else {
      d.recurring.forEach(function (t) {
        var cat = U.catById(t.categoryId);
        html += '<div class="card"><div class="row">' + U.catChip(cat) +
          '<div class="grow"><strong>' + U.esc(t.description || cat.name) + '</strong><br>' +
          '<span class="meta">' + freqName(t.freq) + ' · Next ' + U.fmtDate(t.nextDate) +
          (t.paused ? ' · Paused' : '') + '</span></div>' +
          '<span class="num" style="font-weight:700">' + (t.type === 'income' ? '+' : '-') + ' ' + U.fmt(t.amountMinor, t.currency) + '</span></div>' +
          '<div class="row" style="margin-top:10px"><button class="btn btn-ghost btn-sm" data-rp="' + t.id + '" style="flex:1">' +
          (t.paused ? 'Resume' : 'Pause') + '</button>' +
          '<button class="btn btn-ghost btn-sm" data-re="' + t.id + '" style="flex:1">Edit</button>' +
          '<button class="btn btn-danger btn-sm" data-rd="' + t.id + '" style="flex:1">Delete</button></div></div>';
      });
    }
    s.innerHTML = html;
    document.getElementById('r-back').addEventListener('click', U.back);
    var add = function () { openForm(); };
    document.getElementById('r-add').addEventListener('click', add);
    var f = document.getElementById('r-first');
    if (f) f.addEventListener('click', add);
    s.querySelectorAll('[data-rp]').forEach(function (b) {
      b.addEventListener('click', function () {
        var id = b.getAttribute('data-rp');
        window.DC.store.update(function (dd) {
          var t = dd.recurring.find(function (x) { return x.id === id; });
          if (t) t.paused = !t.paused;
        });
        U.render();
      });
    });
    s.querySelectorAll('[data-re]').forEach(function (b) {
      b.addEventListener('click', function () { openForm(b.getAttribute('data-re')); });
    });
    s.querySelectorAll('[data-rd]').forEach(function (b) {
      b.addEventListener('click', function () {
        var id = b.getAttribute('data-rd');
        U.confirmDlg('Delete recurring entry?', 'The template is removed. Already generated transactions stay.', 'Delete').then(function (yes) {
          if (!yes) return;
          window.DC.store.update(function (dd) { dd.recurring = dd.recurring.filter(function (x) { return x.id !== id; }); });
          U.toast('Recurring entry deleted', 'ok'); U.render();
        });
      });
    });
  }

  function freqName(f) {
    var m = { daily: 'Daily', weekly: 'Weekly', monthly: 'Monthly', yearly: 'Yearly' };
    return m[f] || f;
  }

  function openForm(editId) {
    var d = window.DC.doc();
    var e = editId ? d.recurring.find(function (t) { return t.id === editId; }) : null;
    var accts = d.accounts.filter(function (a) { return !a.archivedAt; });
    if (!accts.length) { U.toast('Create an account first', 'bad'); return; }
    var type = e ? e.type : 'expense';
    var freq = e ? e.freq : 'monthly';
    var acctId = e ? e.accountId : accts[0].id;
    var cur = (accts.find(function (a) { return a.id === acctId; }) || {}).currency || window.DC.prefs().currency;

    function catOptions() {
      return d.categories.filter(function (c) { return c.type === type; })
        .map(function (c) { return '<option value="' + c.id + '"' + (e && e.categoryId === c.id ? ' selected' : '') + '>' + U.esc(c.name) + '</option>'; }).join('');
    }

    var sh = U.openSheet('<h2>' + (e ? 'Edit' : 'Add') + ' recurring</h2>' +
      '<div class="field"><label>Type</label><div class="seg" id="rf-type">' +
      '<button data-v="expense" aria-selected="' + (type === 'expense') + '">Expense</button>' +
      '<button data-v="income" aria-selected="' + (type === 'income') + '">Income</button></div></div>' +
      '<div class="field"><label>Amount (<span id="rf-cur">' + cur + '</span>)</label>' +
      '<input id="rf-amt" inputmode="decimal" class="num" value="' + (e ? M.toMajor(e.amountMinor, e.currency) : '') + '"><div class="err"></div></div>' +
      '<div class="field"><label>Account</label><select id="rf-acct">' +
      accts.map(function (a) {
        return '<option value="' + a.id + '"' + (acctId === a.id ? ' selected' : '') + '>' + U.esc(a.name) + ' (' + a.currency + ')</option>';
      }).join('') + '</select><div class="hint">Amount uses the account currency.</div></div>' +
      '<div class="field"><label>Category</label><select id="rf-cat">' + catOptions() + '</select></div>' +
      '<div class="field"><label>Repeats</label><div class="seg" id="rf-freq">' +
      FREQS.map(function (o) {
        return '<button data-v="' + o[0] + '" aria-selected="' + (freq === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="field"><label>Description</label><input id="rf-desc" maxlength="80" value="' + U.esc(e ? e.description || '' : '') + '"></div>' +
      '<div class="field"><label>First date</label><input id="rf-date" type="date" value="' +
      new Date(e ? e.nextDate : Date.now()).toISOString().slice(0, 10) + '"></div>' +
      '<button class="btn" id="rf-save" style="width:100%">' + (e ? 'Save changes' : 'Add recurring') + '</button>');

    function sync(id, fn) {
      sh.querySelectorAll('#' + id + ' button').forEach(function (b) {
        b.addEventListener('click', function () {
          fn(b.getAttribute('data-v'));
          sh.querySelectorAll('#' + id + ' button').forEach(function (x) { x.setAttribute('aria-selected', 'false'); });
          b.setAttribute('aria-selected', 'true');
        });
      });
    }
    sync('rf-type', function (v) {
      type = v;
      sh.querySelector('#rf-cat').innerHTML = d.categories.filter(function (c) { return c.type === type; })
        .map(function (c) { return '<option value="' + c.id + '">' + U.esc(c.name) + '</option>'; }).join('');
    });
    sync('rf-freq', function (v) { freq = v; });
    sh.querySelector('#rf-acct').addEventListener('change', function (ev) {
      acctId = ev.target.value;
      var a = accts.find(function (x) { return x.id === acctId; });
      cur = a ? a.currency : cur;
      sh.querySelector('#rf-cur').textContent = cur;
    });
    sh.querySelector('#rf-save').addEventListener('click', function () {
      var ai = sh.querySelector('#rf-amt'), minor = 0;
      try { minor = M.parse(ai.value, cur); U.fieldError(ai); }
      catch (err) { U.fieldError(ai, err.message); return; }
      var dv = sh.querySelector('#rf-date').value;
      var rec = {
        type: type, amountMinor: minor, currency: cur, accountId: acctId,
        categoryId: sh.querySelector('#rf-cat').value, description: sh.querySelector('#rf-desc').value.trim(),
        freq: freq, interval: 1,
        startDate: dv ? new Date(dv + 'T12:00:00').getTime() : Date.now(),
        nextDate: dv ? new Date(dv + 'T12:00:00').getTime() : Date.now(),
        endDate: null, paused: e ? e.paused : false, updatedAt: Date.now()
      };
      var r;
      if (e) r = window.DC.store.update(function (dd) {
        var t = dd.recurring.find(function (x) { return x.id === e.id; });
        if (t) Object.assign(t, rec);
      });
      else {
        rec.id = window.DCStore.uid('rec'); rec.createdAt = Date.now();
        r = window.DC.store.update(function (dd) { dd.recurring.push(rec); });
      }
      if (r.ok) { U.closeSheet(); window.DC.runRecurring(); U.toast(e ? 'Recurring updated' : 'Recurring added', 'ok'); U.render(); }
      else U.toast('Save failed: ' + r.error, 'bad');
    });
  }

  window.DCRecurring = { openForm: openForm };
  U.register('recurring', render);
})();
