/* DigiCash accounting engine. Single source of truth for every number the UI
 * shows. Integer minor-unit arithmetic only (via DCMoney).
 *
 * Accounting policy (documented, applied consistently):
 * - Expense reduces its account. Income increases its account.
 * - Transfer moves value source -> destination; never income or expense.
 * - Refund is a negative expense in the same category (reduces spending),
 *   never new income. Prevents double counting.
 * - Opening balance is an auditable initialization record, not income.
 * - Date ranges are inclusive of both ends, in the user's local day.
 * - Currencies are NEVER aggregated. Every total is per-currency; mixed
 *   views convert only through explicit user-entered rates, disclosed in UI.
 */
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = factory(require('./money.js'));
  } else root.DCCalc = factory(root.DCMoney);
})(typeof self !== 'undefined' ? self : this, function (Money) {
  'use strict';

  function inRange(dateMs, fromMs, toMs) {
    return dateMs >= fromMs && dateMs <= toMs;
  }

  // Signed effect of one transaction on one account, in the tx currency.
  function txEffect(tx, accountId) {
    switch (tx.type) {
      case 'expense': return tx.accountId === accountId ? -tx.amountMinor : 0;
      case 'income': return tx.accountId === accountId ? tx.amountMinor : 0;
      case 'refund': return tx.accountId === accountId ? tx.amountMinor : 0; // negative expense
      case 'transfer':
        if (tx.accountId === accountId) return -tx.amountMinor;
        if (tx.destAccountId === accountId) return tx.amountMinor;
        return 0;
      case 'opening':
      case 'adjustment': return tx.accountId === accountId ? tx.amountMinor : 0;
      default: return 0;
    }
  }

  function accountBalance(account, txs) {
    var bal = account.openingMinor || 0;
    for (var i = 0; i < txs.length; i++) {
      var tx = txs[i];
      if (tx.currency !== account.currency) continue; // never mix currencies
      bal = Money.add(bal, txEffect(tx, account.id));
    }
    return bal;
  }

  function allBalances(accounts, txs) {
    var out = {};
    accounts.forEach(function (a) {
      if (!a.archivedAt) out[a.id] = accountBalance(a, txs);
    });
    return out;
  }

  // Income/expense/net for a period + currency. Transfers and opening balances excluded.
  function periodTotals(txs, opts) {
    opts = opts || {};
    var from = opts.fromMs, to = opts.toMs, cur = opts.currency;
    var income = 0, expense = 0;
    for (var i = 0; i < txs.length; i++) {
      var tx = txs[i];
      if (cur && tx.currency !== cur) continue;
      if (from != null && !inRange(tx.date, from, to)) continue;
      if (tx.type === 'income') income = Money.add(income, tx.amountMinor);
      else if (tx.type === 'expense') expense = Money.add(expense, tx.amountMinor);
      else if (tx.type === 'refund') expense = Money.sub(expense, tx.amountMinor);
    }
    return { income: income, expense: expense, net: Money.sub(income, expense) };
  }

  // Budget spend: qualifying EXPENSES in period, in budget currency, matching categories.
  function budgetSpending(budget, txs) {
    var spent = 0;
    for (var i = 0; i < txs.length; i++) {
      var tx = txs[i];
      if (tx.currency !== budget.currency) continue;
      if (!inRange(tx.date, budget.startDate, budget.endDate)) continue;
      if (budget.categoryIds.length && budget.categoryIds.indexOf(tx.categoryId) === -1) continue;
      if (tx.type === 'expense') spent = Money.add(spent, tx.amountMinor);
      else if (tx.type === 'refund') spent = Money.sub(spent, tx.amountMinor);
    }
    if (spent < 0) spent = 0;
    var remaining = Money.sub(budget.limitMinor, spent);
    var pct = budget.limitMinor > 0 ? Math.min(100, Math.round((spent / budget.limitMinor) * 100)) : 0;
    return { spent: spent, remaining: remaining, pct: pct };
  }

  function goalProgress(goal, events) {
    var saved = 0;
    for (var i = 0; i < events.length; i++) {
      var e = events[i];
      if (e.goalId !== goal.id) continue;
      saved = e.type === 'in' ? Money.add(saved, e.amountMinor) : Money.sub(saved, e.amountMinor);
    }
    if (saved < 0) saved = 0;
    var remaining = Money.sub(goal.targetMinor, saved);
    if (remaining < 0) remaining = 0;
    var pct = goal.targetMinor > 0 ? Math.min(100, Math.round((saved / goal.targetMinor) * 100)) : 0;
    return { saved: saved, remaining: remaining, pct: pct };
  }

  // Group transactions by day/week/month bucket for charts. Returns [{key, label, income, expense}].
  function groupBy(txs, bucket, currency, fromMs, toMs, weekStart) {
    var buckets = {};
    var order = [];
    function keyFor(d) {
      var dt = new Date(d);
      if (bucket === 'day') return dt.getFullYear() + '-' + (dt.getMonth() + 1) + '-' + dt.getDate();
      if (bucket === 'week') {
        var ws = weekStart == null ? 1 : weekStart;
        var day = (dt.getDay() - ws + 7) % 7;
        var start = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate() - day);
        return start.getFullYear() + '-' + (start.getMonth() + 1) + '-' + start.getDate();
      }
      return dt.getFullYear() + '-' + (dt.getMonth() + 1);
    }
    for (var i = 0; i < txs.length; i++) {
      var tx = txs[i];
      if (currency && tx.currency !== currency) continue;
      if (fromMs != null && !inRange(tx.date, fromMs, toMs)) continue;
      if (tx.type !== 'income' && tx.type !== 'expense' && tx.type !== 'refund') continue;
      var k = keyFor(tx.date);
      if (!buckets[k]) { buckets[k] = { key: k, income: 0, expense: 0 }; order.push(k); }
      if (tx.type === 'income') buckets[k].income = Money.add(buckets[k].income, tx.amountMinor);
      else if (tx.type === 'expense') buckets[k].expense = Money.add(buckets[k].expense, tx.amountMinor);
      else buckets[k].expense = Money.sub(buckets[k].expense, tx.amountMinor);
    }
    order.sort();
    return order.map(function (k) { return buckets[k]; });
  }

  function categoryBreakdown(txs, currency, fromMs, toMs) {
    var map = {};
    for (var i = 0; i < txs.length; i++) {
      var tx = txs[i];
      if (tx.type !== 'expense') continue;
      if (currency && tx.currency !== currency) continue;
      if (fromMs != null && !inRange(tx.date, fromMs, toMs)) continue;
      var id = tx.categoryId || 'uncategorized';
      map[id] = map[id] ? Money.add(map[id], tx.amountMinor) : tx.amountMinor;
    }
    var arr = Object.keys(map).map(function (id) { return { categoryId: id, total: map[id] }; });
    arr.sort(function (a, b) { return b.total - a.total; });
    return arr;
  }

  // Recurring: compute next dates without ever duplicating generated entries.
  function nextOccurrence(tmpl, afterMs) {
    var d = new Date(Math.max(tmpl.nextDate, tmpl.startDate));
    if (afterMs && d.getTime() <= afterMs) {
      d = new Date(afterMs + 86400000);
    }
    return d.getTime();
  }

  function advanceDate(ms, freq, interval) {
    var d = new Date(ms);
    interval = interval || 1;
    if (freq === 'daily') d.setDate(d.getDate() + interval);
    else if (freq === 'weekly') d.setDate(d.getDate() + 7 * interval);
    else if (freq === 'monthly') d.setMonth(d.getMonth() + interval);
    else if (freq === 'yearly') d.setFullYear(d.getFullYear() + interval);
    return d.getTime();
  }

  return {
    txEffect: txEffect,
    accountBalance: accountBalance,
    allBalances: allBalances,
    periodTotals: periodTotals,
    budgetSpending: budgetSpending,
    goalProgress: goalProgress,
    groupBy: groupBy,
    categoryBreakdown: categoryBreakdown,
    advanceDate: advanceDate,
    nextOccurrence: nextOccurrence
  };
});
