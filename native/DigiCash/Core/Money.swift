import Foundation

/// ISO currency definition. MMK uses 0 decimals: the kyat circulates
/// without subunits, so 1 minor unit = 1 MMK.
struct Currency: Hashable, Sendable {
    let code: String
    let name: String
    let country: String
    let minorDigits: Int
    let symbol: String

    static let mmk = Currency(code: "MMK", name: "Myanmar Kyat", country: "Myanmar", minorDigits: 0, symbol: "K")
    static let usd = Currency(code: "USD", name: "US Dollar", country: "United States", minorDigits: 2, symbol: "$")
    static let eur = Currency(code: "EUR", name: "Euro", country: "Eurozone", minorDigits: 2, symbol: "€")
    static let gbp = Currency(code: "GBP", name: "British Pound", country: "United Kingdom", minorDigits: 2, symbol: "£")
    static let sgd = Currency(code: "SGD", name: "Singapore Dollar", country: "Singapore", minorDigits: 2, symbol: "S$")
    static let thb = Currency(code: "THB", name: "Thai Baht", country: "Thailand", minorDigits: 2, symbol: "฿")
    static let jpy = Currency(code: "JPY", name: "Japanese Yen", country: "Japan", minorDigits: 0, symbol: "¥")
    static let cny = Currency(code: "CNY", name: "Chinese Yuan", country: "China", minorDigits: 2, symbol: "¥")
    static let krw = Currency(code: "KRW", name: "South Korean Won", country: "South Korea", minorDigits: 0, symbol: "₩")
    static let inr = Currency(code: "INR", name: "Indian Rupee", country: "India", minorDigits: 2, symbol: "₹")
    static let myr = Currency(code: "MYR", name: "Malaysian Ringgit", country: "Malaysia", minorDigits: 2, symbol: "RM")
    static let vnd = Currency(code: "VND", name: "Vietnamese Dong", country: "Vietnam", minorDigits: 0, symbol: "₫")
    static let aud = Currency(code: "AUD", name: "Australian Dollar", country: "Australia", minorDigits: 2, symbol: "A$")
    static let cad = Currency(code: "CAD", name: "Canadian Dollar", country: "Canada", minorDigits: 2, symbol: "C$")

    static let all: [Currency] = [.mmk, .usd, .eur, .gbp, .sgd, .thb, .jpy, .cny, .krw, .inr, .myr, .vnd, .aud, .cad]

    static func of(_ code: String) -> Currency {
        all.first { $0.code == code.uppercased() } ?? .mmk
    }
}

enum MoneyError: Error, LocalizedError {
    case invalidFormat
    case tooManyDecimals(currency: String)
    case notPositive
    case tooLarge
    case currencyMismatch

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Enter a valid amount."
        case .tooManyDecimals(let c): return "Too many decimal places for \(c)."
        case .notPositive: return "Amount must be greater than zero."
        case .tooLarge: return "Amount is too large."
        case .currencyMismatch: return "Currencies do not match."
        }
    }
}

private let myanmarDigits = ["၀","၁","၂","၃","၄","၅","၆","၇","၈","၉"]

/// Exact money: integer minor units. No floating point, ever.
struct Money: Hashable, Comparable, Sendable {
    var minorUnits: Int64
    var currency: Currency

    static let zeroMMK = Money(minorUnits: 0, currency: .mmk)

    /// Parse user input like "1,250,000" into minor units. Throws on invalid input.
    /// Myanmar digits are normalized to ASCII first.
    static func parse(_ text: String, currency: Currency) throws -> Money {
        let ascii = text.map { ch -> Character in
            if let idx = myanmarDigits.firstIndex(of: String(ch)),
               let scalar = Unicode.Scalar(48 + idx) {
                return Character(scalar)
            }
            return ch
        }
        let s = String(ascii).trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
        guard !s.isEmpty else { throw MoneyError.invalidFormat }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 2,
              parts[0].allSatisfy({ $0.isNumber }),
              (parts.count == 1 || parts[1].allSatisfy({ $0.isNumber })) else {
            throw MoneyError.invalidFormat
        }
        let frac = parts.count == 2 ? parts[1] : ""
        guard frac.count <= currency.minorDigits else { throw MoneyError.tooManyDecimals(currency: currency.code) }
        let scale = Int64(pow(10.0, Double(currency.minorDigits)))
        let whole = Int64(parts[0]) ?? 0
        var fracUnits: Int64 = 0
        if !frac.isEmpty {
            let padded = frac.padding(toLength: currency.minorDigits, withPad: "0", startingAt: 0)
            fracUnits = Int64(padded) ?? 0
        }
        let (w, wOver) = whole.multipliedReportingOverflow(by: scale)
        let (total, tOver) = w.addingReportingOverflow(fracUnits)
        guard !wOver, !tOver else { throw MoneyError.tooLarge }
        guard total > 0 else { throw MoneyError.notPositive }
        return Money(minorUnits: total, currency: currency)
    }

    var isNegative: Bool { minorUnits < 0 }
    var abs: Money { Money(minorUnits: Swift.abs(minorUnits), currency: currency) }

    private func requireSameCurrency(_ other: Money) throws {
        guard currency.code == other.currency.code else { throw MoneyError.currencyMismatch }
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency.code == rhs.currency.code, "currency mismatch")
        let (v, over) = lhs.minorUnits.addingReportingOverflow(rhs.minorUnits)
        precondition(!over, "overflow")
        return Money(minorUnits: v, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency.code == rhs.currency.code, "currency mismatch")
        let (v, over) = lhs.minorUnits.subtractingReportingOverflow(rhs.minorUnits)
        precondition(!over, "overflow")
        return Money(minorUnits: v, currency: lhs.currency)
    }

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency.code == rhs.currency.code, "currency mismatch")
        return lhs.minorUnits < rhs.minorUnits
    }

    /// Centralized formatter. Default English style: "1,250,000 MMK".
    func formatted(useMyanmarDigits: Bool = false, showCode: Bool = true) -> String {
        let scale = Int64(pow(10.0, Double(currency.minorDigits)))
        let neg = minorUnits < 0
        let a = neg ? minorUnits.magnitude : UInt64(minorUnits)
        let intPart = scale > 0 ? a / UInt64(scale) : a
        let fracPart = scale > 1 ? a % UInt64(scale) : 0
        var intStr = group(String(intPart))
        if useMyanmarDigits {
            intStr = intStr.map { c -> String in
                if let d = c.wholeNumberValue { return myanmarDigits[d] }
                return String(c)
            }.joined()
        }
        var fracStr = ""
        if currency.minorDigits > 0 {
            var f = String(fracPart)
            while f.count < currency.minorDigits { f = "0" + f }
            if useMyanmarDigits {
                f = f.map { c -> String in
                    if let d = c.wholeNumberValue { return myanmarDigits[d] }
                    return String(c)
                }.joined()
            }
            fracStr = "." + f
        }
        let num = (neg ? "-" : "") + intStr + fracStr
        return showCode ? num + " " + currency.code : num
    }

    /// Compact display for tight spaces, e.g. "1.25M MMK".
    func formattedCompact() -> String {
        let scale = Double(pow(10.0, Double(currency.minorDigits)))
        let major = Double(minorUnits) / scale
        let a = Swift.abs(major)
        let neg = major < 0 ? "-" : ""
        if a >= 1_000_000_000 { return "\(neg)\(String(format: "%.2f", a / 1_000_000_000))B \(currency.code)" }
        if a >= 1_000_000 { return "\(neg)\(String(format: "%.2f", a / 1_000_000))M \(currency.code)" }
        if a >= 1_000 { return "\(neg)\(String(format: "%.2f", a / 1_000))K \(currency.code)" }
        return formatted()
    }

    private func group(_ s: String) -> String {
        var out = ""
        var count = 0
        for ch in s.reversed() {
            out.append(ch)
            count += 1
            if count % 3 == 0 && count != s.count { out.append(",") }
        }
        return String(out.reversed())
    }
}
