import Foundation

enum MoneyError: Error { case invalidAmount, overflow, currencyMismatch }

struct Money: Codable, Equatable, Sendable {
    let minorUnits: Int64
    let currencyCode: String

    private enum CodingKeys: String, CodingKey { case minorUnits, currencyCode }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(minorUnits: container.decode(Int64.self, forKey: .minorUnits),
                      currencyCode: container.decode(String.self, forKey: .currencyCode))
    }

    init(minorUnits: Int64, currencyCode: String = "USD") throws {
        guard minorUnits >= 0, currencyCode == "USD" else { throw MoneyError.invalidAmount }
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    static func parse(_ text: String) throws -> Money {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else {
            throw MoneyError.invalidAmount
        }
        let parts = value.split(separator: ".")
        guard let whole = Int64(parts[0]) else { throw MoneyError.overflow }
        let scaled = whole.multipliedReportingOverflow(by: 100)
        guard !scaled.overflow else { throw MoneyError.overflow }
        let fraction = parts.count == 2 ? Int64(parts[1].count == 1 ? String(parts[1]) + "0" : String(parts[1])) ?? 0 : 0
        let sum = scaled.partialValue.addingReportingOverflow(fraction)
        guard !sum.overflow else { throw MoneyError.overflow }
        return try Money(minorUnits: sum.partialValue)
    }

    func adding(_ other: Money) throws -> Money {
        guard currencyCode == other.currencyCode else { throw MoneyError.currencyMismatch }
        let sum = minorUnits.addingReportingOverflow(other.minorUnits)
        guard !sum.overflow else { throw MoneyError.overflow }
        return try Money(minorUnits: sum.partialValue, currencyCode: currencyCode)
    }

    func multiplied(by count: Int64) throws -> Money {
        let result = minorUnits.multipliedReportingOverflow(by: count)
        guard !result.overflow else { throw MoneyError.overflow }
        return try Money(minorUnits: result.partialValue, currencyCode: currencyCode)
    }

    var formatted: String {
        (Decimal(minorUnits) / 100).formatted(.currency(code: currencyCode))
    }
}
