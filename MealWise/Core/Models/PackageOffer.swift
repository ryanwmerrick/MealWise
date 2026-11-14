import Foundation

struct PackageOffer: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let ingredientID: String
    let storeID: String
    let packageQuantity: Int64
    let unit: QuantityUnit
    let priceMinorUnits: Int64
    let currencyCode: String
    let priceDate: String
    let validThrough: String
    let provenance: String
    let reviewStatus: ContentReview

    func packageCount(for requirement: Quantity) throws -> Int64 {
        let package = try Quantity(amount: packageQuantity, unit: unit)
        guard package.canonicalAmount > 0 else { throw QuantityError.invalidAmount }
        guard package.unit == requirement.unit else { throw QuantityError.incompatibleUnits }
        let count = requirement.canonicalAmount / package.canonicalAmount
        return count + (requirement.canonicalAmount % package.canonicalAmount == 0 ? 0 : 1)
    }

    func purchaseCost(for requirement: Quantity) throws -> Money {
        try Money(minorUnits: priceMinorUnits, currencyCode: currencyCode).multiplied(by: packageCount(for: requirement))
    }
}
