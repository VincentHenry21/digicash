import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case expense, income, transfer, refund, opening, adjustment
}

enum AccountType: String, Codable, CaseIterable {
    case cash, bank, savings, ewallet

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .bank: return "Bank Account"
        case .savings: return "Savings Account"
        case .ewallet: return "E-Wallet"
        }
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var currencyCode: String
    var openingMinor: Int64
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    var type: AccountType { AccountType(rawValue: typeRaw) ?? .cash }
    var currency: Currency { Currency.of(currencyCode) }
    var isArchived: Bool { archivedAt != nil }

    init(id: UUID = UUID(), name: String, type: AccountType, currencyCode: String,
         openingMinor: Int64 = 0, createdAt: Date = Date(), archivedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.currencyCode = currencyCode
        self.openingMinor = openingMinor
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.archivedAt = archivedAt
    }
}

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    /// "expense" or "income"
    var kind: String
    var icon: String
    var color: String
    var isSystem: Bool

    init(id: UUID = UUID(), name: String, kind: String, icon: String, color: String, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.icon = icon
        self.color = color
        self.isSystem = isSystem
    }
}

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var amountMinor: Int64
    var currencyCode: String
    var categoryId: UUID?
    var accountId: UUID
    var destAccountId: UUID?
    var title: String
    var merchant: String
    var notes: String
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    var recurringId: UUID?
    var importSource: String?

    var type: TransactionType { TransactionType(rawValue: typeRaw) ?? .expense }
    var currency: Currency { Currency.of(currencyCode) }
    var money: Money { Money(minorUnits: amountMinor, currency: currency) }

    init(id: UUID = UUID(), type: TransactionType, amountMinor: Int64, currencyCode: String,
         categoryId: UUID? = nil, accountId: UUID, destAccountId: UUID? = nil,
         title: String = "", merchant: String = "", notes: String = "",
         date: Date = Date(), recurringId: UUID? = nil, importSource: String? = nil) {
        self.id = id
        self.typeRaw = type.rawValue
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.categoryId = categoryId
        self.accountId = accountId
        self.destAccountId = destAccountId
        self.title = title
        self.merchant = merchant
        self.notes = notes
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recurringId = recurringId
        self.importSource = importSource
    }
}

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryIds: [UUID]
    var limitMinor: Int64
    var currencyCode: String
    /// "weekly", "monthly", "yearly"
    var period: String
    var startDate: Date
    var endDate: Date
    var thresholds: [Int]
    var notified: [Int]
    var createdAt: Date
    var archivedAt: Date?

    var currency: Currency { Currency.of(currencyCode) }
    var isArchived: Bool { archivedAt != nil }

    init(id: UUID = UUID(), name: String, categoryIds: [UUID], limitMinor: Int64,
         currencyCode: String, period: String, startDate: Date, endDate: Date,
         thresholds: [Int] = [80]) {
        self.id = id
        self.name = name
        self.categoryIds = categoryIds
        self.limitMinor = limitMinor
        self.currencyCode = currencyCode
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.thresholds = thresholds
        self.notified = []
        self.createdAt = Date()
        self.archivedAt = nil
    }
}

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetMinor: Int64
    var currencyCode: String
    var targetDate: Date?
    var accountId: UUID?
    var status: String // "active" | "archived"
    var createdAt: Date

    var currency: Currency { Currency.of(currencyCode) }
    var isActive: Bool { status == "active" }

    init(id: UUID = UUID(), name: String, targetMinor: Int64, currencyCode: String,
         targetDate: Date? = nil, accountId: UUID? = nil) {
        self.id = id
        self.name = name
        self.targetMinor = targetMinor
        self.currencyCode = currencyCode
        self.targetDate = targetDate
        self.accountId = accountId
        self.status = "active"
        self.createdAt = Date()
    }
}

@Model
final class GoalEvent {
    @Attribute(.unique) var id: UUID
    var goalId: UUID
    /// "in" | "out"
    var direction: String
    var amountMinor: Int64
    var date: Date
    var note: String

    init(id: UUID = UUID(), goalId: UUID, direction: String, amountMinor: Int64,
         date: Date = Date(), note: String = "") {
        self.id = id
        self.goalId = goalId
        self.direction = direction
        self.amountMinor = amountMinor
        self.date = date
        self.note = note
    }
}

@Model
final class RecurringTemplate {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var amountMinor: Int64
    var currencyCode: String
    var categoryId: UUID?
    var accountId: UUID
    var title: String
    /// "daily" | "weekly" | "monthly" | "yearly"
    var frequency: String
    var startDate: Date
    var nextDate: Date
    var endDate: Date?
    var paused: Bool

    var type: TransactionType { TransactionType(rawValue: typeRaw) ?? .expense }
    var currency: Currency { Currency.of(currencyCode) }

    init(id: UUID = UUID(), type: TransactionType, amountMinor: Int64, currencyCode: String,
         categoryId: UUID? = nil, accountId: UUID, title: String = "",
         frequency: String, startDate: Date, nextDate: Date) {
        self.id = id
        self.typeRaw = type.rawValue
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.categoryId = categoryId
        self.accountId = accountId
        self.title = title
        self.frequency = frequency
        self.startDate = startDate
        self.nextDate = nextDate
        self.endDate = nil
        self.paused = false
    }
}

@Model
final class ExchangeRate {
    @Attribute(.unique) var code: String
    /// MMK per 1 unit of `code`. Manual entries only, labeled with source + time.
    var perUnitMMK: Double
    var source: String
    var updatedAt: Date

    init(code: String, perUnitMMK: Double, source: String = "manual", updatedAt: Date = Date()) {
        self.code = code
        self.perUnitMMK = perUnitMMK
        self.source = source
        self.updatedAt = updatedAt
    }
}
