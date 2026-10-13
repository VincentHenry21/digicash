# DigiCash (native iOS)

A complete, functional, native iOS finance-tracking app built with
SwiftUI, SwiftData, Swift Charts, LocalAuthentication, and Keychain.

MMK is the default currency. All money math uses integer minor units.
No bank connections, no cloud sync, no live rates: everything is
on-device and honest about it.

## Requirements

- macOS with Xcode 16.2 or later (iOS 17 SDK)
- iPhone or iOS Simulator running iOS 17+

## Build and run

1. Open `DigiCash.xcodeproj` in Xcode.
2. Select the `DigiCash` scheme and an iPhone simulator (or your device).
3. Press Cmd+R.

Unit tests: Cmd+U (runs `DigiCashTests`: money parsing/formatting and
accounting scenarios A-E).

CI: every push to `native/**` runs `.github/workflows/ios.yml`, which
builds for the iOS Simulator and runs the unit tests on a GitHub-hosted
macOS runner. This is the verified build, not a claim.

## Project layout

```
DigiCash/
  DigiCashApp.swift          App entry point
  Design/
    Theme.swift              Colors, type, glass helpers, Reduce Motion support
    Components.swift         Buttons, fields, segmented control, progress, rows
  Core/
    Money.swift              Integer money engine + currency registry + formatter
    Models.swift             SwiftData models
    DataStore.swift          Container, seeding, recurring engine, fetch helpers
    Finance.swift            Accounting engine (balances, totals, budgets, goals)
    Notifications.swift      Budget threshold alerts
  Features/
    RootView.swift           Bubble tab bar + center Add
    OnboardingView.swift     5-step welcome (currency, opening balance, privacy)
    HomeView.swift            Dashboard, charts, quick actions, More section
    TransactionsView.swift   Search, filters, sort, detail, edit, delete
    TransactionFormView.swift Add/edit with validation
    AccountsView.swift       Add/edit/archive accounts with live balances
    BudgetsView.swift        Budgets with real spending + threshold alerts
    GoalsView.swift          Savings goals with contribution history
    InsightsView.swift       Swift Charts analytics from real records
    RecurringView.swift      Recurring templates, pause/resume
    SettingsView.swift       Currency, digits, PIN, rates, CSV, backup, about
  Resources/
    Assets.xcassets          App icon + transparent DigiCash logo
DigiCashTests/
  MoneyTests.swift           Parsing, formatting, arithmetic
  FinanceTests.swift         Scenarios A-E, goal progress, recurring advance
```

## Signing and TestFlight (what you need to do)

Building is verified by CI. Getting onto TestFlight needs your Apple
Developer Program membership ($99/year), which only you can provide.

One-time setup on a Mac:

1. Enroll at https://developer.apple.com/programs/ (Apple ID + $99/year).
2. In Xcode, sign in with that Apple ID (Settings > Accounts).
3. Open this project, select the DigiCash target, and set your Team.
   Change the bundle identifier if needed (default: `com.digicash.app`).
4. Product > Archive, then Distribute App > TestFlight.

Or use the prepared CI lane: add the secrets listed at the top of
`.github/workflows/testflight.yml` (API key, distribution certificate,
provisioning profile) and run the "TestFlight Upload" workflow manually.
Apple's own `apple-actions` handle the upload.

To install on your iPhone directly from Xcode: connect the phone,
select it as the run destination, press Cmd+R. A free Apple ID works
for device installs; TestFlight needs the paid membership.

## Completed

- Onboarding (currency, opening balance, privacy disclosure)
- Home dashboard (balance card, period flow, charts, quick actions, recents)
- Accounts: cash / bank / savings / e-wallet, add, edit, archive
- Transactions: add, edit, delete, search, type/category/account filters, sorting
- Transfers between accounts (excluded from income/expense)
- Refunds (reduce expense, never income), opening records (never income)
- Budgets with real category spending, remaining, utilization, threshold alerts
- Savings goals with contribution/withdrawal history
- Insights: income vs expenses chart, category donut, savings rate, observations
- Recurring templates with auto-posting and pause/resume
- Currency settings, Western/Myanmar digits, themes, balance hiding
- PIN lock (SHA-256 in Keychain) + Face ID / Touch ID unlock
- Manual exchange rates with source and timestamp labels
- CSV export, CSV import with validation, full JSON backup
- Unit tests (money + accounting scenarios A-E)

## Incomplete / needs you

- App Store / TestFlight publication: needs your Apple Developer Program
  membership, signing certificate, and provisioning profile (see above).
- Widgets and Live Activities: not implemented.
- Push notifications: only local budget alerts are implemented.
- iCloud sync: intentionally not implemented (on-device by design).

## Honest limitations (also shown in Settings > About)

- No bank connections. All data is entered by hand.
- No cloud sync. Data lives on this device only.
- No live exchange rates. Rates are manual entries you type in.
- Charts describe your data; they are not financial advice.
