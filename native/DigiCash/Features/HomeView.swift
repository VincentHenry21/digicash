import SwiftUI
import Charts

enum HomePeriod: String, CaseIterable {
    case week = "Week", month = "Month", lastMonth = "Last mo."
}

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Binding var tab: DCTab
    @State private var period: HomePeriod = .month
    @State private var accountFilter: UUID? = nil
    @State private var showSettings = false
    @State private var showAdd = false
    @State private var addType: TransactionType = .expense
    @State private var moreDest: MoreDestination? = nil

    enum MoreDestination: String, Identifiable {
        case accounts, goals, recurring
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    accountPicker
                    balanceCard
                    periodSection
                    spendingChart
                    quickActions
                    recentSection
                    budgetsPreview
                    goalsPreview
                    moreSection
                }
                .padding(.horizontal, DCSpacing.screen)
                .padding(.top, 8)
            }
            .navigationTitle("DIGI:CASH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { DCSheet { SettingsView() } }
            .sheet(isPresented: $showAdd) { DCSheet { TransactionFormView(initialType: addType) } }
            .sheet(item: $moreDest) { dest in
                switch dest {
                case .accounts: DCSheet { AccountsView() }
                case .goals: DCSheet { GoalsView() }
                case .recurring: DCSheet { RecurringView() }
                }
            }
        }
    }

    private var moreSection: some View {
        VStack(spacing: 0) {
            moreRow("Accounts", "wallet", store.accounts().count > 0
                    ? "\(store.accounts().count) accounts" : nil, .accounts)
            Divider()
            moreRow("Savings goals", "target", store.goals().count > 0
                    ? "\(store.goals().count) active" : nil, .goals)
            Divider()
            moreRow("Recurring", "repeat", nil, .recurring)
        }
        .padding(.horizontal, 4)
    }

    private func moreRow(_ title: String, _ icon: String, _ sub: String?, _ dest: MoreDestination) -> some View {
        Button { moreDest = dest } label: {
            HStack(spacing: 12) {
                DCCategoryIcon(icon: icon, color: "purple", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    if let sub { Text(sub).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private var accounts: [Account] { store.accounts() }
    private var txs: [TransactionRecord] { store.transactions() }

    private var accountPicker: some View {
        Picker("Account", selection: $accountFilter) {
            Text("All accounts").tag(UUID?.none)
            ForEach(accounts, id: \.id) { a in
                Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var relevantAccounts: [Account] {
        if let f = accountFilter { return accounts.filter { $0.id == f } }
        return accounts
    }

    private var totalBalance: (minor: Int64, code: String, converted: Bool, unconverted: [(String, Int64, String)]) {
        let code = prefs.currencyCode
        var total: Int64 = 0
        var converted = false
        var unconverted: [(String, Int64, String)] = []
        let rates = Dictionary(uniqueKeysWithValues: store.rates().map { ($0.code, $0.perUnitMMK) })
        for a in relevantAccounts {
            let b = Finance.balance(account: a, transactions: txs)
            if a.currencyCode == code {
                total = total &+ b
            } else if code == "MMK", let r = rates[a.currencyCode], r > 0 {
                total = total &+ Int64((Double(b) * r).rounded())
                converted = true
            } else {
                unconverted.append((a.name, b, a.currencyCode))
            }
        }
        return (total, code, converted, unconverted)
    }

    private var balanceCard: some View {
        let t = totalBalance
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button {
                    prefs.balanceHidden.toggle()
                } label: {
                    Image(systemName: prefs.balanceHidden ? "eye.slash" : "eye")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(prefs.balanceHidden ? "Show balance" : "Hide balance")
            }
            Text(prefs.balanceHidden ? "••••••" : prefs.money(t.minor, code: t.code))
                .font(DCFonts.balance())
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(periodLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            if t.converted && !prefs.balanceHidden {
                Text("Includes conversion at your manual exchange rates.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            ForEach(t.unconverted, id: \.0) { name, bal, code in
                Text("+\(prefs.money(bal, code: code)) in \(name) (no rate set)")
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0x7A/255, green: 0x08/255, blue: 0xA0/255),
                                    DCColor.brand, DCColor.brandDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: DCColor.brand.opacity(0.35), radius: 24)
    }

    private var range: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .week:
            let weekday = cal.component(.weekday, from: now)
            let offset = prefs.weekStartsMonday ? (weekday + 5) % 7 : weekday - 1
            let start = cal.startOfDay(cal.date(byAdding: .day, value: -offset, to: now)!)
            let end = cal.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
            return (start, end)
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end = cal.date(byAdding: DateComponents(month: 1), to: start)!.addingTimeInterval(-1)
            return (start, end)
        case .lastMonth:
            let thisStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: thisStart)!
            return (start, thisStart.addingTimeInterval(-1))
        }
    }

    private var periodLabel: String {
        let (f, t) = range
        return "\(f.formatted(date: .abbreviated, time: .omitted)) – \(t.formatted(date: .abbreviated, time: .omitted))"
    }

    private var periodTotals: Finance.PeriodTotals {
        let (f, t) = range
        let filtered = txs.filter { tx in
            guard let af = accountFilter else { return true }
            return tx.accountId == af || tx.destAccountId == af
        }
        return Finance.periodTotals(transactions: filtered, from: f, to: t,
                                    currencyCode: prefs.currencyCode)
    }

    private var periodSection: some View {
        VStack(spacing: 12) {
            DCSegmented(items: HomePeriod.allCases.map { ($0, $0.rawValue) }, selection: $period)
            HStack(spacing: 10) {
                flowCell("Income", periodTotals.income, DCColor.income)
                flowCell("Expenses", periodTotals.expense, DCColor.expense)
                flowCell("Net", periodTotals.net, .primary)
            }
        }
    }

    private func flowCell(_ label: String, _ minor: Int64, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(prefs.balanceHidden ? "•••" : prefs.money(minor))
                .font(.headline).monospacedDigit().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
    }

    private var spendingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending").font(.headline)
            let (f, t) = range
            let buckets = Finance.groupByDay(transactions: txs, currencyCode: prefs.currencyCode,
                                             from: f, to: t).suffix(14)
            if buckets.isEmpty {
                Text("No data for this period. Add a transaction to see your chart.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                Chart(buckets, id: \.key) { b in
                    BarMark(x: .value("Day", String(b.key.suffix(2))),
                            y: .value("Expenses", Double(b.expense)))
                        .foregroundStyle(DCColor.brand.gradient)
                    BarMark(x: .value("Day", String(b.key.suffix(2))),
                            y: .value("Income", Double(b.income)))
                        .foregroundStyle(DCColor.income.gradient)
                }
                .frame(height: 170)
                .chartYAxis(.hidden)
                .accessibilityLabel("Daily income and expenses chart")
            }
        }
        .padding(DCSpacing.card)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickButton("Expense", "minus", .expense) { addType = .expense; showAdd = true }
            quickButton("Income", "plus", .income) { addType = .income; showAdd = true }
            quickButton("Transfer", "arrow.left.arrow.right", .transfer) { addType = .transfer; showAdd = true }
            quickButton("Activity", "list.bullet", .primary) { tab = .transactions }
        }
    }

    private func quickButton(_ label: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint)
                Text(label).font(.caption2).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            let recent = Array(txs.prefix(5))
            if recent.isEmpty {
                DCEmptyState(icon: "tray", title: "No transactions yet",
                             body: "Your recent activity will appear here.",
                             actionTitle: "Add your first transaction") {
                    addType = .expense; showAdd = true
                }
            } else {
                ForEach(recent, id: \.id) { tx in
                    row(for: tx)
                    Divider()
                }
            }
        }
    }

    private var budgetsPreview: some View {
        let budgets = Array(store.budgets().prefix(3))
        return Group {
            if !budgets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Budgets").font(.headline)
                    ForEach(budgets, id: \.id) { b in
                        let sp = Finance.budgetSpending(budget: b, transactions: txs)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(b.name).fontWeight(.semibold)
                                Spacer()
                                Text("\(sp.percent)%").font(.subheadline).monospacedDigit()
                            }
                            Text("\(prefs.money(sp.spent, code: b.currencyCode)) of \(prefs.money(b.limitMinor, code: b.currencyCode))")
                                .font(.caption).foregroundStyle(.secondary)
                            DCProgressBar(percent: sp.percent)
                        }
                        .padding(DCSpacing.card)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
                    }
                }
            }
        }
    }

    private var goalsPreview: some View {
        let goals = Array(store.goals().prefix(3))
        let events = store.allGoalEvents()
        return Group {
            if !goals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Savings goals").font(.headline)
                    ForEach(goals, id: \.id) { g in
                        let p = Finance.goalProgress(goal: g, events: events)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(g.name).fontWeight(.semibold)
                                Spacer()
                                Text("\(p.percent)%").font(.subheadline).monospacedDigit()
                            }
                            Text("\(prefs.money(p.saved, code: g.currencyCode)) of \(prefs.money(g.targetMinor, code: g.currencyCode))")
                                .font(.caption).foregroundStyle(.secondary)
                            DCProgressBar(percent: p.percent)
                        }
                        .padding(DCSpacing.card)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
                    }
                }
            }
        }
    }

    private func row(for tx: TransactionRecord) -> some View {
        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        let accs = Dictionary(uniqueKeysWithValues: store.accounts(activeOnly: false).map { ($0.id, $0.name) })
        return DCTransactionRow(tx: tx, category: tx.categoryId.flatMap { cats[$0] },
                                accountName: accs[tx.accountId] ?? "",
                                prefs: prefs) {}
    }
}
