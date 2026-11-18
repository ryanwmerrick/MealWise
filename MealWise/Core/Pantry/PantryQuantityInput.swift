import Foundation

enum PantryQuantityInput {
    static func parse(_ text: String, unit: QuantityUnit) throws -> Int64 {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = unit == .milligrams ? #"^[0-9]+(?:\.[0-9]{1,3})?$"# : #"^[0-9]+$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { throw PantryError.invalidQuantity }
        let parts = value.split(separator: ".")
        guard let whole = Int64(parts[0]) else { throw QuantityError.overflow }
        if unit != .milligrams { return whole }
        let scaled = whole.multipliedReportingOverflow(by: 1000)
        guard !scaled.overflow else { throw QuantityError.overflow }
        let fraction = parts.count == 2 ? String(parts[1]).padding(toLength: 3, withPad: "0", startingAt: 0) : "0"
        return try checkedSum(scaled.partialValue, Int64(fraction) ?? 0)
    }
    static func text(amount: Int64, unit: QuantityUnit) -> String {
        unit == .milligrams ? NSDecimalNumber(decimal: Decimal(amount) / 1000).stringValue : String(amount)
    }
    static func symbol(unit: QuantityUnit) -> String { unit == .milligrams ? "g" : (unit == .milliliters ? "mL" : String(localized: "count")) }
}
