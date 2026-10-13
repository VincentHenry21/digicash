# DigiCash — Platform & Limitations

## What this is

DigiCash is a **progressive web app (PWA)**: an installable, offline-capable web
application with an iOS-oriented interface. It is **not a compiled native iOS
app**. No Xcode/Swift toolchain exists in this build environment, so native
compilation was not possible.

## Honest capability map

| Capability | Status |
|---|---|
| Transaction tracking (expense, income, transfer, refund) | Real. Integer minor-unit math, persisted locally. |
| Accounts (cash, bank, savings, e-wallet — manual records) | Real. Balances derived from records. |
| Budgets with progress and threshold alerts | Real. In-app alerts only. |
| Savings goals with contribution history | Real. |
| Recurring transaction templates | Real. Generated locally on app open. |
| Insights and charts | Real. Computed from your records; no estimates presented as fact. |
| CSV export / import with validation | Real. |
| Full backup / restore | Real (JSON file). |
| MMK-first currency, manual exchange rates | Real. Manual rates are labeled with source + timestamp, never presented as live. |
| App lock | Real PIN lock (SHA-256 hashed, never stored in plain text). |
| Offline operation | Real. Service worker caches the app shell. |
| Bank connections / live balances | **Not available.** Accounts are manual records. |
| Cloud sync / accounts | **Not available.** Data stays on this device. |
| AI financial assistant | **Not available.** |
| Face ID / Touch ID | **Not available in the web build.** Requires the native iOS app. PIN lock is the fallback. |
| Home-screen widgets | **Not available in the web build.** Requires WidgetKit in the native iOS app. |
| Push notifications | **Not available in the web build.** Budget alerts appear in-app. |
| Liquid Glass | Web approximation via backdrop blur. True Liquid Glass materials require native iOS APIs. |

## Privacy

All data is stored in this device's local storage. Nothing is uploaded,
tracked, or shared. There are no analytics or advertising SDKs.

## Native iOS path

A native Swift/SwiftUI implementation would need: Xcode on macOS, an Apple
Developer account for signing, and the DigiCash brand assets (already
preserved in `assets/`). The data model in `js/` documents the schema a
SwiftData migration should follow.
