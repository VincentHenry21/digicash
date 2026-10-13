import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings: currency, display, privacy (PIN + biometrics), exchange rates,
/// export/import/backup, notifications, and honest limitations.
struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs

    @State private var showPINSetup = false
    @State private var showRates = false
    @State private var showExport = false
    @State private var showImport = false
    @State private var showAbout = false
    @State private var showWipeConfirm = false
    @State private var importError: String? = nil
    @State private var exportURL: URL? = nil

    private var hasPIN: Bool { Keychain.getPINHash() != nil }

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    Picker("Currency", selection: $prefs.currencyCode) {
                        ForEach(Currency.all, id: \.code) { c in
                            Text("\(c.code) · \(c.name)").tag(c.code)
                        }
                    }
                    Toggle("Myanmar digits (၀-၉)", isOn: $prefs.useMyanmarDigits)
                    Toggle("Week starts Monday", isOn: $prefs.weekStartsMonday)
                    Picker("Appearance", selection: $prefs.theme) {
                        Text("System").tag("system")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    Toggle("Hide balances", isOn: $prefs.balanceHidden)
                }

                Section("Privacy") {
                    HStack {
                        Text("App PIN")
                        Spacer()
                        Text(hasPIN ? "On" : "Off").foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showPINSetup = true }
                    if hasPIN {
                        Toggle("Lock on launch", isOn: $prefs.lockOnLaunch)
                    }
                    Button("Enable notifications") { DCNotifications.requestPermission() }
                }

                Section("Data") {
                    Button("Exchange rates") { showRates = true }
                    Button("Export CSV") { showExport = true }
                    Button("Full backup (JSON)") { exportBackup() }
                    Button("Import CSV") { showImport = true }
                    if let importError {
                        Text(importError).font(.caption).foregroundStyle(DCColor.expense)
                    }
                }

                Section("Danger zone") {
                    Button("Erase all data", role: .destructive) { showWipeConfirm = true }
                }

                Section("About") {
                    Button("About DigiCash") { showAbout = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Erase everything?",
                                isPresented: $showWipeConfirm, titleVisibility: .visible) {
                Button("Erase all data", role: .destructive) { wipe() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All accounts, transactions, budgets, goals, and settings are removed from this device. This cannot be undone.")
            }
            .sheet(isPresented: $showPINSetup) { DCSheet { PINSetupView() } }
            .sheet(isPresented: $showRates) { DCSheet { RatesView() } }
            .sheet(isPresented: $showExport) { DCSheet { ExportView() } }
            .sheet(isPresented: $showImport) { DCSheet { ImportView(onError: { importError = $0 }) } }
            .sheet(isPresented: $showAbout) { DCSheet { AboutView() } }
            .fileExporter(isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            ), document: exportURL.map(BackupDocument.init(url:)), contentType: .json,
                          defaultFilename: "digicash-backup.json") { _ in }
        }
    }

    private func exportBackup() {
        do {
            let url = try BackupService.export(store: store)
            exportURL = url
        } catch {
            importError = "Backup failed: \(error.localizedDescription)"
        }
    }

    private func wipe() {
        let ctx = store.context
        for a in store.accounts(activeOnly: false) { ctx.delete(a) }
        for c in store.categories() { ctx.delete(c) }
        for t in store.transactions() { ctx.delete(t) }
        for b in store.budgets(activeOnly: false) { ctx.delete(b) }
        for g in store.goals(activeOnly: false) { ctx.delete(g) }
        for e in store.allGoalEvents() { ctx.delete(e) }
        for r in (try? ctx.fetch(FetchDescriptor<RecurringTemplate>())) ?? [] { ctx.delete(r) }
        for r in store.rates() { ctx.delete(r) }
        Keychain.deletePINHash()
        let keys = ["dc.currency", "dc.myanmarDigits", "dc.weekMonday", "dc.theme",
                    "dc.balanceHidden", "dc.lockOnLaunch", "dc.onboardingDone"]
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
        store.save()
        prefs.onboardingDone = false
    }
}

// MARK: - PIN setup

struct PINSetupView: View {
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    @State private var pin = ""
    @State private var confirm = ""
    @State private var error: String? = nil
    private var hasPIN: Bool { Keychain.getPINHash() != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(hasPIN ? "Change PIN" : "Set app PIN")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("The PIN is hashed (SHA-256) and stored in the device Keychain. It never leaves this device.")
                    .font(.subheadline).foregroundStyle(.secondary)
                DCField(label: "New PIN (4+ digits)", error: error) {
                    SecureField("", text: $pin).keyboardType(.numberPad)
                }
                DCField(label: "Confirm PIN") {
                    SecureField("", text: $confirm).keyboardType(.numberPad)
                }
                DCPrimaryButton(title: hasPIN ? "Update PIN" : "Set PIN") { setPIN() }
                if hasPIN {
                    Button("Remove PIN", role: .destructive) {
                        Keychain.deletePINHash()
                        prefs.lockOnLaunch = false
                        dismiss()
                    }
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                }
            }
            .padding(20)
        }
    }

    private func setPIN() {
        error = nil
        guard pin.count >= 4, pin.allSatisfy({ $0.isNumber }) else {
            error = "Use at least 4 digits."
            return
        }
        guard pin == confirm else { error = "PINs do not match."; return }
        if Keychain.setPINHash(Keychain.hashPIN(pin)) {
            prefs.lockOnLaunch = true
            dismiss()
        } else {
            error = "Could not save the PIN. Try again."
        }
    }
}

// MARK: - Exchange rates

struct RatesView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    @State private var edits: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Exchange rates")
                    .font(.title2).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Manual rates only. Labeled with source and time. Never presented as live market data.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(Currency.all.filter { $0.code != "MMK" }, id: \.code) { c in
                    let rate = store.rates().first { $0.code == c.code }
                    DCField(label: "1 \(c.code) = ? MMK",
                            hint: rate.map { "Manual · updated \($0.updatedAt.formatted(date: .abbreviated, time: .shortened))" }) {
                        TextField("e.g. 2100", text: Binding(
                            get: { edits[c.code] ?? (rate.map { String(format: "%g", $0.perUnitMMK) } ?? "") },
                            set: { edits[c.code] = $0 }
                        ))
                        .keyboardType(.decimalPad).monospacedDigit()
                    }
                }
                DCPrimaryButton(title: "Save rates") {
                    for (code, text) in edits {
                        let v = Double(text.replacingOccurrences(of: ",", with: "")) ?? 0
                        guard v > 0 else { continue }
                        if let r = store.rates().first(where: { $0.code == code }) {
                            r.perUnitMMK = v
                            r.source = "manual"
                            r.updatedAt = Date()
                        } else {
                            store.context.insert(ExchangeRate(code: code, perUnitMMK: v))
                        }
                    }
                    store.save()
                    dismiss()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Export

struct ExportView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var url: URL? = nil

    var body: some View {
        VStack(spacing: 16) {
            Text("Export CSV")
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Exports all transactions as CSV. Amounts are in minor units (exact).")
                .font(.subheadline).foregroundStyle(.secondary)
            DCPrimaryButton(title: "Generate CSV") {
                url = BackupService.exportCSV(store: store)
            }
            if url != nil {
                ShareLink("Share CSV", item: url!)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(DCColor.brand)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
            }
            Spacer()
        }
        .padding(20)
    }
}

struct ImportView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    var onError: (String) -> Void
    @State private var importing = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Import CSV")
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Expected columns: type,amountMinor,currency,accountName,title,date. Amounts must be whole minor units. Invalid rows are skipped and reported.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button(importing ? "Importing…" : "Choose CSV file") { importing = true }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity).frame(minHeight: 50)
                .background(DCColor.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    do {
                        let report = try BackupService.importCSV(store: store, from: url)
                        dismiss()
                        if report.skipped > 0 {
                            onError("Imported \(report.imported), skipped \(report.skipped) invalid rows.")
                        }
                    } catch {
                        onError("Import failed: \(error.localizedDescription)")
                        dismiss()
                    }
                case .failure(let e):
                    onError("Import failed: \(e.localizedDescription)")
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

// MARK: - About (honest limitations)

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("Logo")
                    .resizable().scaledToFit()
                    .frame(width: 88, height: 88)
                    .shadow(color: DCColor.brand.opacity(0.4), radius: 20)
                Text("DigiCash").font(.title).fontWeight(.heavy)
                Text("Version 1.0 · Built for iOS")
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("What DigiCash does not do").font(.headline)
                    limitation("Bank connections", "DigiCash never connects to banks. All data is entered by hand.")
                    limitation("Cloud sync", "No cloud account, no sync. Your data lives on this device.")
                    limitation("Live exchange rates", "Rates are manual entries you type in, labeled with source and time.")
                    limitation("Financial advice", "Charts and observations describe your data. They are not advice.")
                }
                .padding(DCSpacing.card)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
                Spacer()
            }
            .padding(20)
        }
    }

    private func limitation(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(DCColor.brandSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold).font(.subheadline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Backup document + service

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: .immediate)
    }
}

struct ImportReport { var imported: Int; var skipped: Int }

enum BackupService {
    static func export(store: DataStore) throws -> URL {
        let ctx = store.context
        // Encode via JSONEncoder-friendly structs
        struct AC: Codable { var id: UUID; var name: String; var type: String; var currency: String; var opening: Int64; var created: Date; var archived: Date? }
        struct CT: Codable { var id: UUID; var name: String; var kind: String; var icon: String; var color: String }
        struct TX: Codable { var id: UUID; var type: String; var amount: Int64; var currency: String; var category: UUID?; var account: UUID; var dest: UUID?; var title: String; var merchant: String; var notes: String; var date: Date }
        struct BG: Codable { var id: UUID; var name: String; var cats: [UUID]; var limit: Int64; var currency: String; var period: String; var start: Date; var end: Date }
        struct GL: Codable { var id: UUID; var name: String; var target: Int64; var currency: String; var date: Date?; var account: UUID? }
        struct GE: Codable { var id: UUID; var goal: UUID; var dir: String; var amount: Int64; var date: Date; var note: String }
        let accounts = (try? ctx.fetch(FetchDescriptor<Account>())) ?? []
        let cats = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
        let txs = (try? ctx.fetch(FetchDescriptor<TransactionRecord>())) ?? []
        let budgets = (try? ctx.fetch(FetchDescriptor<Budget>())) ?? []
        let goals = (try? ctx.fetch(FetchDescriptor<Goal>())) ?? []
        let events = (try? ctx.fetch(FetchDescriptor<GoalEvent>())) ?? []
        let bundle: [String: Any] = [
            "accounts": accounts.map { AC(id: $0.id, name: $0.name, type: $0.typeRaw, currency: $0.currencyCode, opening: $0.openingMinor, created: $0.createdAt, archived: $0.archivedAt) }.map { try! JSONEncoder().encode($0) },
            "categories": cats.map { CT(id: $0.id, name: $0.name, kind: $0.kind, icon: $0.icon, color: $0.color) }.map { try! JSONEncoder().encode($0) },
            "transactions": txs.map { TX(id: $0.id, type: $0.typeRaw, amount: $0.amountMinor, currency: $0.currencyCode, category: $0.categoryId, account: $0.accountId, dest: $0.destAccountId, title: $0.title, merchant: $0.merchant, notes: $0.notes, date: $0.date) }.map { try! JSONEncoder().encode($0) },
            "budgets": budgets.map { BG(id: $0.id, name: $0.name, cats: $0.categoryIds, limit: $0.limitMinor, currency: $0.currencyCode, period: $0.period, start: $0.startDate, end: $0.endDate) }.map { try! JSONEncoder().encode($0) },
            "goals": goals.map { GL(id: $0.id, name: $0.name, target: $0.targetMinor, currency: $0.currencyCode, date: $0.targetDate, account: $0.accountId) }.map { try! JSONEncoder().encode($0) },
            "goalEvents": events.map { GE(id: $0.id, goal: $0.goalId, dir: $0.direction, amount: $0.amountMinor, date: $0.date, note: $0.note) }.map { try! JSONEncoder().encode($0) }
        ]
        let data = try JSONSerialization.data(withJSONObject: jsonable(bundle), options: .prettyPrinted)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("digicash-backup-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }

    private static func jsonable(_ bundle: [String: Any]) -> [String: Any] {
        var out: [String: Any] = ["version": 1,
                                  "exportedAt": ISO8601DateFormatter().string(from: Date())]
        for (k, v) in bundle {
            if let arr = v as? [Data] {
                out[k] = arr.compactMap { try? JSONSerialization.jsonObject(with: $0) }
            }
        }
        return out
    }

    static func exportCSV(store: DataStore) -> URL {
        let txs = store.transactions()
        let accs = Dictionary(uniqueKeysWithValues: store.accounts(activeOnly: false).map { ($0.id, $0.name) })
        var lines = ["id,type,amountMinor,currency,categoryId,accountName,title,date"]
        let df = ISO8601DateFormatter()
        for t in txs {
            let row = [t.id.uuidString, t.typeRaw, String(t.amountMinor), t.currencyCode,
                       t.categoryId?.uuidString ?? "", csvEscape(accs[t.accountId] ?? ""),
                       csvEscape(t.title), df.string(from: t.date)].joined(separator: ",")
            lines.append(row)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("digicash-transactions.csv")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func csvEscape(_ s: String) -> String {
        s.contains(",") || s.contains("\"") ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }

    static func importCSV(store: DataStore, from url: URL) throws -> ImportReport {
        guard url.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return ImportReport(imported: 0, skipped: 0) }
        let accounts = store.accounts(activeOnly: false)
        let nameToId = Dictionary(uniqueKeysWithValues: accounts.map { ($0.name.lowercased(), $0.id) })
        var imported = 0, skipped = 0
        for line in lines.dropFirst() {
            let parts = splitCSV(line)
            guard parts.count >= 7,
                  let type = TransactionType(rawValue: parts[1].lowercased()),
                  let amount = Int64(parts[2]),
                  amount > 0,
                  let accId = nameToId[parts[5].lowercased()] else {
                skipped += 1
                continue
            }
            let acc = accounts.first { $0.id == accId }!
            let date = ISO8601DateFormatter().date(from: parts[6]) ?? Date()
            store.context.insert(TransactionRecord(
                type: type, amountMinor: amount, currencyCode: parts[3].isEmpty ? acc.currencyCode : parts[3],
                accountId: accId, title: parts[4], date: date, importSource: "csv"
            ))
            imported += 1
        }
        store.save()
        return ImportReport(imported: imported, skipped: skipped)
    }

    private static func splitCSV(_ line: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inQuotes = false
        var it = line.makeIterator()
        while let ch = it.next() {
            if ch == "\"" {
                if inQuotes { inQuotes = false } else { inQuotes = true }
            } else if ch == "," && !inQuotes {
                out.append(cur); cur = ""
            } else {
                cur.append(ch)
            }
        }
        out.append(cur)
        return out
    }
}
