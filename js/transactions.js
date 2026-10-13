/* DigiCash transactions: list, search/filter/sort, add/edit form, detail, delete. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney, C = window.DCCalc;

  var f = { q: '', type: 'all', cat: 'all', acct: 'all', sort: 'new', min: '', max: '' };

  function filtered() {
    var d = window.DC.doc();
    var out = d.transactions.filter(function (t) {
      if (f.type !== 'all' && t.type !== f.type) return false;
      if (f.cat !== 'all' && t.categoryId !== f.cat) return false;
      if (f.acct !== 'all' && t.accountId !== f.acct && t.destAccountId !== f.acct) return false;
      if (f.q) {
        var q = f.q.toLowerCase();
        var hay = ((t.description || '') + ' ' + (t.merchant || '') + ' ' + (t.notes || '')).toLowerCase();
        if (hay.indexOf(q) === -1) return false;
      }
      if (f.min !== '') { try { if (t.amountMinor < M.parse(f.min, t.currency)) return false; } catch (e) {} }
      if (f.max !== '') { try { if (t.amountMinor > M.parse(f.max, t.currency)) return false; } catch (e) {} }
      return true;
    });
    var by = {
      new: function (a, b) { return b.date - a.date; },
      old: function (a, b) { return a.date - b.date; },
      high: function (a, b) { return b.amountMinor - a.amountMinor; },
      low: function (a, b) { return a.amountMinor - b.amountMinor; }
    }[f.sort];
    return out.sort(by);
  }

  function render(s) {
    var d = window.DC.doc();
    var list = filtered();
    var html = '<div class="topbar"><h1 style="margin:0">Activity</h1>' +
      '<button class="iconbtn" id="t-filter" aria-label="Filters">' + I.svg('search') + '</button></div>' +
      '<div class="field"><input id="t-q" placeholder="Search transactions" value="' + U.esc(f.q) + '" aria-label="Search"></div>';
    var activeF = (f.type !== 'all' || f.cat !== 'all' || f.acct !== 'all' || f.min !== '' || f.max !== '');
    if (activeF) html += '<p><button class="chip" id="t-clear">' + I.svg('x', 14) + ' Clear filters</button></p>';
    html += '<div class="card">';
    if (!d.transactions.length) {
      html += '<div class="empty"><h3>No transactions yet</h3><p>Add your first transaction to start tracking.</p>' +
        '<button class="btn" id="t-first">Add transaction</button></div>';
    } else if (!list.length) {
      html += '<div class="empty"><h3>No matching transactions</h3><p>Try clearing or changing your filters.</p></div>';
    } else {
      html += list.slice(0, 200).map(U.txnRow).join('');
      if (list.length > 200) html += '<p style="text-align:center">Showing 200 of ' + list.length + '.</p>';
    }
    html += '</div>';
    s.innerHTML = html;

    document.getElementById('t-q').addEventListener('input', function (e) { f.q = e.target.value; render(s); keepFocus(); });
    document.getElementById('t-filter').addEventListener('click', openFilters);
    var c = document.getElementById('t-clear');
    if (c) c.addEventListener('click', function () {
      f = { q: '', type: 'all', cat: 'all', acct: 'all', sort: 'new', min: '', max: '' }; U.render();
    });
    var tf = document.getElementById('t-first');
    if (tf) tf.addEventListener('click', function () { openForm('expense'); });
  }

  var qEl = null;
  function keepFocus() {
    // keep search focus while typing (re-render steals it)
    var q = document.getElementById('t-q');
    if (q) { q.focus(); var v = q.value; q.value = ''; q.value = v; }
  }

  function openFilters() {
    var d = window.DC.doc();
    var sh = U.openSheet('<h2>Filters</h2>' +
      '<div class="field"><label>Type</label><div class="seg" id="ff-type">' +
      [['all', 'All'], ['expense', 'Expense'], ['income', 'Income'], ['transfer', 'Transfer'], ['refund', 'Refund']].map(function (o) {
        return '<button data-v="' + o[0] + '" aria-selected="' + (f.type === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="field"><label>Category</label><select id="ff-cat"><option value="all">All</option>' +
      d.categories.map(function (c) {
        return '<option value="' + c.id + '"' + (f.cat === c.id ? ' selected' : '') + '>' + U.esc(c.name) + '</option>';
      }).join('') + '</select></div>' +
      '<div class="field"><label>Account</label><select id="ff-acct"><option value="all">All</option>' +
      d.accounts.map(function (a) {
        return '<option value="' + a.id + '"' + (f.acct === a.id ? ' selected' : '') + '>' + U.esc(a.name) + '</option>';
      }).join('') + '</select></div>' +
      '<div class="row"><div class="field grow"><label>Min amount</label><input id="ff-min" inputmode="decimal" value="' + U.esc(f.min) + '"></div>' +
      '<div class="field grow"><label>Max amount</label><input id="ff-max" inputmode="decimal" value="' + U.esc(f.max) + '"></div></div>' +
      '<div class="field"><label>Sort</label><div class="seg" id="ff-sort">' +
      [['new', 'Newest'], ['old', 'Oldest'], ['high', 'Highest'], ['low', 'Lowest']].map(function (o) {
        return '<button data-v="' + o[0] + '" aria-selected="' + (f.sort === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      '<button class="btn" id="ff-apply" style="width:100%">Apply</button>');
    function seg(id, key) {
      sh.querySelectorAll('#' + id + ' button').forEach(function (b) {
        b.addEventListener('click', function () {
          f[key] = b.getAttribute('data-v');
          sh.querySelectorAll('#' + id + ' button').forEach(function (x) { x.setAttribute('aria-selected', 'false'); });
          b.setAttribute('aria-selected', 'true');
        });
      });
    }
    seg('ff-type', 'type'); seg('ff-sort', 'sort');
    sh.querySelector('#ff-apply').addEventListener('click', function () {
      f.cat = sh.querySelector('#ff-cat').value;
      f.acct = sh.querySelector('#ff-acct').value;
      f.min = sh.querySelector('#ff-min').value.trim();
      f.max = sh.querySelector('#ff-max').value.trim();
      U.closeSheet(); U.render();
    });
  }

  // ---------- form ----------
  var formState = null;

  function openForm(presetType, editId) {
    var d = window.DC.doc();
    var accts = d.accounts.filter(function (a) { return !a.archivedAt; });
    if (!accts.length) { U.toast('Create an account first', 'bad'); U.go('settings'); return; }
    var editing = editId ? d.transactions.find(function (t) { return t.id === editId; }) : null;
    formState = {
      editId: editId || null,
      type: editing ? editing.type : (presetType || 'expense'),
      accountId: editing ? editing.accountId : accts[0].id,
      destAccountId: editing ? editing.destAccountId : (accts[1] ? accts[1].id : accts[0].id),
      categoryId: editing ? editing.categoryId : null,
      date: editing ? editing.date : Date.now()
    };
    renderForm(editing);
  }

  function formCurrency() {
    var a = U.acctById(formState.accountId);
    return a ? a.currency : window.DC.prefs().currency;
  }

  function renderForm(editing) {
    var d = window.DC.doc();
    var accts = d.accounts.filter(function (a) { return !a.archivedAt; });
    var cur = formCurrency();
    var cats = d.categories.filter(function (c) {
      return formState.type === 'income' ? c.type === 'income' : c.type === 'expense';
    });
    if (formState.type === 'transfer' || formState.type === 'refund') cats = [];
    if (!formState.categoryId || cats.every(function (c) { return c.id !== formState.categoryId; })) {
      formState.categoryId = cats.length ? cats[0].id : null;
    }

    var html = '<h2>' + (editing ? 'Edit' : 'Add') + ' ' + formState.type.charAt(0).toUpperCase() + formState.type.slice(1) + '</h2>' +
      '<div class="field"><label>Type</label><div class="seg" id="xf-type">' +
      [['expense', 'Expense'], ['income', 'Income'], ['transfer', 'Transfer'], ['refund', 'Refund']].map(function (o) {
        return '<button data-v="' + o[0] + '" aria-selected="' + (formState.type === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="field"><label>Amount (' + cur + ')</label>' +
      '<input id="xf-amt" inputmode="decimal" class="num" style="font-size:1.6rem" placeholder="0" value="' +
      (editing ? M.toMajor(editing.amountMinor, editing.currency) : '') + '"><div class="err"></div>' +
      (cur === 'MMK' ? '<div class="hint">Whole kyat, no decimals.</div>' : '') + '</div>';

    if (formState.type === 'transfer') {
      html += '<div class="row"><div class="field grow"><label>From</label><select id="xf-acct">' +
        accts.map(function (a) { return '<option value="' + a.id + '"' + (formState.accountId === a.id ? ' selected' : '') + '>' + U.esc(a.name) + ' (' + a.currency + ')</option>'; }).join('') +
        '</select></div><div class="field grow"><label>To</label><select id="xf-dest">' +
        accts.map(function (a) { return '<option value="' + a.id + '"' + (formState.destAccountId === a.id ? ' selected' : '') + '>' + U.esc(a.name) + ' (' + a.currency + ')</option>'; }).join('') +
        '</select><div class="err"></div></div></div>' +
        '<p style="font-size:0.82rem">Transfers move money between your accounts. They are never counted as income or expenses. Cross-currency transfers are not supported.</p>';
    } else {
      html += '<div class="field"><label>Account</label><select id="xf-acct">' +
        accts.map(function (a) { return '<option value="' + a.id + '"' + (formState.accountId === a.id ? ' selected' : '') + '>' + U.esc(a.name) + ' (' + a.currency + ')</option>'; }).join('') +
        '</select></div>';
    }

    if (cats.length) {
      html += '<div class="field"><label>Category</label><div class="catgrid" id="xf-cats">' +
        cats.map(function (c) {
          return '<button data-c="' + c.id + '" aria-pressed="' + (formState.categoryId === c.id) + '">' +
            U.catChip(c, 19) + '<span>' + U.esc(c.name) + '</span></button>';
        }).join('') + '</div></div>';
    }

    var dt = new Date(formState.date);
    var iso = dt.getFullYear() + '-' + String(dt.getMonth() + 1).padStart(2, '0') + '-' + String(dt.getDate()).padStart(2, '0');
    html += '<div class="field"><label>Date</label><input id="xf-date" type="date" value="' + iso + '"><div class="err"></div></div>' +
      '<div class="field"><label>Description</label><input id="xf-desc" maxlength="80" placeholder="e.g. Lunch at Feel" value="' +
      U.esc(editing ? editing.description || '' : '') + '"></div>' +
      '<div class="field"><label>Merchant / payee (optional)</label><input id="xf-merch" maxlength="80" value="' +
      U.esc(editing ? editing.merchant || '' : '') + '"></div>' +
      '<div class="field"><label>Notes (optional)</label><textarea id="xf-notes">' +
      U.esc(editing ? editing.notes || '' : '') + '</textarea></div>' +
      '<button class="btn" id="xf-save" style="width:100%">' + (editing ? 'Save changes' : 'Add ' + formState.type) + '</button>';

    var sh = U.openSheet(html);
    sh.querySelectorAll('#xf-type button').forEach(function (b) {
      b.addEventListener('click', function () {
        formState.type = b.getAttribute('data-v');
        if (formState.type === 'transfer' && formState.accountId === formState.destAccountId) {
          var other = accts.find(function (a) { return a.id !== formState.accountId; });
          if (other) formState.destAccountId = other.id;
        }
        renderForm(editing);
      });
    });
    sh.querySelectorAll('#xf-cats button').forEach(function (b) {
      b.addEventListener('click', function () {
        formState.categoryId = b.getAttribute('data-c');
        sh.querySelectorAll('#xf-cats button').forEach(function (x) { x.setAttribute('aria-pressed', 'false'); });
        b.setAttribute('aria-pressed', 'true');
      });
    });
    var acctSel = sh.querySelector('#xf-acct');
    if (acctSel) acctSel.addEventListener('change', function () { formState.accountId = acctSel.value; renderForm(editing); });
    var destSel = sh.querySelector('#xf-dest');
    if (destSel) destSel.addEventListener('change', function () { formState.destAccountId = destSel.value; });
    sh.querySelector('#xf-save').addEventListener('click', function () { saveForm(sh, editing); });
  }

  function saveForm(sh, editing) {
    var ok = true;
    var amtInp = sh.querySelector('#xf-amt');
    var cur = formCurrency();
    var minor = 0;
    try { minor = M.parse(amtInp.value, cur); U.fieldError(amtInp); }
    catch (e) { U.fieldError(amtInp, e.message); ok = false; }

    var dateInp = sh.querySelector('#xf-date');
    var dv = dateInp.value.split('-');
    var dateMs = new Date(+dv[0], +dv[1] - 1, +dv[2], 12, 0, 0).getTime();
    if (!dateInp.value || isNaN(dateMs)) { U.fieldError(dateInp, 'Pick a valid date.'); ok = false; }
    else U.fieldError(dateInp);

    if (formState.type === 'transfer') {
      if (formState.accountId === formState.destAccountId) {
        var ds = sh.querySelector('#xf-dest');
        U.fieldError(ds, 'Pick a different destination account.'); ok = false;
      } else U.fieldError(sh.querySelector('#xf-dest'));
      var sa = U.acctById(formState.accountId), da = U.acctById(formState.destAccountId);
      if (sa && da && sa.currency !== da.currency) {
        U.toast('Cross-currency transfers are not supported.', 'bad'); ok = false;
      }
    }
    if (!ok) return;

    var btn = sh.querySelector('#xf-save');
    btn.disabled = true; // prevent duplicate submissions

    var rec = {
      type: formState.type, amountMinor: minor, currency: cur,
      categoryId: formState.type === 'transfer' ? null : formState.categoryId,
      accountId: formState.accountId,
      destAccountId: formState.type === 'transfer' ? formState.destAccountId : null,
      description: sh.querySelector('#xf-desc').value.trim(),
      merchant: sh.querySelector('#xf-merch').value.trim(),
      notes: sh.querySelector('#xf-notes').value.trim(),
      tags: editing ? editing.tags || [] : [],
      date: dateMs, updatedAt: Date.now()
    };

    var r;
    if (editing) {
      r = window.DC.store.update(function (d) {
        var t = d.transactions.find(function (x) { return x.id === editing.id; });
        if (t) Object.assign(t, rec);
      });
    } else {
      rec.id = window.DCStore.uid('txn');
      rec.createdAt = Date.now();
      r = window.DC.store.update(function (d) { d.transactions.push(Object.assign({}, rec)); });
    }
    if (r.ok) {
      U.closeSheet();
      U.toast(editing ? 'Transaction updated' : 'Transaction saved', 'ok');
      if (!editing) U.noteNewTxn(rec.id); // animate the new row in on next render
      if (U.name() !== 'home' && U.name() !== 'transactions') U.go('transactions', {}, true);
      else U.render();
    } else {
      btn.disabled = false;
      U.toast('Save failed: ' + r.error + ' Your entries are kept.', 'bad');
    }
  }

  // ---------- detail ----------
  function openDetail(id) {
    var d = window.DC.doc();
    var t = d.transactions.find(function (x) { return x.id === id; });
    if (!t) { U.toast('Transaction not found', 'bad'); return; }
    var cat = t.type === 'transfer' ? { name: 'Transfer', icon: 'swap', color: 'purple' } : U.catById(t.categoryId);
    var acct = U.acctById(t.accountId);
    var html = '<h2>Transaction</h2><div class="row" style="margin-bottom:8px">' + U.catChip(cat, 24) +
      '<div class="grow"><strong>' + U.esc(t.description || cat.name) + '</strong><br>' +
      '<span class="badge ' + ((t.type === 'income' || t.type === 'refund') ? 'in' : t.type === 'transfer' ? 'info' : 'out') + '">' +
      t.type.charAt(0).toUpperCase() + t.type.slice(1) + '</span></div>' +
      '<div class="num" style="font-size:1.4rem;font-weight:800">' +
      (t.type === 'transfer' ? U.fmt(t.amountMinor, t.currency) : U.fmtSigned(t.amountMinor, t.currency, t.type)) +
      '</div></div><div class="card">' +
      kv('Date', U.fmtDateTime(t.date)) +
      kv('Account', acct ? U.esc(acct.name) : '-') +
      (t.type === 'transfer' ? kv('Destination', U.esc((U.acctById(t.destAccountId) || {}).name || '-')) : '') +
      (t.type !== 'transfer' ? kv('Category', U.esc(cat.name)) : '') +
      (t.merchant ? kv('Merchant', U.esc(t.merchant)) : '') +
      (t.notes ? kv('Notes', U.esc(t.notes)) : '') +
      (t.recurringId ? kv('Source', 'Recurring schedule') : '') +
      '</div><div class="row" style="margin-top:16px">' +
      '<button class="btn btn-ghost" id="td-edit" style="flex:1">Edit</button>' +
      '<button class="btn btn-danger" id="td-del" style="flex:1">Delete</button></div>';
    var sh = U.openSheet(html, { noFocus: true });
    sh.querySelector('#td-edit').addEventListener('click', function () { U.closeSheet(); openForm(null, t.id); });
    sh.querySelector('#td-del').addEventListener('click', function () {
      U.confirmDlg('Delete transaction?', 'This removes the record and recalculates all balances and budgets. This cannot be undone.', 'Delete').then(function (yes) {
        if (!yes) return;
        var r = window.DC.store.update(function (dd) {
          dd.transactions = dd.transactions.filter(function (x) { return x.id !== t.id; });
        });
        if (r.ok) { U.closeSheet(); U.toast('Transaction deleted', 'ok'); U.removeTxnAnimated(t.id); }
        else U.toast('Delete failed: ' + r.error, 'bad');
      });
    });
  }
  function kv(k, v) { return '<div class="kv"><span class="k">' + k + '</span><span class="v">' + v + '</span></div>'; }

  window.DCTxn = { openForm: openForm, openDetail: openDetail };
  U.register('transactions', render);
})();
