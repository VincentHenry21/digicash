/* DigiCash settings: preferences, security, exchange rates, data, about. */
(function () {
  'use strict';
  var U = window.DCUI, I = window.DCIcons, M = window.DCMoney;

  function render(s) {
    var d = window.DC.doc(), p = window.DC.prefs();
    var html = '<div class="topbar"><h1 style="margin:0">Settings</h1></div>';

    html += '<h2>Preferences</h2><div class="card">' +
      setRow('Primary currency', curName(p.currency), 'cur') +
      setRow('Number style', p.digits === 'myanmar' ? 'Myanmar digits (၀-၉)' : 'Western digits (0-9)', 'digits') +
      setRow('Week starts', p.weekStart === 1 ? 'Monday' : 'Sunday', 'week') +
      setRow('Appearance', cap(p.theme), 'theme') +
      setRow('Hide balances', p.balanceHidden ? 'On' : 'Off', 'hidebal') + '</div>';

    html += '<h2>Accounts & schedules</h2><div class="card">' +
      setRow('Accounts', d.accounts.filter(function (a) { return !a.archivedAt; }).length + ' active', 'accounts', true) +
      setRow('Recurring', d.recurring.length + ' templates', 'recurring', true) +
      setRow('Savings goals', d.goals.filter(function (g) { return g.status === 'active'; }).length + ' active', 'goals', true) +
      setRow('Categories', d.categories.length + ' total', 'cats', true) + '</div>';

    html += '<h2>Exchange rates</h2><div class="card">' +
      (d.rates.length ? d.rates.map(function (r) {
        return '<div class="kv"><span class="k">1 ' + r.code + ' = ' + r.perUnitMMK + ' MMK<br>' +
          '<span style="font-size:0.75rem;color:var(--text3)">Manual entry · ' + U.fmtDateTime(r.updatedAt) + '</span></span>' +
          '<button class="link" data-rate-del="' + r.code + '">Remove</button></div>';
      }).join('') : '<p>Only MMK is used right now. Add a manual rate to convert other currencies on the Home screen.</p>') +
      '<button class="btn btn-ghost" id="s-rate" style="width:100%;margin-top:8px">Add manual rate</button>' +
      '<p style="font-size:0.8rem">Manual rates are your own entries, never live market data. Source and time are shown with each rate.</p></div>';

    html += '<h2>Security</h2><div class="card">' +
      setRow('App lock (PIN)', p.pinHash ? 'On' : 'Off', 'pin') +
      setRow('Lock on launch', p.lockOnLaunch ? 'On' : 'Off', 'locklaunch') +
      '<p style="font-size:0.8rem">The PIN is hashed on this device and never stored in plain text. Biometric lock is not available in the web version; it requires the native iOS app.</p></div>';

    html += '<h2>Data</h2><div class="card">' +
      setRow('Export CSV', 'Download all transactions', 'export', true) +
      setRow('Import CSV', 'Preview and validate first', 'import', true) +
      setRow('Backup', 'Download full backup file', 'backup', true) +
      setRow('Restore backup', 'Replaces current data', 'restore', true) +
      setRow('Clear all data', 'Permanent', 'wipe', true) + '</div>';

    html += '<h2>About</h2><div class="card">' +
      '<div class="kv"><span class="k">DigiCash</span><span class="v">1.0.0 (web)</span></div>' +
      '<div class="kv"><span class="k">Data</span><span class="v">On this device only</span></div>' +
      '<div class="kv"><span class="k">Bank connections</span><span class="v">Not available</span></div>' +
      '<div class="kv"><span class="k">Cloud sync</span><span class="v">Not available</span></div>' +
      setRow('Privacy & terms', '', 'legal', true) + '</div>' +
      '<p style="font-size:0.8rem">This is the DigiCash web app. Native iOS features (Face ID, widgets, push notifications) require the native iOS build, which is not available in this environment.</p>';

    s.innerHTML = html;

    s.querySelectorAll('[data-set]').forEach(function (b) {
      b.addEventListener('click', function () { handle(b.getAttribute('data-set')); });
    });
    document.getElementById('s-rate').addEventListener('click', rateForm);
    s.querySelectorAll('[data-rate-del]').forEach(function (b) {
      b.addEventListener('click', function () {
        var code = b.getAttribute('data-rate-del');
        U.confirmDlg('Remove rate?', 'The manual ' + code + ' rate is deleted. Converted totals will show unconverted instead.', 'Remove').then(function (yes) {
          if (!yes) return;
          window.DC.store.update(function (dd) { dd.rates = dd.rates.filter(function (r) { return r.code !== code; }); });
          U.toast('Rate removed', 'ok'); U.render();
        });
      });
    });
  }

  function setRow(label, sub, id, chev) {
    return '<button class="setrow" data-set="' + id + '"><span class="grow">' + label +
      (sub ? '<div class="sub">' + U.esc(sub) + '</div>' : '') + '</span>' +
      (chev ? I.svg('chevR', 18) : '') + '</button>';
  }
  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
  function curName(c) { try { return c + ' · ' + M.currency(c).name; } catch (e) { return c; } }

  function handle(id) {
    var p = window.DC.prefs();
    if (id === 'cur') {
      var sh = U.openSheet('<h2>Primary currency</h2><div class="curpick">' +
        Object.keys(M.CURRENCIES).map(function (c) {
          var cur = M.CURRENCIES[c];
          return '<button data-c="' + c + '" aria-pressed="' + (p.currency === c) + '"><div class="code">' + c +
            '</div><div class="nm">' + cur.name + '</div></button>';
        }).join('') + '</div>');
      sh.querySelectorAll('[data-c]').forEach(function (b) {
        b.addEventListener('click', function () {
          window.DC.store.update(function (dd) { dd.prefs.currency = b.getAttribute('data-c'); });
          U.closeSheet(); U.toast('Currency updated', 'ok'); U.render();
        });
      });
    }
    else if (id === 'digits') {
      window.DC.store.update(function (dd) { dd.prefs.digits = dd.prefs.digits === 'myanmar' ? 'western' : 'myanmar'; });
      U.render();
    }
    else if (id === 'week') {
      window.DC.store.update(function (dd) { dd.prefs.weekStart = dd.prefs.weekStart === 1 ? 0 : 1; });
      U.render();
    }
    else if (id === 'theme') {
      var order = ['dark', 'light', 'system'];
      var next = order[(order.indexOf(p.theme) + 1) % 3];
      window.DC.store.update(function (dd) { dd.prefs.theme = next; });
      window.DC.applyTheme(); U.render();
    }
    else if (id === 'hidebal') {
      window.DC.store.update(function (dd) { dd.prefs.balanceHidden = !dd.prefs.balanceHidden; });
      U.render();
    }
    else if (id === 'accounts') U.go('accounts');
    else if (id === 'recurring') U.go('recurring');
    else if (id === 'goals') U.go('goals');
    else if (id === 'cats') categoryManager();
    else if (id === 'pin') pinSetup();
    else if (id === 'locklaunch') {
      if (!p.pinHash) { U.toast('Set a PIN first', 'bad'); return; }
      window.DC.store.update(function (dd) { dd.prefs.lockOnLaunch = !dd.prefs.lockOnLaunch; });
      U.render();
    }
    else if (id === 'export') exportCSV();
    else if (id === 'import') importCSV();
    else if (id === 'backup') backup();
    else if (id === 'restore') restore();
    else if (id === 'wipe') {
      U.confirmDlg('Clear all data?', 'Every account, transaction, budget, and goal on this device is permanently deleted.', 'Clear all').then(function (yes) {
        if (!yes) return;
        window.DC.store.wipe();
        U.toast('All data cleared', 'ok'); U.render();
      });
    }
    else if (id === 'legal') legal();
  }

  // ---------- categories ----------
  function categoryManager() {
    var d = window.DC.doc();
    function body() {
      var h = '<h2>Categories</h2>';
      ['expense', 'income'].forEach(function (t) {
        h += '<h3>' + cap(t) + '</h3>';
        d.categories.filter(function (c) { return c.type === t && !c.archivedAt; }).forEach(function (c) {
          h += '<div class="kv"><span class="k">' + U.catChip(c, 18) + ' ' + U.esc(c.name) + '</span>' +
            (c.system ? '<span class="v" style="font-size:0.75rem;color:var(--text3)">Default</span>'
              : '<button class="link" data-cdel="' + c.id + '">Delete</button>') + '</div>';
        });
      });
      h += '<button class="btn" id="c-add" style="width:100%;margin-top:12px">Add category</button>';
      return h;
    }
    var sh = U.openSheet(body());
    sh.querySelector('#c-add').addEventListener('click', function () {
      var s2 = U.openSheet('<h2>New category</h2>' +
        '<div class="field"><label>Name</label><input id="cn-name" maxlength="30"><div class="err"></div></div>' +
        '<div class="field"><label>Type</label><div class="seg" id="cn-type">' +
        '<button data-v="expense" aria-selected="true">Expense</button>' +
        '<button data-v="income" aria-selected="false">Income</button></div></div>' +
        '<button class="btn" id="cn-ok" style="width:100%">Add</button>');
      var type = 'expense';
      s2.querySelectorAll('#cn-type button').forEach(function (b) {
        b.addEventListener('click', function () {
          type = b.getAttribute('data-v');
          s2.querySelectorAll('#cn-type button').forEach(function (x) { x.setAttribute('aria-selected', 'false'); });
          b.setAttribute('aria-selected', 'true');
        });
      });
      s2.querySelector('#cn-ok').addEventListener('click', function () {
        var nm = s2.querySelector('#cn-name');
        if (!nm.value.trim()) { U.fieldError(nm, 'Name the category.'); return; }
        window.DC.store.update(function (dd) {
          dd.categories.push({
            id: window.DCStore.uid('cat'), name: nm.value.trim(), type: type,
            icon: 'dots', color: 'gray', system: false
          });
        });
        U.closeSheet(); U.toast('Category added', 'ok'); U.render();
      });
    });
    sh.querySelectorAll('[data-cdel]').forEach(function (b) {
      b.addEventListener('click', function () {
        var id = b.getAttribute('data-cdel');
        var used = window.DC.doc().transactions.some(function (t) { return t.categoryId === id; });
        if (used) { U.toast('Category is used by transactions and cannot be deleted.', 'bad'); return; }
        window.DC.store.update(function (dd) {
          dd.categories = dd.categories.filter(function (c) { return c.id !== id; });
        });
        U.closeSheet(); categoryManager(); U.render();
      });
    });
  }

  // ---------- PIN ----------
  function pinSetup() {
    var p = window.DC.prefs();
    if (p.pinHash) {
      U.confirmDlg('Remove PIN?', 'App lock will be turned off.', 'Remove').then(function (yes) {
        if (!yes) return;
        window.DC.store.update(function (dd) { dd.prefs.pinHash = null; dd.prefs.lockOnLaunch = false; });
        U.toast('PIN removed', 'ok'); U.render();
      });
      return;
    }
    var sh = U.openSheet('<h2>Set app PIN</h2>' +
      '<div class="field"><label>New PIN (4-8 digits)</label>' +
      '<input id="pin1" type="password" inputmode="numeric" maxlength="8" class="num"><div class="err"></div></div>' +
      '<div class="field"><label>Confirm PIN</label><input id="pin2" type="password" inputmode="numeric" maxlength="8" class="num"><div class="err"></div></div>' +
      '<button class="btn" id="pin-ok" style="width:100%">Set PIN</button>');
    sh.querySelector('#pin-ok').addEventListener('click', function () {
      var p1 = sh.querySelector('#pin1'), p2 = sh.querySelector('#pin2');
      if (!/^\d{4,8}$/.test(p1.value)) { U.fieldError(p1, 'Use 4-8 digits.'); return; }
      U.fieldError(p1);
      if (p1.value !== p2.value) { U.fieldError(p2, 'PINs do not match.'); return; }
      U.fieldError(p2);
      window.DC.sha256hex(p1.value).then(function (h) {
        window.DC.store.update(function (dd) { dd.prefs.pinHash = h; dd.prefs.lockOnLaunch = true; });
        U.closeSheet(); U.toast('PIN set. The app locks on launch.', 'ok'); U.render();
      });
    });
  }

  // ---------- exchange rates ----------
  function rateForm() {
    var codes = Object.keys(M.CURRENCIES).filter(function (c) { return c !== 'MMK'; });
    var sh = U.openSheet('<h2>Manual exchange rate</h2>' +
      '<p>Your own rate, stored with the entry time. It is never presented as live market data.</p>' +
      '<div class="field"><label>Currency</label><select id="rt-code">' +
      codes.map(function (c) { return '<option>' + c + '</option>'; }).join('') + '</select></div>' +
      '<div class="field"><label>1 unit = ? MMK</label>' +
      '<input id="rt-val" inputmode="decimal" class="num" placeholder="e.g. 2100"><div class="err"></div>' +
      '<div class="hint">Use whole numbers where possible. Stored exactly as entered.</div></div>' +
      '<button class="btn" id="rt-ok" style="width:100%">Save rate</button>');
    sh.querySelector('#rt-ok').addEventListener('click', function () {
      var inp = sh.querySelector('#rt-val');
      var v = inp.value.trim().replace(/,/g, '');
      if (!/^\d+(\.\d{1,4})?$/.test(v) || +v <= 0) { U.fieldError(inp, 'Enter a positive rate.'); return; }
      var code = sh.querySelector('#rt-code').value;
      // store as rational string to avoid float: keep the decimal string
      window.DC.store.update(function (dd) {
        dd.rates = dd.rates.filter(function (r) { return r.code !== code; });
        dd.rates.push({ code: code, perUnitMMK: +v, source: 'manual', updatedAt: Date.now() });
      });
      U.closeSheet(); U.toast('Manual rate saved', 'ok'); U.render();
    });
  }

  // ---------- CSV export ----------
  function csvEsc(v) {
    v = String(v == null ? '' : v);
    return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
  }
  function exportCSV() {
    var d = window.DC.doc();
    var rows = [['Transaction ID', 'Date', 'Type', 'Description', 'Category', 'Account', 'Amount', 'Currency', 'Notes', 'Tags']];
    var accts = {}, cats = {};
    d.accounts.forEach(function (a) { accts[a.id] = a.name; });
    d.categories.forEach(function (c) { cats[c.id] = c.name; });
    d.transactions.slice().sort(function (a, b) { return a.date - b.date; }).forEach(function (t) {
      rows.push([
        t.id, new Date(t.date).toISOString(), t.type, t.description || '',
        cats[t.categoryId] || '', accts[t.accountId] || '',
        M.toMajor(t.amountMinor, t.currency), t.currency,
        t.notes || '', (t.tags || []).join(';')
      ]);
    });
    var csv = rows.map(function (r) { return r.map(csvEsc).join(','); }).join('\n');
    download(csv, 'digicash-transactions.csv', 'text/csv');
    U.toast('Exported ' + (rows.length - 1) + ' transactions', 'ok');
  }

  function download(content, name, type) {
    var blob = new Blob([content], { type: type });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a); a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
  }

  // ---------- CSV import ----------
  function importCSV() {
    var sh = U.openSheet('<h2>Import CSV</h2>' +
      '<p>Upload a CSV with columns: Date, Type, Description, Category, Account, Amount, Currency. Rows are validated and previewed before anything is saved.</p>' +
      '<div class="field"><label>CSV file</label><input id="im-file" type="file" accept=".csv,text/csv"></div>' +
      '<div id="im-prev"></div>');
    sh.querySelector('#im-file').addEventListener('change', function (ev) {
      var file = ev.target.files[0];
      if (!file) return;
      var rd = new FileReader();
      rd.onload = function () { previewImport(String(rd.result || ''), sh); };
      rd.readAsText(file);
    });
  }

  function parseCSV(text) {
    var rows = [], row = [], cur = '', q = false;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (q) {
        if (c === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; }
        else cur += c;
      } else if (c === '"') q = true;
      else if (c === ',') { row.push(cur); cur = ''; }
      else if (c === '\n' || c === '\r') {
        if (c === '\r' && text[i + 1] === '\n') i++;
        row.push(cur); cur = '';
        if (row.length > 1 || row[0] !== '') rows.push(row);
        row = [];
      } else cur += c;
    }
    if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
    return rows;
  }

  function previewImport(text, sh) {
    var rows = parseCSV(text);
    var prev = sh.querySelector('#im-prev');
    if (rows.length < 2) { prev.innerHTML = '<p style="color:var(--expense)">No data rows found.</p>'; return; }
    var head = rows[0].map(function (h) { return h.trim().toLowerCase(); });
    function col() {
      for (var i = 0; i < arguments.length; i++) {
        var ix = head.indexOf(arguments[i]);
        if (ix !== -1) return ix;
      }
      return -1;
    }
    var ci = {
      date: col('date'), type: col('type'), desc: col('description', 'desc'),
      cat: col('category'), acct: col('account'), amt: col('amount'), cur: col('currency')
    };
    if (ci.date === -1 || ci.amt === -1) {
      prev.innerHTML = '<p style="color:var(--expense)">Missing required columns: Date and Amount.</p>';
      return;
    }
    var d = window.DC.doc();
    var valid = [], errors = [];
    var seen = {};
    d.transactions.forEach(function (t) { seen[t.date + '|' + t.amountMinor + '|' + t.currency] = true; });
    rows.slice(1, 501).forEach(function (r, i) {
      var line = i + 2;
      try {
        var dateMs = Date.parse(r[ci.date]);
        if (isNaN(dateMs)) throw new Error('bad date');
        var type = (r[ci.type] || 'expense').trim().toLowerCase();
        if (['expense', 'income'].indexOf(type) === -1) throw new Error('type must be expense or income');
        var currency = (r[ci.cur] || window.DC.prefs().currency).trim().toUpperCase();
        M.currency(currency);
        var minor = M.parse(r[ci.amt] || '', currency);
        var key = dateMs + '|' + minor + '|' + currency;
        var dup = !!seen[key];
        var acctName = ci.acct === -1 ? '' : (r[ci.acct] || '').trim();
        var acct = d.accounts.find(function (a) { return a.name.toLowerCase() === acctName.toLowerCase() && a.currency === currency && !a.archivedAt; });
        if (!acct) throw new Error('account "' + (acctName || '(blank)') + '" not found for ' + currency);
        var catName = ci.cat === -1 ? '' : (r[ci.cat] || '').trim();
        var cat = d.categories.find(function (c) { return c.name.toLowerCase() === catName.toLowerCase() && c.type === type; });
        valid.push({
          date: dateMs, type: type, amountMinor: minor, currency: currency,
          accountId: acct.id, categoryId: cat ? cat.id : null,
          description: ci.desc === -1 ? '' : (r[ci.desc] || '').trim(),
          dup: dup, line: line
        });
        seen[key] = true;
      } catch (err) { errors.push('Row ' + line + ': ' + err.message); }
    });
    var h = '<h3>Preview</h3><p>' + valid.length + ' valid, ' + errors.length + ' invalid, ' +
      valid.filter(function (v) { return v.dup; }).length + ' likely duplicates.</p>';
    if (valid.length) {
      h += '<div class="card" style="max-height:220px;overflow:auto">' +
        valid.slice(0, 20).map(function (v) {
          return '<div class="kv"><span class="k">' + U.fmtDate(v.date) + ' · ' + U.esc(v.description || v.type) +
            (v.dup ? ' <span class="badge info">possible duplicate</span>' : '') + '</span>' +
            '<span class="v num">' + U.fmt(v.amountMinor, v.currency) + '</span></div>';
        }).join('') + (valid.length > 20 ? '<p>...and ' + (valid.length - 20) + ' more</p>' : '') + '</div>';
    }
    if (errors.length) h += '<div class="card">' + errors.slice(0, 10).map(function (e) {
      return '<p style="color:var(--expense);font-size:0.85rem">' + U.esc(e) + '</p>';
    }).join('') + (errors.length > 10 ? '<p>...and ' + (errors.length - 10) + ' more</p>' : '') + '</div>';
    if (valid.length) h += '<button class="btn" id="im-ok" style="width:100%;margin-top:10px">Import ' + valid.length + ' transactions</button>';
    prev.innerHTML = h;
    var ok = prev.querySelector('#im-ok');
    if (ok) ok.addEventListener('click', function () {
      var r = window.DC.store.update(function (dd) {
        valid.forEach(function (v) {
          dd.transactions.push({
            id: window.DCStore.uid('txn'), type: v.type, amountMinor: v.amountMinor, currency: v.currency,
            categoryId: v.categoryId, accountId: v.accountId, destAccountId: null,
            description: v.description, merchant: '', notes: 'Imported', tags: [],
            date: v.date, createdAt: Date.now(), updatedAt: Date.now(), importSource: 'csv'
          });
        });
      });
      if (r.ok) { U.closeSheet(); U.toast('Imported ' + valid.length + ' transactions', 'ok'); U.render(); }
      else U.toast('Import failed: ' + r.error + ' Nothing was changed.', 'bad');
    });
  }

  // ---------- backup / restore ----------
  function backup() {
    download(window.DC.store.exportJSON(), 'digicash-backup-' + new Date().toISOString().slice(0, 10) + '.json', 'application/json');
    U.toast('Backup downloaded', 'ok');
  }
  function restore() {
    var sh = U.openSheet('<h2>Restore backup</h2>' +
      '<p>This <strong>replaces</strong> all current data with the backup file. The file is validated first; nothing is deleted until validation passes.</p>' +
      '<div class="field"><label>Backup file (.json)</label><input id="rs-file" type="file" accept=".json,application/json"></div>');
    sh.querySelector('#rs-file').addEventListener('change', function (ev) {
      var file = ev.target.files[0];
      if (!file) return;
      var rd = new FileReader();
      rd.onload = function () {
        var parsed;
        try { parsed = JSON.parse(String(rd.result)); }
        catch (e) { U.toast('File is not valid JSON.', 'bad'); return; }
        var r = window.DC.store.replaceAll(parsed);
        if (r.ok) {
          window.DC.seedIfNeeded(); window.DC.applyTheme();
          U.closeSheet(); U.toast('Backup restored', 'ok');
          U.go('home', {}, true);
        } else U.toast('Restore failed: ' + r.error + ' Current data untouched.', 'bad');
      };
      rd.readAsText(file);
    });
  }

  function legal() {
    U.openSheet('<h2>Privacy & terms</h2>' +
      '<p><strong>Data storage.</strong> All DigiCash data lives in this device\'s local storage. Nothing is uploaded to any server.</p>' +
      '<p><strong>No bank connections.</strong> Accounts are manual records you enter yourself. DigiCash does not connect to any bank or wallet.</p>' +
      '<p><strong>No analytics.</strong> No advertising or analytics SDKs are included. No financial data leaves the device.</p>' +
      '<p><strong>Deletion.</strong> Use Settings &gt; Clear all data to permanently delete everything, or delete the app / clear site data.</p>' +
      '<p><strong>Terms.</strong> DigiCash is provided as-is for personal finance tracking. It is not a bank, not financial advice, and converted totals that use your manual rates are estimates based on rates you entered.</p>' +
      '<p style="color:var(--text3);font-size:0.85rem">© 2026 DigiCash. All rights reserved.</p>');
  }

  U.register('settings', render);
})();
