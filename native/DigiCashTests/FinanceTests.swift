import XCTest
@testable import DigiCash

/// Accounting scenarios A-E. Balances use Finance.balance over SwiftData
/// models held in memory; no container required.
final class FinanceTests: XCTestCase {

    private func account(_ name: String = "Cash", code: String = "MMK", opening: Int64 = 0) -> Account {
        Account(name: name, type: .cash, currencyCode: code, openingMinor: opening)
    }

    // Scenario A: basic income and expense change the balance.
    func testScenarioA_BasicBalance() {
        let acc = account(opening: 100_000)
        let txs = [
            TransactionRecord(type: .income, amountMinor: 500_000, currencyCode: "MMK", accountId: acc.id, title: "Salary"),
            TransactionRecord(type: .expense, amountMinor: 15_000, currencyCode: "MMK", accountId: acc.id, title: "Lunch")
        ]
        XCTAssertEqual(Finance.balance(account: acc, transactions: txs), 585_000)
    }

    // Scenario B: transfers move money, never counted as income/expense.
    func testScenarioB_TransferExcluded() {
        let cash = account("Cash", opening: 200_000)
        let bank = account("Bank", opening: 0)
        let txs = [
            TransactionRecord(type: .transfer, amountMinor: 50_000, currencyCode: "MMK",
                              accountId: cash.id, destAccountId: bank.id, title: "Move")
        ]
        XCTAssertEqual(Finance.balance(account: cash, transactions: txs), 150_000)
        XCTAssertEqual(Finance.balance(account: bank, transactions: txs), 50_000)
        let totals = Finance.periodTotals(transactions: txs, currencyCode: "MMK")
        XCTAssertEqual(totals.income, 0)
        XCTAssertEqual(totals.expense, 0)
    }

    // Scenario C: refunds reduce expense, never become income.
    func testScenarioC_RefundHandling() {
        let acc = account()
        let txs = [
            TransactionRecord(type: .expense, amountMinor: 30_000, currencyCode: "MMK", accountId: acc.id),
            TransactionRecord(type: .refund, amountMinor: 10_000, currencyCode: "MMK", accountId: acc.id)
        ]
        let totals = Finance.periodTotals(transactions: txs, currencyCode: "MMK")
        XCTAssertEqual(totals.expense, 20_000)
        XCTAssertEqual(totals.income, 0)
        XCTAssertEqual(Finance.balance(account: acc, transactions: txs), -20_000)
    }

    // Scenario D: currencies are never aggregated together.
    func testScenarioD_CurrencyIsolation() {
        let mmkAcc = account("Cash", code: "MMK")
        let usdAcc = account("USD wallet", code: "USD")
        let txs = [
            TransactionRecord(type: .income, amountMinor: 100_000, currencyCode: "MMK", accountId: mmkAcc.id),
            TransactionRecord(type: .income, amountMinor: 500_00, currencyCode: "USD", accountId: usdAcc.id)
        ]
        XCTAssertEqual(Finance.balance(account: mmkAcc, transactions: txs), 100_000)
        XCTAssertEqual(Finance.balance(account: usdAcc, transactions: txs), 500_00)
        let mmk = Finance.periodTotals(transactions: txs, currencyCode: "MMK")
        let usd = Finance.periodTotals(transactions: txs, currencyCode: "USD")
        XCTAssertEqual(mmk.income, 100_000)
        XCTAssertEqual(usd.income, 500_00)
    }

    // Scenario E: budget spending counts expenses minus refunds in range.
    func testScenarioE_BudgetSpending() {
        let acc = account()
        let cat = Category(name: "Food", kind: "expense", icon: "fork.knife", color: "orange")
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let end = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        let b = Budget(name: "Food", categoryIds: [cat.id], limitMinor: 50_000,
                       currencyCode: "MMK", period: "monthly", startDate: start, endDate: end)
        let txs = [
            TransactionRecord(type: .expense, amountMinor: 15_000, currencyCode: "MMK",
                              categoryId: cat.id, accountId: acc.id, date: now),
            TransactionRecord(type: .refund, amountMinor: 2_000, currencyCode: "MMK",
                              categoryId: cat.id, accountId: acc.id, date: now),
            // outside the budget window: must not count
            TransactionRecord(type: .expense, amountMinor: 99_000, currencyCode: "MMK",
                              categoryId: cat.id, accountId: acc.id,
                              date: Calendar.current.date(byAdding: .day, value: -40, to: now)!)
        ]
        let sp = Finance.budgetSpending(budget: b, transactions: txs)
        XCTAssertEqual(sp.spent, 13_000)
        XCTAssertEqual(sp.remaining, 37_000)
        XCTAssertEqual(sp.percent, 26)
    }

    func testGoalProgress() {
        let g = Goal(name: "Phone", targetMinor: 1_000_000, currencyCode: "MMK")
        let events = [
            GoalEvent(goalId: g.id, direction: "in", amountMinor: 300_000),
            GoalEvent(goalId: g.id, direction: "out", amountMinor: 50_000)
        ]
        let p = Finance.goalProgress(goal: g, events: events)
        XCTAssertEqual(p.saved, 250_000)
        XCTAssertEqual(p.remaining, 750_000)
        XCTAssertEqual(p.percent, 25)
    }

    func testRecurringAdvance() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let next = Finance.advance(d, frequency: "monthly")
        let months = Calendar.current.dateComponents([.month], from: d, to: next).month
        XCTAssertEqual(months, 1)
    }

    func testOpeningIsNotIncome() {
        let acc = account(opening: 0)
        let txs = [
            TransactionRecord(type: .opening, amountMinor: 80_000, currencyCode: "MMK", accountId: acc.id, title: "Opening balance")
        ]
        let totals = Finance.periodTotals(transactions: txs, currencyCode: "MMK")
        XCTAssertEqual(totals.income, 0)
        XCTAssertEqual(Finance.balance(account: acc, transactions: txs), 80_000)
    }
}
