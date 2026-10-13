import XCTest
@testable import DigiCash

final class MoneyTests: XCTestCase {

    func testParseMMKWholeNumber() throws {
        let m = try Money.parse("15,000", currency: .mmk)
        XCTAssertEqual(m.minorUnits, 15_000)
        XCTAssertEqual(m.currency.code, "MMK")
    }

    func testParseMMKRejectsDecimals() {
        XCTAssertThrowsError(try Money.parse("15,000.5", currency: .mmk)) { err in
            guard case MoneyError.tooManyDecimals = err else {
                return XCTFail("expected tooManyDecimals, got \(err)")
            }
        }
    }

    func testParseUSDDecimals() throws {
        let m = try Money.parse("1,234.56", currency: .usd)
        XCTAssertEqual(m.minorUnits, 123_456)
        XCTAssertEqual(m.formatted(), "1,234.56 USD")
    }

    func testParseRejectsInvalid() {
        XCTAssertThrowsError(try Money.parse("abc", currency: .mmk))
        XCTAssertThrowsError(try Money.parse("", currency: .mmk))
        XCTAssertThrowsError(try Money.parse("0", currency: .mmk))
        XCTAssertThrowsError(try Money.parse("-500", currency: .mmk))
    }

    func testFormatMMK() {
        XCTAssertEqual(Money(minorUnits: 15_000, currency: .mmk).formatted(), "15,000 MMK")
        XCTAssertEqual(Money(minorUnits: 1_250_000, currency: .mmk).formatted(), "1,250,000 MMK")
    }

    func testFormatMyanmarDigits() {
        let s = Money(minorUnits: 15_000, currency: .mmk).formatted(useMyanmarDigits: true)
        XCTAssertEqual(s, "၁၅,၀၀၀ MMK")
    }

    func testArithmetic() {
        let a = Money(minorUnits: 10_000, currency: .mmk)
        let b = Money(minorUnits: 4_000, currency: .mmk)
        XCTAssertEqual((a + b).minorUnits, 14_000)
        XCTAssertEqual((a - b).minorUnits, 6_000)
        XCTAssertTrue(b < a)
    }

    func testCompact() {
        XCTAssertEqual(Money(minorUnits: 1_250_000, currency: .mmk).formattedCompact(), "1.25M MMK")
        XCTAssertEqual(Money(minorUnits: 500, currency: .mmk).formattedCompact(), "500 MMK")
    }
}
