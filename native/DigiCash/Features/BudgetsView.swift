import SwiftUI

/// Budgets with real category spending, remaining amount, and utilization.
struct BudgetsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var showAdd = false
    @State private var editing: Budget? = nil

    var body: some View {
        NavigationStack {
            let budgets = store.budgets()
            let txs = store.transactions()
            if budgets.isEmpty {
                DCEmptyState(icon: "chart.pie", title: "No budgets yet",
                             message: "Set a spending limit per category and DigiCash will track it automatically.",
                             actionTitle: "Create a budget") { showAdd = true }
            } else {
                List {
                    ForEach(budgets, id: \.id) { b in
                        BudgetCard(budget: b, spending: Finance.budgetSpending(budget: b, transactions: txs))
                            .contentShape(Rectangle())
                            .onTapGesture { editing = b }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add budget")
            }
        }
        .sheet(isPresented: $showAdd) { DCSheet { BudgetFormView() } }
        .dcSheet(value: $editing) { b in DCSheet { BudgetFormView(editing: b) } }
    }
}

struct BudgetCard: View {
    @EnvironmentObject var prefs: Prefs
    var budget: Budget
    var spending: Finance.BudgetSpending

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.name).font(.headline)
                Spacer()
                if spending.percent >= 100 {
                    Text("Over")
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(DCColor.expense.opacity(0.15))
                        .foregroundStyle(DCColor.expense)
                        .clipShape(Capsule())
                } else if spending.percent >= 80 {
                    Text("Near limit")
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(DCColor.warning.opacity(0.15))
                        .foregroundStyle(DCColor.warning)
                        .clipShape(Capsule())
                }
            }
            Text("\(prefs.money(spending.spent, code: budget.currencyCode)) of \(prefs.money(budget.limitMinor, code: budget.currencyCode))")
                .font(.subheadline).foregroundStyle(.secondary)
                .monospacedDigit()
            DCProgressBar(percent: spending.percent)
            HStack {
                Text("Remaining \(prefs.money(spending.remaining, code: budget.currencyCode))")
                Spacer()
                Text("\(spending.percent)%").monospacedDigit()
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(DCSpacing.card)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
    }
}

struct BudgetFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    var editing: Budget? = nil

    @State private var name = ""
    @State private var selectedCategories: Set<UUID> = []
    @State private var limitText = ""
    @State private var currencyCode = "MMK"
    @State private var period = "monthly"
    @State private var startDate = Date()
    @State private var error: String? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(editing == nil ? "Create budget" : "Edit budget")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DCField(label: "Budget name") {
                    TextField("e.g. Food this month", text: $name)
                }

                DCField(label: "Limit (\(currencyCode))", error: error) {
                    TextField("0", text: $limitText).keyboardType(.decimalPad).monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("Empty selection covers all categories.")
                        .font(.caption).foregroundStyle(.tertiary)
                    let cats = store.categories(kind: "expense")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(cats, id: \.id) { c in
                            Button {
                                if selectedCategories.contains(c.id) {
                                    selectedCategories.remove(c.id)
                                } else {
                                    selectedCategories.insert(c.id)
                                }
                            } label: {
                                HStack {
                                    DCCategoryIcon(icon: c.icon, color: c.color, size: 30)
                                    Text(c.name).font(.subheadline).lineLimit(1)
                                    Spacer()
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: DCRadius.small)
                                        .fill(selectedCategories.contains(c.id)
                                              ? DCColor.brand.opacity(0.16) : Color.primary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Period").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    DCSegmented(items: [("weekly", "Weekly"), ("monthly", "Monthly"), ("yearly", "Yearly")],
                                selection: $period)
                }

                DCField(label: "Start date") {
                    DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.all, id: \.code) { c in Text(c.code).tag(c.code) }
                    }
                    .pickerStyle(.menu)
                }

                DCPrimaryButton(title: editing == nil ? "Create budget" : "Save changes") { save() }

                if editing != nil {
                    Button("Delete budget", role: .destructive) { showDeleteConfirm = true }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                        .confirmationDialog("Delete this budget?", isPresented: $showDeleteConfirm,
                                            titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            if let e = editing { store.context.delete(e); store.save() }
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .padding(20)
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        if let e = editing {
            name = e.name
            selectedCategories = Set(e.categoryIds)
            limitText = Money(minorUnits: e.limitMinor, currency: e.currency)
                .formatted(showCode: false).replacingOccurrences(of: ",", with: "")
            currencyCode = e.currencyCode
            period = e.period
            startDate = e.startDate
        } else {
            currencyCode = prefs.currencyCode
        }
    }

    private func save() {
        error = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Name is required."; return }
        let limit: Int64
        do {
            limit = try Money.parse(limitText, currency: Currency.of(currencyCode)).minorUnits
        } catch let parseError {
            error = (parseError as? LocalizedError)?.errorDescription ?? "Invalid limit."
            return
        }
        let cal = Calendar.current
        let end: Date
        switch period {
        case "weekly": end = cal.date(byAdding: .day, value: 7, to: startDate)!.addingTimeInterval(-1)
        case "yearly": end = cal.date(byAdding: .year, value: 1, to: startDate)!.addingTimeInterval(-1)
        default: end = cal.date(byAdding: .month, value: 1, to: startDate)!.addingTimeInterval(-1)
        }
        let start = cal.startOfDay(for: startDate)
        if let e = editing {
            e.name = n
            e.categoryIds = Array(selectedCategories)
            e.limitMinor = limit
            e.currencyCode = currencyCode
            e.period = period
            e.startDate = start
            e.endDate = end
        } else {
            store.context.insert(Budget(name: n, categoryIds: Array(selectedCategories),
                                       limitMinor: limit, currencyCode: currencyCode,
                                       period: period, startDate: start, endDate: end))
        }
        store.save()
        DCNotifications.checkBudgetAlerts(store: store)
        dismiss()
    }
}
