import SwiftUI
import SwiftData

/// Recurring transaction templates with pause/resume and next-date preview.
struct RecurringView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var showAdd = false
    @State private var editing: RecurringTemplate? = nil

    var body: some View {
        NavigationStack {
            let templates = (try? store.context.fetch(FetchDescriptor<RecurringTemplate>())) ?? []
            if templates.isEmpty {
                DCEmptyState(icon: "repeat", title: "No recurring transactions",
                             message: "Salary, rent, and bills can post automatically on schedule.",
                             actionTitle: "Add recurring") { showAdd = true }
            } else {
                List {
                    ForEach(templates, id: \.id) { t in
                        let cats = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
                        let accs = Dictionary(uniqueKeysWithValues: store.accounts(activeOnly: false).map { ($0.id, $0) })
                        HStack(spacing: 12) {
                            DCCategoryIcon(icon: t.type == .income ? "arrow.down" : "arrow.up",
                                           color: t.type == .income ? "green" : "orange")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title.isEmpty ? t.type.rawValue.capitalized : t.title)
                                    .fontWeight(.semibold)
                                Text("\(t.frequency.capitalized) · next \(t.nextDate.formatted(date: .abbreviated, time: .omitted)) · \(accs[t.accountId]?.name ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(prefs.money(t.amountMinor, code: t.currencyCode))
                                    .font(DCFonts.money()).monospacedDigit()
                                Toggle("", isOn: Binding(
                                    get: { !t.paused },
                                    set: { t.paused = !$0; store.save() }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                            }
                        }
                        .opacity(t.paused ? 0.5 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = t }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add recurring")
                }
            }
            .sheet(isPresented: $showAdd) { DCSheet { RecurringFormView() } }
            .dcSheet(value: $editing) { t in DCSheet { RecurringFormView(editing: t) } }
        }
    }
}

struct RecurringFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    var editing: RecurringTemplate? = nil

    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var accountId: UUID? = nil
    @State private var categoryId: UUID? = nil
    @State private var title = ""
    @State private var frequency = "monthly"
    @State private var startDate = Date()
    @State private var error: String? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(editing == nil ? "Add recurring" : "Edit recurring")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DCSegmented(items: [(.expense, "Expense"), (.income, "Income")], selection: $type)

                DCField(label: "Amount (\(prefs.currencyCode))", error: error) {
                    TextField("0", text: $amountText).keyboardType(.decimalPad).monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Account", selection: $accountId) {
                        ForEach(store.accounts(), id: \.id) { a in
                            Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Category", selection: $categoryId) {
                        ForEach(store.categories(kind: type == .income ? "income" : "expense"), id: \.id) { c in
                            Text(c.name).tag(UUID?.some(c.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequency").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    DCSegmented(items: [("daily", "Daily"), ("weekly", "Weekly"),
                                        ("monthly", "Monthly"), ("yearly", "Yearly")],
                                selection: $frequency)
                }

                DCField(label: "Start date") {
                    DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden()
                }

                DCField(label: "Title") {
                    TextField("e.g. Rent", text: $title)
                }

                DCPrimaryButton(title: editing == nil ? "Add recurring" : "Save changes") { save() }

                if editing != nil {
                    Button("Delete template", role: .destructive) { showDeleteConfirm = true }
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                        .confirmationDialog("Delete this template?", isPresented: $showDeleteConfirm,
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
            type = e.type
            amountText = Money(minorUnits: e.amountMinor, currency: e.currency)
                .formatted(showCode: false).replacingOccurrences(of: ",", with: "")
            accountId = e.accountId
            categoryId = e.categoryId
            title = e.title
            frequency = e.frequency
            startDate = e.startDate
        } else {
            accountId = store.accounts().first?.id
            categoryId = store.categories(kind: "expense").first?.id
        }
    }

    private func save() {
        error = nil
        let acc = store.accounts().first { $0.id == accountId }
        let cur = acc?.currency ?? prefs.currency
        let amount: Int64
        do {
            amount = try Money.parse(amountText, currency: cur).minorUnits
        } catch let parseError {
            error = (parseError as? LocalizedError)?.errorDescription ?? "Invalid amount."
            return
        }
        guard accountId != nil else { error = "Pick an account."; return }
        if let e = editing {
            e.typeRaw = type.rawValue
            e.amountMinor = amount
            e.currencyCode = cur.code
            e.categoryId = categoryId
            e.accountId = accountId!
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.frequency = frequency
            e.startDate = startDate
            e.nextDate = Finance.advance(startDate, frequency: frequency)
        } else {
            store.context.insert(RecurringTemplate(
                type: type, amountMinor: amount, currencyCode: cur.code,
                categoryId: categoryId, accountId: accountId!,
                title: title.trimmingCharacters(in: .whitespaces),
                frequency: frequency, startDate: startDate,
                nextDate: Finance.advance(startDate, frequency: frequency)
            ))
        }
        store.save()
        store.runRecurring()
        dismiss()
    }
}
