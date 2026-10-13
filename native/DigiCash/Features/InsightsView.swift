import SwiftUI
import Charts

enum InsightRange: String, CaseIterable {
    case week = "Week", month = "Month", quarter = "3 months", year = "Year"
}

/// Real analytics from persisted transactions. Never invents data.
struct InsightsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var range: InsightRange = .month

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    DCSegmented(items: InsightRange.allCases.map { ($0, $0.rawValue) }, selection: $range)
                    let txs = store.transactions()
                    let (from, to) = dates
                    let code = prefs.currencyCode
                    let totals = Finance.periodTotals(transactions: txs, from: from, to: to, currencyCode: code)
                    let breakdown = Finance.categoryBreakdown(transactions: txs, currencyCode: code, from: from, to: to)
                    let buckets = Finance.groupByDay(transactions: txs, currencyCode: code, from: from, to: to)

                    flowCard(totals: totals)
                    incomeExpenseChart(buckets: buckets)
                    categoryChart(breakdown: breakdown)
                    observations(totals: totals, breakdown: breakdown, code: code)
                }
                .padding(.horizontal, DCSpacing.screen)
                .padding(.top, 8)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var dates: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .week:
            let weekday = cal.component(.weekday, from: now)
            let offset = prefs.weekStartsMonday ? (weekday + 5) % 7 : weekday - 1
            let start = cal.startOfDay(cal.date(byAdding: .day, value: -offset, to: now)!)
            return (start, cal.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1))
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (start, cal.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1))
        case .quarter:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (cal.date(byAdding: .month, value: -2, to: thisMonth)!, now)
        case .year:
            let start = cal.date(from: DateComponents(year: cal.component(.year, from: now)))!
            return (start, cal.date(byAdding: .year, value: 1, to: start)!.addingTimeInterval(-1))
        }
    }

    private func flowCard(totals: Finance.PeriodTotals) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Money flow · \(prefs.currencyCode)").font(.headline)
            HStack(spacing: 10) {
                statCell("Income", totals.income, DCColor.income)
                statCell("Expenses", totals.expense, DCColor.expense)
            }
            HStack(spacing: 10) {
                statCell("Net", totals.net, totals.net >= 0 ? DCColor.income : DCColor.expense)
                statCell("Savings rate", nil, .primary, sub: savingsRate(totals: totals))
            }
        }
        .padding(DCSpacing.card)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
    }

    private func savingsRate(totals: Finance.PeriodTotals) -> String {
        guard totals.income > 0 else { return "—" }
        let r = Double(totals.net) / Double(totals.income) * 100
        return "\(Int(r.rounded()))%"
    }

    private func statCell(_ label: String, _ minor: Int64?, _ color: Color, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            if let minor {
                Text(prefs.money(minor)).font(.headline).monospacedDigit().foregroundStyle(color)
            } else if let sub {
                Text(sub).font(.headline).monospacedDigit().foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func incomeExpenseChart(buckets: [Finance.Bucket]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Income vs expenses").font(.headline)
            if buckets.isEmpty {
                emptyChart
            } else {
                Chart(buckets, id: \.key) {
                    BarMark(x: .value("Day", String($0.key.suffix(5))),
                            y: .value("Income", Double($0.income)))
                        .foregroundStyle(DCColor.income.gradient)
                    BarMark(x: .value("Day", String($0.key.suffix(5))),
                            y: .value("Expenses", Double($0.expense)))
                        .foregroundStyle(DCColor.expense.gradient)
                }
                .frame(height: 190)
                .chartYAxis(.hidden)
            }
        }
        .padding(DCSpacing.card)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
    }

    private func categoryChart(breakdown: [Finance.CategoryTotal]) -> some View {
        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        let top = Array(breakdown.prefix(6))
        let total = breakdown.reduce(0) { $0 &+ $1.total }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Where it goes").font(.headline)
            if top.isEmpty {
                emptyChart
            } else {
                VStack(spacing: 10) {
                    Chart(top, id: \.categoryId) { b in
                        let c = b.categoryId.flatMap { cats[$0] }
                        SectorMark(angle: .value("Amount", Double(b.total)),
                                   innerRadius: .ratio(0.6),
                                   angularInset: 2)
                            .foregroundStyle(DCColor.category(c?.color ?? "gray"))
                    }
                    .frame(height: 180)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2),
                              alignment: .leading, spacing: 6) {
                        ForEach(top, id: \.categoryId) { b in
                            let c = b.categoryId.flatMap { cats[$0] }
                            let name = c?.name ?? "Uncategorized"
                            let pct = total > 0 ? Int((Double(b.total) / Double(total) * 100).rounded()) : 0
                            HStack {
                                Circle().fill(DCColor.category(c?.color ?? "gray")).frame(width: 8, height: 8)
                                Text("\(name) · \(pct)%").font(.caption).lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(DCSpacing.card)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
    }

    private var emptyChart: some View {
        Text("No data for this period. Add transactions to see real analytics.")
            .font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 28)
    }

    private func observations(totals: Finance.PeriodTotals, breakdown: [Finance.CategoryTotal],
                              code: String) -> some View {
        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        var items: [String] = []
        if totals.expense > 0, let top = breakdown.first {
            let name = top.categoryId.flatMap { cats[$0]?.name } ?? "Uncategorized"
            let pct = Int((Double(top.total) / Double(totals.expense) * 100).rounded())
            items.append("Top category: \(name), \(prefs.money(top.total, code: code)) (\(pct)% of spending).")
        }
        if totals.income > 0 {
            let r = Int((Double(totals.net) / Double(totals.income) * 100).rounded())
            items.append("You kept \(r)% of your income (\(prefs.money(totals.net, code: code))).")
        } else if totals.expense > 0 {
            items.append("No income recorded for this period, only expenses.")
        }
        if totals.net < 0 {
            items.append("Spending exceeded income by \(prefs.money(-totals.net, code: code)).")
        }
        return Group {
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Observations").font(.headline)
                    ForEach(items, id: \.self) { t in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(DCColor.brandSoft).font(.caption)
                            Text(t).font(.subheadline)
                        }
                    }
                }
                .padding(DCSpacing.card)
                .background(DCColor.brand.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
            }
        }
    }
}
