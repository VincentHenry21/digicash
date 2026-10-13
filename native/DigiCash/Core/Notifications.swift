import Foundation
import UserNotifications

/// Budget threshold alerts via real iOS notifications.
/// Only fires when a budget crosses a threshold it has not reported yet.
enum DCNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    /// Called on launch and after budget/transaction changes.
    static func checkBudgetAlerts(store: DataStore) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                let txs = store.transactions()
                for b in store.budgets() {
                    let sp = Finance.budgetSpending(budget: b, transactions: txs)
                    for t in b.thresholds where sp.percent >= t && !b.notified.contains(t) {
                        b.notified.append(t)
                        let content = UNMutableNotificationContent()
                        content.title = "Budget alert: \(b.name)"
                        content.body = sp.percent >= 100
                            ? "You reached \(sp.percent)% of this budget."
                            : "You spent \(sp.percent)% of this budget."
                        content.sound = .default
                        let req = UNNotificationRequest(
                            identifier: "budget-\(b.id)-\(t)",
                            content: content, trigger: nil)
                        UNUserNotificationCenter.current().add(req)
                    }
                }
                store.save()
            }
        }
    }
}
