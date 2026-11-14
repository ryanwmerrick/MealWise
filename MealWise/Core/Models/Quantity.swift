import Foundation

enum QuantityError: Error { case invalidAmount, incompatibleUnits, overflow }

enum QuantityUnit: String, Codable, Sendable {
    case milligrams, grams, kilograms, milliliters, liters, count

    var canonicalUnit: QuantityUnit {
        switch self {
        case .milligrams, .grams, .kilograms: .milligrams
        case .milliliters, .liters: .milliliters
        case .count: .count
        }
    }

    var multiplier: Int64 {
        switch self {
        case .milligrams, .milliliters, .count: 1
        case .grams, .liters: 1000
        case .kilograms: 1000000
        }
    }
}

struct Quantity: Codable, Equatable, Sendable {
    let canonicalAmount: Int64
    let unit: QuantityUnit

    private enum CodingKeys: String, CodingKey { case canonicalAmount, unit }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unit = try container.decode(QuantityUnit.self, forKey: .unit)
        guard unit == unit.canonicalUnit else { throw QuantityError.invalidAmount }
        try self.init(amount: container.decode(Int64.self, forKey: .canonicalAmount), unit: unit)
    }

    init(amount: Int64, unit: QuantityUnit) throws {
        guard amount >= 0 else { throw QuantityError.invalidAmount }
        let result = amount.multipliedReportingOverflow(by: unit.multiplier)
        guard !result.overflow else { throw QuantityError.overflow }
        canonicalAmount = result.partialValue
        self.unit = unit.canonicalUnit
    }

    func adding(_ other: Quantity) throws -> Quantity {
        guard unit == other.unit else { throw QuantityError.incompatibleUnits }
        let sum = canonicalAmount.addingReportingOverflow(other.canonicalAmount)
        guard !sum.overflow else { throw QuantityError.overflow }
        return try Quantity(amount: sum.partialValue, unit: unit)
    }
}
