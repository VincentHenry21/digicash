import SwiftUI

/// Accounts list + add/edit/archive with real balances.
struct AccountsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var showAdd = false
    @State private var showArchived = false
    @State private var editing: Account? = nil

    var body: some View {
        NavigationStack {
            let accounts = store.accounts(activeOnly: !showArchived)
            let txs = store.transactions()
            List {
                ForEach(accounts, id: \.id) { a in
                    HStack(spacing: 12) {
                        DCCategoryIcon(icon: icon(for: a.type), color: "purple")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name).fontWeight(.semibold)
                            Text("\(a.type.displayName) · \(a.currencyCode)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(prefs.balanceHidden ? "•••" : prefs.money(Finance.balance(account: a, transactions: txs), code: a.currencyCode))
                            .font(DCFonts.money()).monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = a }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add account")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(showArchived ? "Hide archived" : "Show archived") {
                    showArchived.toggle()
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(DCColor.brandSoft)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showAdd) { DCSheet { AccountFormView() } }
            .dcSheet(value: $editing) { a in DCSheet { AccountFormView(editing: a) } }
        }
    }

    private func icon(for t: AccountType) -> String {
        switch t {
        case .cash: return "banknote"
        case .bank: return "building.columns"
        case .savings: return "piggy.bank"
        case .ewallet: return "wallet"
        }
    }
}

struct AccountFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    var editing: Account? = nil

    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var currencyCode = "MMK"
    @State private var openingText = ""
    @State private var nameError: String? = nil
    @State private var openingError: String? = nil
    @State private var showArchiveConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(editing == nil ? "Add account" : "Edit account")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DCField(label: "Account name", error: nameError) {
                    TextField("e.g. Cash wallet", text: $name)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Type").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    DCSegmented(items: AccountType.allCases.map { ($0, $0.displayName) }, selection: $type)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.all, id: \.code) { c in
                            Text("\(c.code) · \(c.name)").tag(c.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if editing == nil {
                    DCField(label: "Opening balance (\(currencyCode))", error: openingError,
                            hint: "Optional. Recorded as an opening record, never as income.") {
                        TextField("0", text: $openingText).keyboardType(.decimalPad).monospacedDigit()
                    }
                }

                DCPrimaryButton(title: editing == nil ? "Add account" : "Save changes") { save() }

                if let e = editing {
                    Button(e.isArchived ? "Unarchive" : "Archive") {
                        if e.isArchived {
                            e.archivedAt = nil
                            store.save()
                            dismiss()
                        } else {
                            showArchiveConfirm = true
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                    .confirmationDialog("Archive this account?",
                                        isPresented: $showArchiveConfirm, titleVisibility: .visible) {
                        Button("Archive", role: .destructive) {
                            e.archivedAt = Date()
                            store.save()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("It will be hidden and excluded from totals. History is kept.")
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
            type = e.type
            currencyCode = e.currencyCode
        } else {
            currencyCode = prefs.currencyCode
        }
    }

    private func save() {
        nameError = nil
        openingError = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { nameError = "Name is required."; return }

        let ctx = store.context
        if let e = editing {
            e.name = n
            e.typeRaw = type.rawValue
            e.currencyCode = currencyCode
            e.updatedAt = Date()
            store.save()
            dismiss()
            return
        }

        var opening: Int64 = 0
        if !openingText.isEmpty {
            do {
                opening = try Money.parse(openingText, currency: Currency.of(currencyCode)).minorUnits
            } catch {
                openingError = (error as? LocalizedError)?.errorDescription ?? "Invalid amount."
                return
            }
        }
        let acc = Account(name: n, type: type, currencyCode: currencyCode, openingMinor: opening)
        ctx.insert(acc)
        if opening > 0 {
            ctx.insert(TransactionRecord(type: .opening, amountMinor: opening,
                                        currencyCode: currencyCode, accountId: acc.id,
                                        title: "Opening balance"))
        }
        store.save()
        dismiss()
    }
}
