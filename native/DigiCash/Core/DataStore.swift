import Foundation
import SwiftData
import CryptoKit

/// App-wide preferences. Stored in UserDefaults; the PIN hash lives in Keychain.
final class Prefs: ObservableObject {
    static let shared = Prefs()

    @Published var currencyCode: String {
        didSet { UserDefaults.standard.set(currencyCode, forKey: "dc.currency") }
    }
    @Published var useMyanmarDigits: Bool {
        didSet { UserDefaults.standard.set(useMyanmarDigits, forKey: "dc.myanmarDigits") }
    }
    @Published var weekStartsMonday: Bool {
        didSet { UserDefaults.standard.set(weekStartsMonday, forKey: "dc.weekMonday") }
    }
    @Published var theme: String {
        didSet { UserDefaults.standard.set(theme, forKey: "dc.theme") }
    }
    @Published var balanceHidden: Bool {
        didSet { UserDefaults.standard.set(balanceHidden, forKey: "dc.balanceHidden") }
    }
    @Published var lockOnLaunch: Bool {
        didSet { UserDefaults.standard.set(lockOnLaunch, forKey: "dc.lockOnLaunch") }
    }
    @Published var onboardingDone: Bool {
        didSet { UserDefaults.standard.set(onboardingDone, forKey: "dc.onboardingDone") }
    }

    var currency: Currency { Currency.of(currencyCode) }

    private init() {
        let d = UserDefaults.standard
        currencyCode = d.string(forKey: "dc.currency") ?? "MMK"
        useMyanmarDigits = d.bool(forKey: "dc.myanmarDigits")
        weekStartsMonday = d.object(forKey: "dc.weekMonday") == nil ? true : d.bool(forKey: "dc.weekMonday")
        theme = d.string(forKey: "dc.theme") ?? "dark"
        balanceHidden = d.bool(forKey: "dc.balanceHidden")
        lockOnLaunch = d.bool(forKey: "dc.lockOnLaunch")
        onboardingDone = d.bool(forKey: "dc.onboardingDone")
    }

    func money(_ minor: Int64, code: String? = nil) -> String {
        let c = Currency.of(code ?? currencyCode)
        return Money(minorUnits: minor, currency: c).formatted(useMyanmarDigits: useMyanmarDigits)
    }
}

/// Minimal Keychain wrapper for the PIN hash. Raw PINs are never stored.
enum Keychain {
    static let pinService = "com.digicash.app.pin"

    static func setPINHash(_ hash: String) -> Bool {
        deletePINHash()
        let data = Data(hash.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: pinService,
            kSecAttrAccount as String: "pin",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func getPINHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: pinService,
            kSecAttrAccount as String: "pin",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePINHash() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: pinService,
            kSecAttrAccount as String: "pin"
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hashPIN(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data("digicash-pin:\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// SwiftData container + seeding + recurring engine.
@MainActor
final class DataStore: ObservableObject {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let schema = Schema([
            Account.self, Category.self, TransactionRecord.self,
            Budget.self, Goal.self, GoalEvent.self,
            RecurringTemplate.self, ExchangeRate.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        seedIfNeeded()
        runRecurring()
    }

    // MARK: - Seeding (Myanmar everyday categories first)

    /// Public so onboarding can reseed after a full data wipe.
    func ensureSeeded() {
        seedIfNeeded()
    }

    private func seedIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        let expense: [(String, String, String)] = [
            ("Food & Dining", "fork.knife", "orange"),
            ("Groceries", "cart", "green"),
            ("Transportation", "car", "blue"),
            ("Phone Bills", "phone", "purple"),
            ("Shopping", "bag", "pink"),
            ("Housing", "house", "teal"),
            ("Bills & Utilities", "bolt", "yellow"),
            ("Health", "heart", "red"),
            ("Education", "book", "indigo"),
            ("Entertainment", "play", "violet"),
            ("Family Expenses", "person.2", "rose"),
            ("Personal Care", "sparkles", "cyan"),
            ("Subscriptions", "repeat", "slate"),
            ("Gifts & Donations", "gift", "amber"),
            ("Travel", "airplane", "sky"),
            ("Other", "ellipsis", "gray")
        ]
        let income: [(String, String, String)] = [
            ("Salary", "briefcase", "green"),
            ("Business Income", "storefront", "teal"),
            ("Freelance", "laptopcomputer", "blue"),
            ("Allowance", "hand.raised", "amber"),
            ("Interest", "percent", "indigo"),
            ("Other", "ellipsis", "gray")
        ]
        for (name, icon, color) in expense {
            context.insert(Category(name: name, kind: "expense", icon: icon, color: color, isSystem: true))
        }
        for (name, icon, color) in income {
            context.insert(Category(name: name, kind: "income", icon: icon, color: color, isSystem: true))
        }
        try? context.save()
    }

    // MARK: - Recurring engine (idempotent)

    func runRecurring() {
        let now = Date()
        let templates = (try? context.fetch(FetchDescriptor<RecurringTemplate>())) ?? []
        var changed = false
        for t in templates where !t.paused {
            var guardCount = 0
            while t.nextDate <= now && guardCount < 60 {
                if let end = t.endDate, t.nextDate > end { break }
                context.insert(TransactionRecord(
                    type: t.type, amountMinor: t.amountMinor, currencyCode: t.currencyCode,
                    categoryId: t.categoryId, accountId: t.accountId,
                    title: t.title, notes: "Recurring", date: t.nextDate,
                    recurringId: t.id
                ))
                t.nextDate = Finance.advance(t.nextDate, frequency: t.frequency)
                changed = true
                guardCount += 1
            }
        }
        if changed { try? context.save() }
    }

    // MARK: - Fetch helpers

    func accounts(activeOnly: Bool = true) -> [Account] {
        let all = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return activeOnly ? all.filter { !$0.isArchived } : all
    }

    func categories(kind: String? = nil) -> [Category] {
        var desc = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
        if let kind { desc.predicate = #Predicate { $0.kind == kind } }
        return (try? context.fetch(desc)) ?? []
    }

    func transactions() -> [TransactionRecord] {
        (try? context.fetch(FetchDescriptor<TransactionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    func budgets(activeOnly: Bool = true) -> [Budget] {
        let all = (try? context.fetch(FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        return activeOnly ? all.filter { !$0.isArchived } : all
    }

    func goals(activeOnly: Bool = true) -> [Goal] {
        let all = (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        return activeOnly ? all.filter { $0.isActive } : all
    }

    func goalEvents(for goalId: UUID) -> [GoalEvent] {
        var desc = FetchDescriptor<GoalEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.predicate = #Predicate { $0.goalId == goalId }
        return (try? context.fetch(desc)) ?? []
    }

    func allGoalEvents() -> [GoalEvent] {
        (try? context.fetch(FetchDescriptor<GoalEvent>())) ?? []
    }

    func rates() -> [ExchangeRate] {
        (try? context.fetch(FetchDescriptor<ExchangeRate>())) ?? []
    }

    func save() {
        try? context.save()
    }
}
