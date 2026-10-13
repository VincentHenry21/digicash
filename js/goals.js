/* DigiCash savings goals: create/edit, contributions, withdrawals, history. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney, C = window.DCCalc;

  function render(s) {
    var d = window.DC.doc();
    var goals = d.goals.filter(function (g) { return g.status === 'active'; });
    var html = '<div class="topbar"><h1 style="margin:0">Savings goals</h1>' +
      '<button class="iconbtn" id="g-add" aria-label="Add goal">' + I.svg('plus') + '</button></div>';
    if (!goals.length) {
      html += '<div class="empty"><div class="big">' + I.svg('target', 44) + '</div><h3>No savings goals</h3>' +
        '<p>Set a target, contribute over time, and watch it grow.</p>' +
        '<button class="btn" id="g-first">Create goal</button></div>';
    } else {
      goals.forEach(function (g) {
        var p = C.goalProgress(g, d.goalEvents);
        html += '<button class="acct" data-goal="' + g.id + '"><span class="ic" style="background:#39d98a22;color:#39d98a">' +
          I.svg('target', 22) + '</span><span class="grow"><strong>' + U.esc(g.name) + '</strong><br>' +
          '<span class="meta">' + U.fmt(p.saved, g.currency) + ' of ' + U.fmt(g.targetMinor, g.currency) + '</span>' +
          '<div class="progress" style="margin-top:8px"><i style="width:' + p.pct + '%"></i></div></span>' +
          '<span class="num" style="font-weight:700">' + p.pct + '%</span></button>';
      });
    }
    s.innerHTML = html;
    var add = function () { openForm(); };
    document.getElementById('g-add').addEventListener('click', add);
    var f = document.getElementById('g-first');
    if (f) f.addEventListener('click', add);
    s.querySelectorAll('[data-goal]').forEach(function (b) {
      b.addEventListener('click', function () { openDetail(b.getAttribute('data-goal')); });
    });
  }

  function openForm(editId) {
    var d = window.DC.doc();
    var e = editId ? d.goals.find(function (g) { return g.id === editId; }) : null;
    var prefs = window.DC.prefs();
    var cur = e ? e.currency : prefs.currency;
    var accts = d.accounts.filter(function (a) { return !a.archivedAt && a.currency === cur; });
    var sh = U.openSheet('<h2>' + (e ? 'Edit' : 'Create') + ' savings goal</h2>' +
      '<div class="field"><label>Goal name</label><input id="gf-name" maxlength="40" value="' +
      U.esc(e ? e.name : '') + '" placeholder="e.g. Emergency fund"><div class="err"></div></div>' +
      '<div class="field"><label>Target amount (' + cur + ')</label>' +
      '<input id="gf-target" inputmode="decimal" class="num" value="' +
      (e ? M.toMajor(e.targetMinor, e.currency) : '') + '"><div class="err"></div></div>' +
      '<div class="field"><label>Target date (optional)</label><input id="gf-date" type="date" value="' +
      (e && e.targetDate ? new Date(e.targetDate).toISOString().slice(0, 10) : '') + '"></div>' +
      '<div class="field"><label>Linked account (optional)</label><select id="gf-acct"><option value="">None</option>' +
      accts.map(function (a) {
        return '<option value="' + a.id + '"' + (e && e.accountId === a.id ? ' selected' : '') + '>' + U.esc(a.name) + '</option>';
      }).join('') + '</select><div class="hint">Contributions move money into this account; withdrawals move it back. Money is never counted twice.</div></div>' +
      '<button class="btn" id="gf-save" style="width:100%">' + (e ? 'Save changes' : 'Create goal') + '</button>');
    sh.querySelector('#gf-save').addEventListener('click', function () {
      var nm = sh.querySelector('#gf-name');
      if (!nm.value.trim()) { U.fieldError(nm, 'Name the goal.'); return; }
      U.fieldError(nm);
      var ti = sh.querySelector('#gf-target'), target = 0;
      try { target = M.parse(ti.value, cur); U.fieldError(ti); }
      catch (err) { U.fieldError(ti, err.message); return; }
      var dv = sh.querySelector('#gf-date').value;
      var rec = {
        name: nm.value.trim(), targetMinor: target, currency: cur,
        targetDate: dv ? new Date(dv + 'T12:00:00').getTime() : null,
        accountId: sh.querySelector('#gf-acct').value || null, updatedAt: Date.now()
      };
      var r;
      if (e) r = window.DC.store.update(function (dd) {
        var g = dd.goals.find(function (x) { return x.id === e.id; });
        if (g) Object.assign(g, rec);
      });
      else {
        rec.id = window.DCStore.uid('goal'); rec.createdAt = Date.now(); rec.status = 'active';
        r = window.DC.store.update(function (dd) { dd.goals.push(rec); });
      }
      if (r.ok) { U.closeSheet(); U.toast(e ? 'Goal updated' : 'Goal created', 'ok'); U.render(); }
      else U.toast('Save failed: ' + r.error, 'bad');
    });
  }

  function moveMoney(goal, type, amountMinor) {
    // type 'in' (contribute) or 'out' (withdraw). If linked, also post a
    // transfer to keep account and goal consistent without double counting.
    return window.DC.store.update(function (d) {
      var g = d.goals.find(function (x) { return x.id === goal.id; });
      if (!g) return;
      var now = Date.now();
      d.goalEvents.push({
        id: window.DCStore.uid('gev'), goalId: g.id, type: type, amountMinor: amountMinor,
        date: now, note: '', createdAt: now
      });
      if (g.accountId) {
        var a = d.accounts.find(function (x) { return x.id === g.accountId; });
        if (a) {
          d.transactions.push({
            id: window.DCStore.uid('txn'),
            type: type === 'in' ? 'expense' : 'income',
            amountMinor: amountMinor, currency: g.currency,
            categoryId: null, accountId: a.id, destAccountId: null,
            description: (type === 'in' ? 'Saved to ' : 'Withdrawn from ') + g.name,
            merchant: '', notes: 'Savings goal', tags: [],
            date: now, createdAt: now, updatedAt: now
          });
        }
      }
    });
  }

  function openDetail(id) {
    var d = window.DC.doc();
    var g = d.goals.find(function (x) { return x.id === id; });
    if (!g) return;
    var p = C.goalProgress(g, d.goalEvents);
    var evs = d.goalEvents.filter(function (e) { return e.goalId === id; })
      .sort(function (a, b) { return b.date - a.date; });
    var pace = '';
    if (g.targetDate && evs.length > 1 && p.remaining > 0) {
      var first = evs[evs.length - 1].date, days = Math.max(1, (Date.now() - first) / 86400000);
      var perDay = p.saved / days;
      if (perDay > 0) {
        var need = Math.ceil(p.remaining / perDay);
        var eta = new Date(Date.now() + need * 86400000);
        pace = '<div class="kv"><span class="k">At your current pace</span><span class="v">~' + U.fmtDate(eta.getTime()) + '</span></div>' +
          '<div class="hint">Estimate only, based on past contributions. Not a guarantee.</div>';
      }
    }
    var html = '<h2>' + U.esc(g.name) + '</h2>' +
      '<div class="card"><div class="num" style="font-size:1.8rem;font-weight:800">' + U.fmt(p.saved, g.currency) + '</div>' +
      '<div style="color:var(--text2);font-size:0.9rem">of ' + U.fmt(g.targetMinor, g.currency) + ' · ' + p.pct + '%</div>' +
      '<div class="progress" style="margin:12px 0"><i style="width:' + p.pct + '%"></i></div>' +
      (g.targetDate ? '<div class="kv"><span class="k">Target date</span><span class="v">' + U.fmtDate(g.targetDate) + '</span></div>' : '') +
      pace + '</div>' +
      '<div class="row" style="margin:14px 0"><button class="btn" id="gd-in" style="flex:1">Contribute</button>' +
      '<button class="btn btn-ghost" id="gd-out" style="flex:1">Withdraw</button></div>' +
      '<div class="row" style="margin-bottom:14px"><button class="btn btn-ghost btn-sm" id="gd-edit" style="flex:1">Edit</button>' +
      '<button class="btn btn-ghost btn-sm" id="gd-arch" style="flex:1">Archive</button></div>' +
      '<h3>History (' + evs.length + ')</h3><div class="card">' +
      (evs.length ? evs.map(function (e) {
        return '<div class="kv"><span class="k">' + U.fmtDate(e.date) + ' · ' + (e.type === 'in' ? 'Contribution' : 'Withdrawal') +
          '</span><span class="v num" style="color:' + (e.type === 'in' ? 'var(--income)' : 'var(--expense)') + '">' +
          (e.type === 'in' ? '+' : '-') + ' ' + U.fmt(e.amountMinor, g.currency) + '</span></div>';
      }).join('') : '<div class="empty"><h3>No contributions yet</h3><p>Every contribution and withdrawal is recorded here.</p></div>') + '</div>';
    var sh = U.openSheet(html, { noFocus: true });

    function amountDlg(title, type) {
      var s2 = U.openSheet('<h2>' + title + '</h2>' +
        '<div class="field"><label>Amount (' + g.currency + ')</label>' +
        '<input id="ga-amt" inputmode="decimal" class="num" style="font-size:1.5rem"><div class="err"></div></div>' +
        '<button class="btn" id="ga-ok" style="width:100%">Confirm</button>');
      s2.querySelector('#ga-ok').addEventListener('click', function () {
        var inp = s2.querySelector('#ga-amt'), minor = 0;
        try { minor = M.parse(inp.value, g.currency); U.fieldError(inp); }
        catch (err) { U.fieldError(inp, err.message); return; }
        if (type === 'out') {
          var cur2 = C.goalProgress(g, window.DC.doc().goalEvents);
          if (minor > cur2.saved) { U.fieldError(inp, 'Cannot withdraw more than saved.'); return; }
        }
        var r = moveMoney(g, type, minor);
        if (r.ok) { U.closeSheet(); U.toast(type === 'in' ? 'Contribution recorded' : 'Withdrawal recorded', 'ok'); U.render(); }
        else U.toast('Failed: ' + r.error, 'bad');
      });
    }
    sh.querySelector('#gd-in').addEventListener('click', function () { amountDlg('Contribute to ' + g.name, 'in'); });
    sh.querySelector('#gd-out').addEventListener('click', function () { amountDlg('Withdraw from ' + g.name, 'out'); });
    sh.querySelector('#gd-edit').addEventListener('click', function () { U.closeSheet(); openForm(id); });
    sh.querySelector('#gd-arch').addEventListener('click', function () {
      window.DC.store.update(function (dd) {
        var x = dd.goals.find(function (y) { return y.id === id; });
        if (x) x.status = 'archived';
      });
      U.closeSheet(); U.toast('Goal archived', 'ok'); U.render();
    });
  }

  window.DCGoals = { openForm: openForm };
  U.register('goals', render);
})();
