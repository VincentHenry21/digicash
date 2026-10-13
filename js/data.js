/* DigiCash seed data: default categories (Myanmar everyday life first),
 * account types, and the category icon set (inline SVG paths). */
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) module.exports = factory();
  else root.DCData = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // icon: key into DCIcons (defined in icons.js); color: accent token name
  var EXPENSE_CATS = [
    { name: 'Food & Dining', icon: 'food', color: 'orange' },
    { name: 'Groceries', icon: 'cart', color: 'green' },
    { name: 'Transportation', icon: 'transport', color: 'blue' },
    { name: 'Phone Bills', icon: 'phone', color: 'purple' },
    { name: 'Shopping', icon: 'bag', color: 'pink' },
    { name: 'Housing', icon: 'home', color: 'teal' },
    { name: 'Bills & Utilities', icon: 'bolt', color: 'yellow' },
    { name: 'Health', icon: 'health', color: 'red' },
    { name: 'Education', icon: 'book', color: 'indigo' },
    { name: 'Entertainment', icon: 'play', color: 'violet' },
    { name: 'Family Expenses', icon: 'family', color: 'rose' },
    { name: 'Personal Care', icon: 'sparkle', color: 'cyan' },
    { name: 'Subscriptions', icon: 'repeat', color: 'slate' },
    { name: 'Gifts & Donations', icon: 'gift', color: 'amber' },
    { name: 'Travel', icon: 'plane', color: 'sky' },
    { name: 'Other', icon: 'dots', color: 'gray' }
  ];

  var INCOME_CATS = [
    { name: 'Salary', icon: 'briefcase', color: 'green' },
    { name: 'Business Income', icon: 'store', color: 'teal' },
    { name: 'Freelance', icon: 'laptop', color: 'blue' },
    { name: 'Allowance', icon: 'hand', color: 'amber' },
    { name: 'Interest', icon: 'percent', color: 'indigo' },
    { name: 'Other', icon: 'dots', color: 'gray' }
  ];

  var ACCOUNT_TYPES = [
    { id: 'cash', name: 'Cash', desc: 'Physical cash on hand' },
    { id: 'bank', name: 'Bank Account', desc: 'Manual bank account (no live connection)' },
    { id: 'savings', name: 'Savings Account', desc: 'Manual savings account' },
    { id: 'ewallet', name: 'E-Wallet', desc: 'Mobile wallet (manual records only)' }
  ];

  // Myanmar e-wallet presets (generic categories, NOT live integrations)
  var EWALLET_PRESETS = ['KBZPay', 'WavePay', 'CB Pay', 'AYA Pay', 'OK Dollar', 'OnePay', 'UAB Pay'];

  return {
    EXPENSE_CATS: EXPENSE_CATS,
    INCOME_CATS: INCOME_CATS,
    ACCOUNT_TYPES: ACCOUNT_TYPES,
    EWALLET_PRESETS: EWALLET_PRESETS
  };
});
