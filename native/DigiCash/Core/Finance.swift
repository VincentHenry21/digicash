import Foundation

/// DigiCash accounting engine. Single source of truth for every number.
/// Integer minor-unit arithmetic only.
///
/// Policy:
/// - Expense reduces its account. Income increases it.
/// - Transfer moves value source -> destination; never income or expense.
/// - Refund is a negative expense in the same category, never new income.
/// - Opening balance is an auditable initialization record, not income.
/// - Date ranges are inclusive of both ends.
/// - Currencies are NEVER aggregated. Totals are per-currency; conversion
///   happens only through explicit user-entered rates.
enum Finance {

    /// Signed effect of one transaction on one account (in tx currency).
    static func effect(of tx: TransactionRecord, on accountId: UUID) -> Int64 {
        switch tx.type {
        case .expense:
            return tx.accountId == accountId ? -tx.amountMinor : 0
        case .income, .refund, .opening, .adjustment:
            return tx.accountId == accountId ? tx.amountMinor : 0
        case .transfer:
            if tx.accountId == accountId { return -tx.amountMinor }
            if tx.destAccountId == accountId { return tx.amountMinor }
            return 0
        }
    }

    static func balance(account: Account, transactions: [TransactionRecord]) -> Int64 {
        var bal = account.openingMinor
        for tx in transactions where tx.currencyCode == account.currencyCode {
            let (v, over) = bal.addingReportingOverflow(effect(of: tx, on: account.id))
            precondition(!over, "balance overflow")
            bal = v
        }
        return bal
    }

    struct PeriodTotals {
        var income: Int64
        var expense: Int64
        var net: Int64
    }

    /// Income/expense/net for a period + currency. Transfers and openings excluded.
    static func periodTotals(transactions: [TransactionRecord], from: Date? = nil,
                             to: Date? = nil, currencyCode: String) -> PeriodTotals {
        var income: Int64 = 0
        var expense: Int64 = 0
        for tx in transactions {
            guard tx.currencyCode == currencyCode else { continue }
            if let from, tx.date < from { continue }
            if let to, tx.date > to { continue }
            switch tx.type {
            case .income:
                income = income &+ tx.amountMinor
            case .expense:
                expense = expense &+ tx.amountMinor
            case .refund:
                expense = expense &- tx.amountMinor
            default:
                break
            }
        }
        return PeriodTotals(income: income, expense: expense, net: income &- expense)
    }

    struct BudgetSpending {
        var spent: Int64
        var remaining: Int64
        var percent: Int
    }

    static func budgetSpending(budget: Budget, transactions: [TransactionRecord]) -> BudgetSpending {
        var spent: Int64 = 0
        for tx in transactions {
            guard tx.currencyCode == budget.currencyCode else { continue }
            guard tx.date >= budget.startDate && tx.date <= budget.endDate else { continue }
            if !budget.categoryIds.isEmpty, let cid = tx.categoryId,
               !budget.categoryIds.contains(cid) { continue }
            if !budget.categoryIds.isEmpty, tx.categoryId == nil { continue }
            switch tx.type {
            case .expense: spent = spent &+ tx.amountMinor
            case .refund: spent = spent &- tx.amountMinor
            default: break
            }
        }
        if spent < 0 { spent = 0 }
        let remaining = budget.limitMinor &- spent
        let pct: Int = budget.limitMinor > 0
            ? min(100, Int((Double(spent) / Double(budget.limitMinor) * 100).rounded()))
            : 0
        return BudgetSpending(spent: spent, remaining: remaining, percent: pct)
    }

    struct GoalProgress {
        var saved: Int64
        var remaining: Int64
        var percent: Int
    }

    static func goalProgress(goal: Goal, events: [GoalEvent]) -> GoalProgress {
        var saved: Int64 = 0
        for e in events where e.goalId == goal.id {
            saved = e.direction == "in" ? saved &+ e.amountMinor : saved &- e.amountMinor
        }
        if saved < 0 { saved = 0 }
        let remaining = max(0, goal.targetMinor &- saved)
        let pct: Int = goal.targetMinor > 0
            ? min(100, Int((Double(saved) / Double(goal.targetMinor) * 100).rounded()))
            : 0
        return GoalProgress(saved: saved, remaining: remaining, percent: pct)
    }

    struct Bucket {
        var key: String
        var income: Int64
        var expense: Int64
    }

    /// Group transactions into day or month buckets for charts.
    static func groupByDay(transactions: [TransactionRecord], currencyCode: String,
                           from: Date, to: Date) -> [Bucket] {
        var map: [String: Bucket] = [:]
        let cal = Calendar.current
        for tx in transactions {
            guard tx.currencyCode == currencyCode else { continue }
            guard tx.date >= from && tx.date <= to else { continue }
            guard tx.type == .income || tx.type == .expense || tx.type == .refund else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: tx.date)
            let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            var b = map[key] ?? Bucket(key: key, income: 0, expense: 0)
            switch tx.type {
            case .income: b.income = b.income &+ tx.amountMinor
            case .expense: b.expense = b.expense &+ tx.amountMinor
            case .refund: b.expense = b.expense &- tx.amountMinor
            default: break
            }
            map[key] = b
        }
        return map.keys.sorted().compactMap { map[$0] }
    }

    struct CategoryTotal {
        var categoryId: UUID?
        var total: Int64
    }

    static func categoryBreakdown(transactions: [TransactionRecord], currencyCode: String,
                                  from: Date, to: Date) -> [CategoryTotal] {
        var map: [UUID?: Int64] = [:]
        for tx in transactions {
            guard tx.type == .expense, tx.currencyCode == currencyCode else { continue }
            guard tx.date >= from && tx.date <= to else { continue }
            map[tx.categoryId, default: 0] = (map[tx.categoryId] ?? 0) &+ tx.amountMinor
        }
        return map.map { CategoryTotal(categoryId: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    /// Advance a recurring template's next date.
    static func advance(_ date: Date, frequency: String) -> Date {
        var comp = DateComponents()
        switch frequency {
        case "daily": comp.day = 1
        case "weekly": comp.day = 7
        case "monthly": comp.month = 1
        case "yearly": comp.year = 1
        default: comp.month = 1
        }
        return Calendar.current.date(byAdding: comp, to: date) ?? date
    }
}
