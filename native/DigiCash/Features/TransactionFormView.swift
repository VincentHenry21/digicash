import SwiftUI

/// Add / edit transaction form. Validates, persists, and prevents duplicates.
struct TransactionFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    var editing: TransactionRecord? = nil
    var initialType: TransactionType = .expense

    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var accountId: UUID? = nil
    @State private var destAccountId: UUID? = nil
    @State private var categoryId: UUID? = nil
    @State private var date = Date()
    @State private var title = ""
    @State private var merchant = ""
    @State private var notes = ""
    @State private var amountError: String? = nil
    @State private var formError: String? = nil
    @State private var saving = false

    private var accounts: [Account] { store.accounts() }

    private var currency: Currency {
        accounts.first { $0.id == accountId }?.currency ?? prefs.currency
    }

    private var categories: [Category] {
        store.categories(kind: type == .income ? "income" : "expense")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(editing == nil ? "Add \(type.rawValue.capitalized)" : "Edit \(type.rawValue.capitalized)")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DCSegmented(items: [(.expense, "Expense"), (.income, "Income"),
                                    (.transfer, "Transfer"), (.refund, "Refund")],
                            selection: $type)
                    .onChange(of: type) { _, _ in
                        categoryId = categories.first?.id
                        if type == .transfer, accountId == destAccountId {
                            destAccountId = accounts.first { $0.id != accountId }?.id
                        }
                    }

                DCField(label: "Amount (\(currency.code))", error: amountError,
                        hint: currency.code == "MMK" ? "Whole kyat, no decimals." : nil) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                if type == .transfer {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                            Picker("From", selection: $accountId) {
                                ForEach(accounts, id: \.id) { a in
                                    Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                            Picker("To", selection: $destAccountId) {
                                ForEach(accounts, id: \.id) { a in
                                    Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Transfers move money between your accounts. Never counted as income or expenses. Cross-currency transfers are not supported.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                        Picker("Account", selection: $accountId) {
                            ForEach(accounts, id: \.id) { a in
                                Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if type != .transfer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(categories, id: \.id) { c in
                                Button {
                                    categoryId = c.id
                                } label: {
                                    VStack(spacing: 6) {
                                        DCCategoryIcon(icon: c.icon, color: c.color, size: 38)
                                        Text(c.name).font(.caption2).fontWeight(.medium)
                                            .lineLimit(2).multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: DCRadius.small)
                                            .fill(categoryId == c.id ? DCColor.brand.opacity(0.16) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DCRadius.small)
                                            .stroke(categoryId == c.id ? DCColor.brand : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                DCField(label: "Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                DCField(label: "Description") {
                    TextField("e.g. Lunch at Feel", text: $title)
                }

                DCField(label: "Merchant / payee (optional)") {
                    TextField("", text: $merchant)
                }

                DCField(label: "Notes (optional)") {
                    TextField("", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                if let formError {
                    Text(formError).font(.subheadline).foregroundStyle(DCColor.expense)
                }

                DCPrimaryButton(title: saving ? "Saving…" : (editing == nil ? "Add \(type.rawValue.capitalized)" : "Save changes")) {
                    save()
                }
                .disabled(saving)
            }
            .padding(20)
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        if let e = editing {
            type = e.type
            amountText = e.money.formatted(showCode: false)
                .replacingOccurrences(of: ",", with: "")
            accountId = e.accountId
            destAccountId = e.destAccountId
            categoryId = e.categoryId
            date = e.date
            title = e.title
            merchant = e.merchant
            notes = e.notes
        } else {
            type = initialType
            accountId = accounts.first?.id
            destAccountId = accounts.dropFirst().first?.id ?? accounts.first?.id
            categoryId = categories.first?.id
        }
    }

    private func save() {
        guard !saving else { return }
        amountError = nil
        formError = nil

        let money: Money
        do {
            money = try Money.parse(amountText, currency: currency)
        } catch {
            amountError = (error as? LocalizedError)?.errorDescription ?? "Invalid amount."
            return
        }

        guard let accId = accountId else { formError = "Pick an account."; return }

        if type == .transfer {
            guard let dest = destAccountId, dest != accId else {
                formError = "Pick a different destination account."
                return
            }
            let src = accounts.first { $0.id == accId }
            let dst = accounts.first { $0.id == dest }
            if src?.currencyCode != dst?.currencyCode {
                formError = "Cross-currency transfers are not supported."
                return
            }
        }

        if type != .transfer && categoryId == nil {
            formError = "Pick a category."
            return
        }

        saving = true
        let ctx = store.context
        if let e = editing {
            e.typeRaw = type.rawValue
            e.amountMinor = money.minorUnits
            e.currencyCode = currency.code
            e.categoryId = type == .transfer ? nil : categoryId
            e.accountId = accId
            e.destAccountId = type == .transfer ? destAccountId : nil
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.merchant = merchant.trimmingCharacters(in: .whitespaces)
            e.notes = notes.trimmingCharacters(in: .whitespaces)
            e.date = date
            e.updatedAt = Date()
        } else {
            ctx.insert(TransactionRecord(
                type: type, amountMinor: money.minorUnits, currencyCode: currency.code,
                categoryId: type == .transfer ? nil : categoryId,
                accountId: accId, destAccountId: type == .transfer ? destAccountId : nil,
                title: title.trimmingCharacters(in: .whitespaces),
                merchant: merchant.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces),
                date: date
            ))
        }
        store.save()
        dismiss()
    }
}
