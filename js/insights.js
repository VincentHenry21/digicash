/* DigiCash Insights: real analytics from stored records. No fabricated trends. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, C = window.DCCalc;

  var range = 'month'; // week | month | 3m | 6m | year

  function rangeMs() {
    var now = new Date(), s;
    if (range === 'week') { s = new Date(now); s.setDate(s.getDate() - 7); }
    else if (range === '3m') s = new Date(now.getFullYear(), now.getMonth() - 3, now.getDate());
    else if (range === '6m') s = new Date(now.getFullYear(), now.getMonth() - 6, now.getDate());
    else if (range === 'year') s = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
    else s = new Date(now.getFullYear(), now.getMonth(), 1);
    var e = new Date(); e.setHours(23, 59, 59, 999);
    return { from: s.getTime(), to: e.getTime() };
  }

  function render(s) {
    var d = window.DC.doc(), cur = window.DC.prefs().currency;
    var r = rangeMs();
    var t = C.periodTotals(d.transactions, { fromMs: r.from, toMs: r.to, currency: cur });
    var bucket = range === 'week' ? 'day' : (range === 'month' ? 'day' : 'month');
    var series = C.groupBy(d.transactions, bucket, cur, r.from, r.to, window.DC.prefs().weekStart);
    var cats = C.categoryBreakdown(d.transactions, cur, r.from, r.to).slice(0, 8);

    var days = Math.max(1, Math.round((r.to - r.from) / 86400000));
    var avgDaily = t.expense > 0 ? Math.round(t.expense / days) : 0;
    var topCat = cats.length ? U.catById(cats[0].categoryId) : null;

    // previous comparable period for one honest comparison
    var plen = r.to - r.from;
    var prev = C.periodTotals(d.transactions, { fromMs: r.from - plen, toMs: r.from - 1, currency: cur });

    var html = '<div class="topbar"><h1 style="margin:0">Insights</h1></div>' +
      '<div class="seg" role="group" aria-label="Range">' +
      [['week', 'Week'], ['month', 'Month'], ['3m', '3 mo'], ['6m', '6 mo'], ['year', 'Year']].map(function (o) {
        return '<button data-r="' + o[0] + '" aria-selected="' + (range === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div>';

    if (!d.transactions.length) {
      html += '<div class="empty"><div class="big">' + I.svg('chart', 44) + '</div><h3>No data yet</h3>' +
        '<p>Insights appear once you record transactions. Nothing here is estimated or simulated.</p>' +
        '<button class="btn" id="i-add">Add a transaction</button></div>';
      s.innerHTML = html;
      bindRange(s);
      document.getElementById('i-add').addEventListener('click', function () { window.DCTxn.openForm('expense'); });
      return;
    }

    html += '<div class="flow3">' +
      '<div class="cell"><div class="l">Income</div><div class="n num in">' + U.fmt(t.income, cur) + '</div></div>' +
      '<div class="cell"><div class="l">Expenses</div><div class="n num out">' + U.fmt(t.expense, cur) + '</div></div>' +
      '<div class="cell"><div class="l">Net</div><div class="n num">' + (t.net < 0 ? '-' : '+') + ' ' + U.fmt(Math.abs(t.net), cur) + '</div></div></div>';

    html += '<div class="sect-head"><h2>Income vs expenses</h2></div><div class="card">' +
      (series.length ? '<canvas class="chart" id="i-bars" style="height:200px" role="img" aria-label="Income versus expenses chart"></canvas>' +
        '<div class="legend"><span><i style="background:#39d98a"></i>Income</span><span><i style="background:#9409b6"></i>Expenses</span></div>'
        : '<div class="empty"><h3>No activity in this range</h3><p>Try a wider date range.</p></div>') + '</div>';

    if (cats.length) {
      html += '<div class="sect-head"><h2>Spending by category</h2></div><div class="card"><div class="row">' +
        '<canvas id="i-donut" style="width:140px;height:140px" role="img" aria-label="Spending by category chart"></canvas>' +
        '<div class="grow">' + cats.slice(0, 5).map(function (c) {
          var cat = U.catById(c.categoryId);
          var col = I.COLORS[cat.color] || '#9ba79f';
          var pct = t.expense ? Math.round((c.total / t.expense) * 100) : 0;
          return '<div class="kv"><span class="k"><i style="display:inline-block;width:9px;height:9px;border-radius:3px;background:' +
            col + ';margin-right:7px"></i>' + U.esc(cat.name) + ' · ' + pct + '%</span>' +
            '<span class="v num">' + U.fmt(c.total, cur) + '</span></div>';
        }).join('') + '</div></div></div>';
    }

    // grounded observations
    var notes = [];
    if (t.expense > 0) notes.push({
      text: 'You spent ' + U.fmt(t.expense, cur) + ' in this period, averaging ' + U.fmt(avgDaily, cur) + ' per day.',
      src: 'Based on ' + d.transactions.filter(function (x) { return x.type === 'expense' && x.currency === cur && x.date >= r.from && x.date <= r.to; }).length + ' expense records.'
    });
    if (topCat && t.expense > 0) {
      var share = Math.round((cats[0].total / t.expense) * 100);
      notes.push({
        text: topCat.name + ' is your highest spending category at ' + share + '% of expenses.',
        src: U.fmt(cats[0].total, cur) + ' of ' + U.fmt(t.expense, cur) + ' total expenses.'
      });
    }
    if (prev.expense > 0 && t.expense > 0) {
      var diff = Math.round(((t.expense - prev.expense) / prev.expense) * 100);
      if (Math.abs(diff) >= 5) notes.push({
        text: 'Spending is ' + Math.abs(diff) + '% ' + (diff > 0 ? 'higher' : 'lower') + ' than the previous comparable period.',
        src: 'This period ' + U.fmt(t.expense, cur) + ' vs previous ' + U.fmt(prev.expense, cur) + '.'
      });
    }
    var recCount = d.recurring.filter(function (x) { return !x.paused; }).length;
    if (recCount) notes.push({
      text: 'You have ' + recCount + ' active recurring ' + (recCount === 1 ? 'entry' : 'entries') + ' generating records on schedule.',
      src: 'From your recurring templates.'
    });
    var overBudgets = d.budgets.filter(function (b) {
      return !b.archivedAt && b.currency === cur && C.budgetSpending(b, d.transactions).pct >= 100;
    });
    if (overBudgets.length) notes.push({
      text: overBudgets.length + ' ' + (overBudgets.length === 1 ? 'budget has' : 'budgets have') + ' reached or passed its limit: ' +
        overBudgets.map(function (b) { return b.name; }).join(', ') + '.',
      src: 'Budget utilization at or above 100%.'
    });
    if (!notes.length) notes.push({
      text: 'Not enough data in this range for observations yet.',
      src: 'Add more transactions to unlock insights.'
    });

    html += '<div class="sect-head"><h2>Observations</h2></div><div class="card">' +
      notes.map(function (n) {
        return '<div class="insight"><span class="dot"></span><div><p>' + U.esc(n.text) + '</p><div class="src">' + U.esc(n.src) + '</div></div></div>';
      }).join('') + '</div>' +
      '<p style="font-size:0.8rem">Every observation above is computed from your records. DigiCash does not predict or estimate your finances.</p>';

    s.innerHTML = html;
    bindRange(s);

    var bars = document.getElementById('i-bars');
    if (bars && series.length) {
      U.drawBars(bars, series.slice(-12).map(function (x) {
        var p = x.key.split('-');
        return { label: bucket === 'day' ? p[2] + '/' + p[1] : p[1] + '/' + String(p[0]).slice(2), income: x.income, expense: x.expense };
      }));
    }
    var donut = document.getElementById('i-donut');
    if (donut && cats.length) {
      U.drawDonut(donut, cats.slice(0, 6).map(function (c) {
        var cat = U.catById(c.categoryId);
        return { label: cat.name, value: c.total, color: I.COLORS[cat.color] || '#9ba79f' };
      }));
    }
  }

  function bindRange(s) {
    s.querySelectorAll('[data-r]').forEach(function (b) {
      b.addEventListener('click', function () { range = b.getAttribute('data-r'); U.render(); });
    });
  }

  U.register('insights', render);
})();
