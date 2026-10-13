/* DigiCash persistent store. localStorage-backed JSON document with schema
 * versioning and migrations. Single write path; every mutation goes through
 * here so persistence failures surface instead of faking success. */
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) module.exports = factory();
  else root.DCStore = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var KEY = 'digicash.v1';
  var SCHEMA = 3;

  function uid(prefix) {
    return (prefix || 'id') + '_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
  }

  function defaultDoc() {
    return {
      schema: SCHEMA,
      prefs: {
        currency: 'MMK',          // default display currency
        digits: 'western',        // 'western' | 'myanmar'
        weekStart: 1,             // 0=Sun, 1=Mon
        theme: 'dark',            // 'dark' | 'light' | 'system'
        balanceHidden: false,
        pinHash: null,            // SHA-256 hex of PIN, null = lock off
        lockOnLaunch: false,
        onboardingDone: false
      },
      accounts: [],
      categories: [],
      transactions: [],
      budgets: [],
      goals: [],
      goalEvents: [],
      recurring: [],
      rates: []                   // {code, rateToMMK (per 1 unit, as string rational), source, updatedAt}
    };
  }

  function Store() {
    this.doc = null;
    this.listeners = [];
  }

  Store.prototype.load = function () {
    var raw = null;
    try { raw = localStorage.getItem(KEY); } catch (e) { raw = null; }
    if (!raw) { this.doc = defaultDoc(); return this.doc; }
    try {
      var doc = JSON.parse(raw);
      this.doc = migrate(doc);
      return this.doc;
    } catch (e) {
      // Corrupted data: keep a backup, start clean, and report honestly.
      try { localStorage.setItem(KEY + '.corrupt.' + Date.now(), raw); } catch (e2) {}
      this.doc = defaultDoc();
      this.doc._corruptRecovered = true;
      return this.doc;
    }
  };

  function migrate(doc) {
    if (!doc || typeof doc !== 'object') return defaultDoc();
    var d = defaultDoc();
    // shallow-merge known top-level keys; unknown keys are dropped
    ['prefs', 'accounts', 'categories', 'transactions', 'budgets', 'goals', 'goalEvents', 'recurring', 'rates']
      .forEach(function (k) { if (doc[k] !== undefined) d[k] = doc[k]; });
    d.prefs = Object.assign(defaultDoc().prefs, doc.prefs || {});
    d.schema = SCHEMA;
    return d;
  }

  Store.prototype.save = function () {
    var raw;
    try { raw = JSON.stringify(this.doc); }
    catch (e) { return { ok: false, error: 'Could not serialize data.' }; }
    try {
      localStorage.setItem(KEY, raw);
    } catch (e) {
      return { ok: false, error: 'Storage is full or unavailable. Your data was not saved.' };
    }
    this.emit();
    return { ok: true };
  };

  // Mutate inside fn(doc), then persist. Returns save result.
  Store.prototype.update = function (fn) {
    fn(this.doc);
    return this.save();
  };

  Store.prototype.on = function (fn) { this.listeners.push(fn); };
  Store.prototype.emit = function () {
    var doc = this.doc;
    this.listeners.forEach(function (fn) { try { fn(doc); } catch (e) {} });
  };

  Store.prototype.exportJSON = function () {
    return JSON.stringify({ app: 'DigiCash', exportedAt: new Date().toISOString(), doc: this.doc }, null, 2);
  };

  // Replace entire doc from a backup/import after validation. Returns {ok, error}.
  Store.prototype.replaceAll = function (parsed) {
    if (!parsed || parsed.app !== 'DigiCash' || !parsed.doc) return { ok: false, error: 'Not a DigiCash backup file.' };
    var doc = migrate(parsed.doc);
    if (!Array.isArray(doc.accounts) || !Array.isArray(doc.transactions)) {
      return { ok: false, error: 'Backup is missing required data.' };
    }
    this.doc = doc;
    return this.save();
  };

  Store.prototype.wipe = function () {
    this.doc = defaultDoc();
    this.doc.prefs.onboardingDone = true; // don't force onboarding again after wipe
    return this.save();
  };

  return { Store: Store, uid: uid, SCHEMA: SCHEMA, KEY: KEY };
});
