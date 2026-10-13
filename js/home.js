/* DigiCash Home dashboard. Every number derives from stored records. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, C = window.DCCalc;

  var period = 'month'; // week | month | lastmonth | custom
  var customFrom = null, customTo = null;
  var acctFilter = 'all';
  var prevBal = null; // last rendered total, for the balance tween

  // Tween the balance number from the previously rendered value.
  // State-driven: only runs when the balance actually changed.
  function tweenBalance(el, totalMinor, cur, hidden) {
    var from = (prevBal === null || prevBal === undefined) ? totalMinor : prevBal;
    prevBal = totalMinor;
    if (hidden || U.reduceMotion || from === totalMinor) return;
    var t0 = performance.now(), dur = 650;
    function frame(t) {
      var p = Math.min(1, (t - t0) / dur);
      var e = 1 - Math.pow(1 - p, 3);
      el.textContent = U.fmt(Math.round(from + (totalMinor - from) * e), cur);
      if (p < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  function periodRange() {
    var now = new Date(), ws = window.DC.prefs().weekStart;
    var start, end;
    if (period === 'week') {
      var day = (now.getDay() - ws + 7) % 7;
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - day);
      end = new Date(start); end.setDate(end.getDate() + 6);
    } else if (period === 'month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1);
      end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    } else if (period === 'lastmonth') {
      start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      end = new Date(now.getFullYear(), now.getMonth(), 0);
    } else {
      start = new Date(customFrom); end = new Date(customTo);
    }
    start.setHours(0, 0, 0, 0); end.setHours(23, 59, 59, 999);
    return { from: start.getTime(), to: end.getTime() };
  }

  function periodLabel() {
    var r = periodRange();
    return U.fmtDate(r.from) + ' - ' + U.fmtDate(r.to);
  }

  function visibleAccounts() {
    var d = window.DC.doc();
    return d.accounts.filter(function (a) { return !a.archivedAt; });
  }

  function render(s) {
    var d = window.DC.doc(), prefs = window.DC.prefs();
    var accts = visibleAccounts();
    var cur = prefs.currency;
    var balances = C.allBalances(accts, d.transactions);

    // Total: same-currency sum; other currencies converted only via explicit manual rates
    var totalMinor = 0, convertedNote = false, unconverted = [];
    accts.forEach(function (a) {
      if (acctFilter !== 'all' && a.id !== acctFilter) return;
      var b = balances[a.id] || 0;
      if (a.currency === cur) totalMinor += b;
      else {
        var rate = d.rates.find(function (r) { return r.code === a.currency; });
        if (rate && rate.perUnitMMK > 0 && cur === 'MMK') {
          // convert to MMK via manual rate (integer math)
          totalMinor += Math.round(b * rate.perUnitMMK);
          convertedNote = true;
        } else unconverted.push({ acct: a, bal: b });
      }
    });

    var hidden = prefs.balanceHidden;
    var mask = function (v) { return hidden ? '••••••' : v; };

    var r = periodRange();
    var t = C.periodTotals(d.transactions.filter(function (tx) {
      return acctFilter === 'all' || tx.accountId === acctFilter || tx.destAccountId === acctFilter;
    }), { fromMs: r.from, toMs: r.to, currency: cur });

    var html = '<div class="topbar"><div class="brand">' +
      '<img src="./assets/logo-transparent.png" alt="">DIGI:CASH</div>' +
      '<div class="row"><button class="iconbtn" id="h-set" aria-label="Settings">' + I.svg('gear') + '</button></div></div>';

    // account selector
    html += '<div class="field" style="margin-bottom:10px"><select id="h-acct" aria-label="Account filter">' +
      '<option value="all">All accounts</option>' +
      accts.map(function (a) {
        return '<option value="' + a.id + '"' + (acctFilter === a.id ? ' selected' : '') + '>' +
          U.esc(a.name) + ' (' + a.currency + ')</option>';
      }).join('') + '</select></div>';

    html += '<div class="balance-card"><button class="eye" id="h-eye" aria-label="' +
      (hidden ? 'Show balance' : 'Hide balance') + '">' + I.svg(hidden ? 'eyeoff' : 'eye', 20) + '</button>' +
      '<div class="lbl">Total Balance' + (acctFilter !== 'all' ? ' · ' + U.esc((accts.find(function (a) { return a.id === acctFilter; }) || {}).name || '') : '') + '</div>' +
      '<div class="val num" id="h-balval">' + mask(U.fmt(totalMinor, cur)) + '</div>' +
      '<div class="sub">' + U.esc(periodLabel()) + '</div></div>';
    if (convertedNote && !hidden)
      html += '<p style="font-size:0.78rem">Includes conversion at your manual exchange rates.</p>';
    unconverted.forEach(function (u) {
      html += '<p style="font-size:0.78rem">+' + mask(U.fmt(u.bal, u.acct.currency)) +
        ' in ' + U.esc(u.acct.name) + ' (no manual rate set, not converted)</p>';
    });

    // period selector + flow
    html += '<div class="sect-head"><h2>Cash flow</h2></div>' +
      '<div class="seg" role="group" aria-label="Period">' +
      [['week', 'Week'], ['month', 'Month'], ['lastmonth', 'Last mo.']].map(function (p) {
        return '<button data-per="' + p[0] + '" aria-selected="' + (period === p[0]) + '">' + p[1] + '</button>';
      }).join('') + '</div>' +
      '<div class="flow3">' +
      '<div class="cell"><div class="l">Income</div><div class="n num in">' + mask(U.fmt(t.income, cur)) + '</div></div>' +
      '<div class="cell"><div class="l">Expenses</div><div class="n num out">' + mask(U.fmt(t.expense, cur)) + '</div></div>' +
      '<div class="cell"><div class="l">Net</div><div class="n num">' + mask((t.net < 0 ? '- ' : '+ ') + U.fmt(Math.abs(t.net), cur)) + '</div></div></div>';

    // spending chart (real data)
    var bucket = period === 'week' ? 'day' : 'day';
    var series = C.groupBy(d.transactions, 'day', cur, r.from, r.to, prefs.weekStart).slice(-14);
    html += '<div class="sect-head"><h2>Spending</h2></div><div class="card">' +
      (series.length ? '<canvas class="chart" id="h-chart" aria-label="Daily spending chart"></canvas>' +
        '<div class="legend"><span><i style="background:#39d98a"></i>Income</span><span><i style="background:#9409b6"></i>Expenses</span></div>'
        : '<div class="empty"><h3>No data for this period</h3><p>Add a transaction to see your spending chart.</p></div>') +
      '</div>';

    // quick actions
    html += '<div class="sect-head"><h2>Quick actions</h2></div><div class="quick">' +
      '<button data-qa="expense">' + I.svg('minus') + 'Expense</button>' +
      '<button data-qa="income">' + I.svg('plus') + 'Income</button>' +
      '<button data-qa="transfer">' + I.svg('swap') + 'Transfer</button>' +
      '<button data-qa="all">' + I.svg('list') + 'Activity</button></div>';

    // recent transactions
    var recent = d.transactions.slice().sort(function (a, b) { return b.date - a.date; }).slice(0, 5);
    html += '<div class="sect-head"><h2>Recent</h2><button class="link" id="h-all">View all</button></div><div class="card">' +
      (recent.length ? recent.map(U.txnRow).join('')
        : '<div class="empty"><h3>No transactions yet</h3><p>Your recent activity will appear here.</p>' +
          '<button class="btn" id="h-first">Add your first transaction</button></div>') + '</div>';

    // budgets overview
    var budgets = d.budgets.filter(function (b) { return !b.archivedAt; }).slice(0, 3);
    if (budgets.length) {
      html += '<div class="sect-head"><h2>Budgets</h2><button class="link" id="h-bud">View all</button></div>';
      budgets.forEach(function (b) {
        var sp = C.budgetSpending(b, d.transactions);
        html += '<div class="card"><div class="row"><div class="grow"><strong>' + U.esc(b.name) + '</strong>' +
          '<div style="font-size:0.82rem;color:var(--text2)">' + mask(U.fmt(sp.spent, b.currency)) + ' of ' +
          mask(U.fmt(b.limitMinor, b.currency)) + '</div></div>' +
          '<span class="num" style="font-weight:700">' + sp.pct + '%</span></div>' +
          '<div class="progress' + (sp.pct >= 100 ? ' over' : '') + '" style="margin-top:10px"><i style="width:' +
          Math.min(100, sp.pct) + '%"></i></div></div>';
      });
    }

    // goals overview
    var goals = d.goals.filter(function (g) { return g.status === 'active'; }).slice(0, 3);
    if (goals.length) {
      html += '<div class="sect-head"><h2>Savings goals</h2></div>';
      goals.forEach(function (g) {
        var p = C.goalProgress(g, d.goalEvents);
        html += '<div class="card"><div class="row"><div class="grow"><strong>' + U.esc(g.name) + '</strong>' +
          '<div style="font-size:0.82rem;color:var(--text2)">' + mask(U.fmt(p.saved, g.currency)) + ' of ' +
          mask(U.fmt(g.targetMinor, g.currency)) + '</div></div>' +
          '<span class="num" style="font-weight:700">' + p.pct + '%</span></div>' +
          '<div class="progress" style="margin-top:10px"><i style="width:' + p.pct + '%"></i></div></div>';
      });
    }

    s.innerHTML = html;

    tweenBalance(document.getElementById('h-balval'), totalMinor, cur, hidden);

    document.getElementById('h-set').addEventListener('click', function () { U.go('settings'); });
    document.getElementById('h-acct').addEventListener('change', function (e) { acctFilter = e.target.value; U.render(); });
    document.getElementById('h-eye').addEventListener('click', function () {
      window.DC.store.update(function (dd) { dd.prefs.balanceHidden = !dd.prefs.balanceHidden; });
    });
    s.querySelectorAll('[data-per]').forEach(function (b) {
      b.addEventListener('click', function () { period = b.getAttribute('data-per'); U.render(); });
    });
    s.querySelectorAll('[data-qa]').forEach(function (b) {
      b.addEventListener('click', function () {
        var q = b.getAttribute('data-qa');
        if (q === 'all') U.go('transactions', {}, true);
        else window.DCTxn.openForm(q);
      });
    });
    var ha = document.getElementById('h-all');
    if (ha) ha.addEventListener('click', function () { U.go('transactions', {}, true); });
    var hf = document.getElementById('h-first');
    if (hf) hf.addEventListener('click', function () { window.DCTxn.openForm('expense'); });
    var hb = document.getElementById('h-bud');
    if (hb) hb.addEventListener('click', function () { U.go('budgets', {}, true); });

    var cv = document.getElementById('h-chart');
    if (cv && series.length) {
      U.drawBars(cv, series.map(function (x) {
        var dt = x.key.split('-');
        return { label: dt[2] + '/' + dt[1], income: x.income, expense: x.expense };
      }), { currency: cur });
      cv.setAttribute('aria-label', 'Daily income and expenses, ' + periodLabel());
    }
  }

  window.DCHome = { render: render, periodRange: periodRange };
  U.register('home', render);
})();
