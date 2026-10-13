import SwiftUI

/// Savings goals with contribution/withdrawal history and linked accounts.
struct GoalsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var showAdd = false
    @State private var editing: Goal? = nil
    @State private var detail: Goal? = nil

    var body: some View {
        NavigationStack {
            let goals = store.goals()
            let events = store.allGoalEvents()
            if goals.isEmpty {
                DCEmptyState(icon: "target", title: "No savings goals",
                             message: "Create a goal and track every contribution toward it.",
                             actionTitle: "Create a goal") { showAdd = true }
            } else {
                List {
                    ForEach(goals, id: \.id) { g in
                        let p = Finance.goalProgress(goal: g, events: events)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(g.name).font(.headline)
                                Spacer()
                                Text("\(p.percent)%").font(.subheadline).monospacedDigit()
                            }
                            Text("\(prefs.money(p.saved, code: g.currencyCode)) of \(prefs.money(g.targetMinor, code: g.currencyCode))")
                                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                            DCProgressBar(percent: p.percent)
                            if let d = g.targetDate {
                                Text("Target \(d.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(DCSpacing.card)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
                        .contentShape(Rectangle())
                        .onTapGesture { detail = g }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add goal")
                }
            }
            .sheet(isPresented: $showAdd) { DCSheet { GoalFormView() } }
            .dcSheet(value: $editing) { g in DCSheet { GoalFormView(editing: g) } }
            .dcSheet(value: $detail) { g in DCSheet { GoalDetailView(goal: g) } }
        }
    }
}

struct GoalDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    var goal: Goal

    @State private var amountText = ""
    @State private var direction = "in"
    @State private var note = ""
    @State private var error: String? = nil
    @State private var showDeleteConfirm = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                let events = store.goalEvents(for: goal.id)
                let p = Finance.goalProgress(goal: goal, events: events)
                HStack {
                    Text(goal.name).font(.title2).fontWeight(.bold)
                    Spacer()
                    Button("Edit") { showEdit = true }.foregroundStyle(DCColor.brandSoft)
                }
                Text(prefs.money(p.saved, code: goal.currencyCode))
                    .font(DCFonts.balance())
                    .foregroundStyle(DCColor.brandSoft)
                    .monospacedDigit()
                Text("of \(prefs.money(goal.targetMinor, code: goal.currencyCode)) · \(p.percent)%")
                    .foregroundStyle(.secondary)
                DCProgressBar(percent: p.percent)

                VStack(spacing: 10) {
                    DCSegmented(items: [("in", "Contribute"), ("out", "Withdraw")], selection: $direction)
                    DCField(label: "Amount (\(goal.currencyCode))", error: error) {
                        TextField("0", text: $amountText).keyboardType(.decimalPad).monospacedDigit()
                    }
                    DCField(label: "Note (optional)") {
                        TextField("", text: $note)
                    }
                    DCPrimaryButton(title: direction == "in" ? "Contribute" : "Withdraw") { record() }
                }
                .padding(DCSpacing.card)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))

                VStack(spacing: 0) {
                    ForEach(events, id: \.id) { e in
                        HStack {
                            Image(systemName: e.direction == "in" ? "arrow.down" : "arrow.up")
                                .foregroundStyle(e.direction == "in" ? DCColor.income : DCColor.expense)
                            Text(e.note.isEmpty ? (e.direction == "in" ? "Contribution" : "Withdrawal") : e.note)
                            Spacer()
                            Text("\(e.direction == "in" ? "+" : "-")\(prefs.money(e.amountMinor, code: goal.currencyCode))")
                                .font(DCFonts.money()).monospacedDigit()
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }

                Button("Delete goal", role: .destructive) { showDeleteConfirm = true }
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                    .confirmationDialog("Delete this goal?", isPresented: $showDeleteConfirm,
                                        titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.context.delete(goal)
                        store.save()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showEdit) { DCSheet { GoalFormView(editing: goal) } }
    }

    private func record() {
        error = nil
        let amount: Money
        do {
            amount = try Money.parse(amountText, currency: goal.currency)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Invalid amount."
            return
        }
        store.context.insert(GoalEvent(goalId: goal.id, direction: direction,
                                      amountMinor: amount.minorUnits,
                                      note: note.trimmingCharacters(in: .whitespaces)))
        store.save()
        amountText = ""
        note = ""
    }
}

struct GoalFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    var editing: Goal? = nil

    @State private var name = ""
    @State private var targetText = ""
    @State private var currencyCode = "MMK"
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var linkAccount = false
    @State private var accountId: UUID? = nil
    @State private var error: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(editing == nil ? "Create goal" : "Edit goal")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DCField(label: "Goal name") {
                    TextField("e.g. New phone", text: $name)
                }

                DCField(label: "Target amount (\(currencyCode))", error: error) {
                    TextField("0", text: $targetText).keyboardType(.decimalPad).monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.all, id: \.code) { c in Text(c.code).tag(c.code) }
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Target date", isOn: $hasTargetDate)
                if hasTargetDate {
                    DCField(label: "Target date") {
                        DatePicker("", selection: $targetDate, displayedComponents: .date).labelsHidden()
                    }
                }

                Toggle("Link account", isOn: $linkAccount)
                if linkAccount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                        Picker("Account", selection: $accountId) {
                            ForEach(store.accounts(), id: \.id) { a in
                                Text("\(a.name) (\(a.currencyCode))").tag(UUID?.some(a.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                DCPrimaryButton(title: editing == nil ? "Create goal" : "Save changes") { save() }
            }
            .padding(20)
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        if let e = editing {
            name = e.name
            targetText = Money(minorUnits: e.targetMinor, currency: e.currency)
                .formatted(showCode: false).replacingOccurrences(of: ",", with: "")
            currencyCode = e.currencyCode
            hasTargetDate = e.targetDate != nil
            targetDate = e.targetDate ?? Date()
            linkAccount = e.accountId != nil
            accountId = e.accountId
        } else {
            currencyCode = prefs.currencyCode
        }
    }

    private func save() {
        error = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Name is required."; return }
        let target: Int64
        do {
            target = try Money.parse(targetText, currency: Currency.of(currencyCode)).minorUnits
        } catch let parseError {
            error = (parseError as? LocalizedError)?.errorDescription ?? "Invalid amount."
            return
        }
        if let e = editing {
            e.name = n
            e.targetMinor = target
            e.currencyCode = currencyCode
            e.targetDate = hasTargetDate ? targetDate : nil
            e.accountId = linkAccount ? accountId : nil
        } else {
            store.context.insert(Goal(name: n, targetMinor: target, currencyCode: currencyCode,
                                     targetDate: hasTargetDate ? targetDate : nil,
                                     accountId: linkAccount ? accountId : nil))
        }
        store.save()
        dismiss()
    }
}
