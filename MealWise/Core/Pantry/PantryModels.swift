import Foundation

struct PantryItem: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let ingredientID: String
    var quantity: Int64
    let unit: QuantityUnit
    var storage: StorageKind?
    var expiry: Date?
    var availabilityConfirmed: Bool
    var revision: UUID
    var reservations: [String: Int64] = [:]
    var availableQuantity: Int64 { quantity - reservations.values.reduce(0, +) }
    func validate(catalog: RecipeCatalog) throws {
        guard quantity >= 0, let ingredient = catalog.ingredients.first(where: { $0.id == ingredientID }), ingredient.unit == unit else { throw PantryError.invalidQuantity }
        let reserved = try reservations.values.reduce(Int64(0), checkedSum)
        guard reserved <= quantity else { throw PantryError.invalidQuantity }
    }
}

struct PantryCredit: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let ingredientID: String
    let unit: QuantityUnit
    let sourceRevision: UUID
    let originalQuantity: Int64
    var remainingQuantity: Int64
    var storage: StorageKind?
    var expiry: Date?
    var availabilityConfirmed: Bool
}

struct StockDebit: Codable, Equatable, Sendable {
    let ingredientID: String
    let quantity: Int64
    let pantryItemID: UUID?
    let expiryAtUse: Date?
}

struct CarryoverSource: Sendable, Identifiable {
    let id: String
    let ingredientID: String
    let quantity: Int64
    let unit: QuantityUnit
    let storage: StorageKind?
    let expiry: Date?
    let pantryItemID: UUID?
}

struct CarryoverLine: Codable, Equatable, Sendable {
    let sourceID: String
    let quantity: Int64
    let storage: StorageKind?
    let expiry: Date?
    let availabilityConfirmed: Bool
}

struct CarryoverConfirmation: Codable, Equatable, Sendable {
    let planID: UUID
    let expectedRevision: UUID
    let items: [CarryoverLine]
}

struct CycleHistory: Codable, Equatable, Sendable, Identifiable {
    let plan: WeeklyPlan
    let completedAt: Date
    let confirmation: CarryoverConfirmation
    var id: UUID { plan.id }
}

struct WrapUpReport: Sendable {
    let plan: WeeklyPlan
    let sources: [CarryoverSource]
    let forecast: IngredientAllocationReport
    var knownActualMinorUnits: Int64 { plan.resources?.knownActualMinorUnits ?? 0 }
    var missingPriceCount: Int { plan.resources?.missingPriceCount ?? 0 }
    static func make(plan: WeeklyPlan) throws -> WrapUpReport {
        try PlanValidation.validate(plan)
        return try WrapUpReport(plan: plan, sources: StockAccounting.sources(plan: plan), forecast: IngredientAllocationService().allocate(plan: plan))
    }
}

enum PantryError: Error, Equatable { case invalidQuantity, unconfirmedStock, staleStock, cycleClosed, activeCycle, invalidConfirmation }
