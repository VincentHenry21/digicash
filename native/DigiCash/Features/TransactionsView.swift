import SwiftUI

enum TxnFilterType: String, CaseIterable {
    case all = "All", expense = "Expense", income = "Income", transfer = "Transfer", refund = "Refund"
}

enum TxnSort: String, CaseIterable {
    case newest = "Newest", oldest = "Oldest", highest = "Highest", lowest = "Lowest"
}

struct TransactionsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var query = ""
    @State private var filterType: TxnFilterType = .all
    @State private var filterCategory: UUID? = nil
    @State private var filterAccount: UUID? = nil
    @State private var sort: TxnSort = .newest
    @State private var showFilters = false
    @State private var showAdd = false
    @State private var selected: TransactionRecord? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if hasActiveFilters {
                    Button("Clear filters") { clearFilters() }
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(DCColor.brandSoft)
                        .padding(.vertical, 6)
                }
                list
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(isPresented: $showFilters) { DCSheet { filterSheet } }
            .sheet(isPresented: $showAdd) { DCSheet { TransactionFormView() } }
            .dcSheet(value: $selected) { tx in DCSheet { TransactionDetailView(tx: tx) } }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search transactions", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, DCSpacing.screen)
        .padding(.vertical, 8)
    }

    private var hasActiveFilters: Bool {
        filterType != .all || filterCategory != nil || filterAccount != nil
    }

    private func clearFilters() {
        filterType = .all; filterCategory = nil; filterAccount = nil; query = ""
    }

    private var filtered: [TransactionRecord] {
        var list = store.transactions()
        if filterType != .all {
            list = list.filter { $0.typeRaw == filterType.rawValue.lowercased() }
        }
        if let c = filterCategory { list = list.filter { $0.categoryId == c } }
        if let a = filterAccount { list = list.filter { $0.accountId == a || $0.destAccountId == a } }
        if !query.isEmpty {
            let q = query.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) || $0.merchant.lowercased().contains(q) ||
                $0.notes.lowercased().contains(q)
            }
        }
        switch sort {
        case .newest: list.sort { $0.date > $1.date }
        case .oldest: list.sort { $0.date < $1.date }
        case .highest: list.sort { $0.amountMinor > $1.amountMinor }
        case .lowest: list.sort { $0.amountMinor < $1.amountMinor }
        }
        return list
    }

    private var list: some View {
        let items = filtered
        return Group {
            if store.transactions().isEmpty {
                DCEmptyState(icon: "tray", title: "No transactions yet",
                             message: "Add your first transaction to start tracking.",
                             actionTitle: "Add transaction") { showAdd = true }
            } else if items.isEmpty {
                DCEmptyState(icon: "magnifyingglass", title: "No matching transactions",
                             message: "Try clearing or changing your filters.")
            } else {
                List {
                    ForEach(items, id: \.id) { tx in
                        row(for: tx)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(for tx: TransactionRecord) -> some View {
        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        let accs = Dictionary(uniqueKeysWithValues: store.accounts(activeOnly: false).map { ($0.id, $0.name) })
        return DCTransactionRow(tx: tx, category: tx.categoryId.flatMap { cats[$0] },
                                accountName: accs[tx.accountId] ?? "", prefs: prefs) {
            selected = tx
        }
    }

    private var filterSheet: some View {
        let cats = store.categories()
        let accs = store.accounts(activeOnly: false)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Filters").font(.title2).fontWeight(.bold)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    DCSegmented(items: TxnFilterType.allCases.map { ($0, $0.rawValue) },
                                selection: $filterType)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    DCSegmented(items: TxnSort.allCases.map { ($0, $0.rawValue) },
                                selection: $sort)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Category", selection: $filterCategory) {
                        Text("All").tag(UUID?.none)
                        ForEach(cats, id: \.id) { c in Text(c.name).tag(UUID?.some(c.id)) }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Account", selection: $filterAccount) {
                        Text("All").tag(UUID?.none)
                        ForEach(accs, id: \.id) { a in Text(a.name).tag(UUID?.some(a.id)) }
                    }
                    .pickerStyle(.menu)
                }
                DCPrimaryButton(title: "Apply") { showFilters = false }
            }
            .padding(20)
        }
    }
}

/// Transaction detail with Edit and Delete.
struct TransactionDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    var tx: TransactionRecord
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        let accs = Dictionary(uniqueKeysWithValues: store.accounts(activeOnly: false).map { ($0.id, $0) })
        let cat = tx.categoryId.flatMap { cats[$0] }
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if tx.type == .transfer {
                        DCCategoryIcon(icon: "arrow.left.arrow.right", color: "purple", size: 52)
                    } else {
                        DCCategoryIcon(icon: cat?.icon ?? "ellipsis", color: cat?.color ?? "gray", size: 52)
                    }
                    VStack(alignment: .leading) {
                        Text(tx.title.isEmpty ? (cat?.name ?? "Transaction") : tx.title)
                            .font(.title3).fontWeight(.bold)
                        Text(tx.typeRaw.capitalized)
                            .font(.caption).fontWeight(.bold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(badgeColor.opacity(0.15))
                            .foregroundStyle(badgeColor)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(amountText)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
                VStack(spacing: 0) {
                    kv("Date", tx.date.formatted(date: .abbreviated, time: .shortened))
                    kv("Account", accs[tx.accountId]?.name ?? "—")
                    if tx.type == .transfer, let d = tx.destAccountId {
                        kv("Destination", accs[d]?.name ?? "—")
                    }
                    if tx.type != .transfer { kv("Category", cat?.name ?? "Uncategorized") }
                    if !tx.merchant.isEmpty { kv("Merchant", tx.merchant) }
                    if !tx.notes.isEmpty { kv("Notes", tx.notes) }
                    if tx.recurringId != nil { kv("Source", "Recurring schedule") }
                }
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
                HStack(spacing: 10) {
                    DCGhostButton(title: "Edit") { showEdit = true }
                    Button("Delete") { showDeleteConfirm = true }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .foregroundStyle(.white)
                        .background(DCColor.expense)
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showEdit) { DCSheet { TransactionFormView(editing: tx) } }
        .confirmationDialog("Delete this transaction?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.context.delete(tx)
                store.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Balances and budgets will be recalculated. This cannot be undone.")
        }
    }

    private var badgeColor: Color {
        switch tx.type {
        case .income, .refund: return DCColor.income
        case .transfer: return DCColor.brandSoft
        default: return DCColor.expense
        }
    }

    private var amountText: String {
        let m = tx.money.formatted(useMyanmarDigits: prefs.useMyanmarDigits)
        switch tx.type {
        case .income, .refund: return "+ \(m)"
        case .expense: return "- \(m)"
        default: return m
        }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
