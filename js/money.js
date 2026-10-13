/* DigiCash money engine.
 * - All amounts are integer minor units (Number, safe-integer guarded). No floats.
 * - MMK-first: MMK defaults to 0 decimals in practice; ISO precision is centralized.
 * - Centralized locale-aware formatter. English style default: "1,000 MMK".
 * - Myanmar digits optional via prefs (Western digits default).
 * Works in browser and Node (for tests). */
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) module.exports = factory();
  else root.DCMoney = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ISO 4217 precision registry. MMK is stored with 0 decimals: the kyat
  // circulates without subunits in practice, so 1 minor unit = 1 MMK.
  var CURRENCIES = {
    MMK: { code: 'MMK', name: 'Myanmar Kyat', country: 'Myanmar', isoDecimals: 0, uiDecimals: 0, symbol: 'K' },
    USD: { code: 'USD', name: 'US Dollar', country: 'United States', isoDecimals: 2, uiDecimals: 2, symbol: '$' },
    EUR: { code: 'EUR', name: 'Euro', country: 'Eurozone', isoDecimals: 2, uiDecimals: 2, symbol: '€' },
    GBP: { code: 'GBP', name: 'British Pound', country: 'United Kingdom', isoDecimals: 2, uiDecimals: 2, symbol: '£' },
    SGD: { code: 'SGD', name: 'Singapore Dollar', country: 'Singapore', isoDecimals: 2, uiDecimals: 2, symbol: 'S$' },
    THB: { code: 'THB', name: 'Thai Baht', country: 'Thailand', isoDecimals: 2, uiDecimals: 2, symbol: '฿' },
    JPY: { code: 'JPY', name: 'Japanese Yen', country: 'Japan', isoDecimals: 0, uiDecimals: 0, symbol: '¥' },
    CNY: { code: 'CNY', name: 'Chinese Yuan', country: 'China', isoDecimals: 2, uiDecimals: 2, symbol: '¥' },
    KRW: { code: 'KRW', name: 'South Korean Won', country: 'South Korea', isoDecimals: 0, uiDecimals: 0, symbol: '₩' },
    INR: { code: 'INR', name: 'Indian Rupee', country: 'India', isoDecimals: 2, uiDecimals: 2, symbol: '₹' },
    MYR: { code: 'MYR', name: 'Malaysian Ringgit', country: 'Malaysia', isoDecimals: 2, uiDecimals: 2, symbol: 'RM' },
    VND: { code: 'VND', name: 'Vietnamese Dong', country: 'Vietnam', isoDecimals: 0, uiDecimals: 0, symbol: '₫' },
    AUD: { code: 'AUD', name: 'Australian Dollar', country: 'Australia', isoDecimals: 2, uiDecimals: 2, symbol: 'A$' },
    CAD: { code: 'CAD', name: 'Canadian Dollar', country: 'Canada', isoDecimals: 2, uiDecimals: 2, symbol: 'C$' }
  };

  var MYANMAR_DIGITS = ['၀', '၁', '၂', '၃', '၄', '၅', '၆', '၇', '၈', '၉'];

  function currency(code) {
    var c = CURRENCIES[String(code || '').toUpperCase()];
    if (!c) throw new Error('Unsupported currency: ' + code);
    return c;
  }

  function assertSafe(n) {
    if (!Number.isSafeInteger(n)) throw new Error('Amount out of safe integer range');
    return n;
  }

  // Parse a user-entered decimal string into minor units for the currency.
  // Rejects invalid formats and precision beyond the currency's ISO decimals.
  function parse(str, code) {
    var c = currency(code);
    var s = String(str == null ? '' : str).trim().replace(/,/g, '');
    if (!/^\d+(\.\d+)?$/.test(s)) throw new Error('Invalid amount');
    var parts = s.split('.');
    var frac = parts[1] || '';
    if (frac.length > c.isoDecimals) throw new Error('Too many decimal places for ' + c.code);
    while (frac.length < c.isoDecimals) frac += '0';
    var minor = Number(parts[0]) * Math.pow(10, c.isoDecimals) + (frac ? Number(frac) : 0);
    if (!Number.isSafeInteger(minor)) throw new Error('Amount too large');
    if (minor <= 0) throw new Error('Amount must be greater than zero');
    return minor;
  }

  function toMajor(minor, code) {
    var c = currency(code);
    return assertSafe(minor) / Math.pow(10, c.isoDecimals);
  }

  function groupDigits(intStr, useMyanmarDigits) {
    var out = '';
    var count = 0;
    for (var i = intStr.length - 1; i >= 0; i--) {
      out = intStr[i] + out;
      count++;
      if (count % 3 === 0 && i !== 0) out = ',' + out;
    }
    if (useMyanmarDigits) {
      out = out.replace(/[0-9]/g, function (d) { return MYANMAR_DIGITS[+d]; });
    }
    return out;
  }

  // Centralized formatter. opts: { decimals, digits: 'western'|'myanmar', code: true|false }
  // Default English style: "1,250,000 MMK". Unambiguous code suffix everywhere.
  function format(minor, code, opts) {
    var c = currency(code);
    opts = opts || {};
    var decimals = opts.decimals != null ? opts.decimals : c.uiDecimals;
    if (decimals > c.isoDecimals) decimals = c.isoDecimals;
    var m = assertSafe(minor);
    var neg = m < 0;
    var abs = Math.abs(m);
    var div = Math.pow(10, c.isoDecimals);
    var intPart = Math.floor(abs / div);
    var fracPart = abs % div;
    var useMy = opts.digits === 'myanmar';
    var intStr = groupDigits(String(intPart), useMy);
    var fracStr = '';
    if (decimals > 0) {
      var scale = Math.pow(10, c.isoDecimals - decimals);
      // round-half-up on the dropped digits for DISPLAY only; stored value untouched
      var shown = Math.floor(fracPart / scale + 0.5);
      if (shown >= Math.pow(10, decimals)) { intStr = groupDigits(String(intPart + 1), useMy); shown = 0; }
      fracStr = '.' + String(shown).padStart(decimals, '0');
      if (useMy) fracStr = fracStr.replace(/[0-9]/g, function (d) { return MYANMAR_DIGITS[+d]; });
    }
    var num = (neg ? '-' : '') + intStr + fracStr;
    if (opts.code === false) return num;
    return num + ' ' + c.code;
  }

  // Compact display for tight spaces, e.g. "1.25M MMK". Exact value on tap.
  function formatCompact(minor, code, opts) {
    var c = currency(code);
    var m = assertSafe(minor);
    var abs = Math.abs(m) / Math.pow(10, c.isoDecimals);
    var useMy = opts && opts.digits === 'myanmar';
    var val, suffix;
    if (abs >= 1e9) { val = abs / 1e9; suffix = 'B'; }
    else if (abs >= 1e6) { val = abs / 1e6; suffix = 'M'; }
    else if (abs >= 1e3) { val = abs / 1e3; suffix = 'K'; }
    else return format(m, code, opts);
    var rounded = Math.round(val * 100) / 100;
    var s = String(rounded);
    if (useMy) s = s.replace(/[0-9]/g, function (d) { return MYANMAR_DIGITS[+d]; });
    return (m < 0 ? '-' : '') + s + suffix + ' ' + c.code;
  }

  function add(a, b) { return assertSafe(assertSafe(a) + assertSafe(b)); }
  function sub(a, b) { return assertSafe(assertSafe(a) - assertSafe(b)); }

  // Multiply minor units by an integer or a rational (num/den) without floats.
  function mulDiv(minor, num, den) {
    assertSafe(minor);
    if (!Number.isSafeInteger(num) || !Number.isSafeInteger(den) || den === 0) throw new Error('Bad ratio');
    return assertSafe(Math.round((minor * num) / den));
  }

  return {
    CURRENCIES: CURRENCIES,
    currency: currency,
    parse: parse,
    toMajor: toMajor,
    format: format,
    formatCompact: formatCompact,
    add: add,
    sub: sub,
    mulDiv: mulDiv,
    assertSafe: assertSafe
  };
});
