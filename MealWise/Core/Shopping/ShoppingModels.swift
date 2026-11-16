import Foundation

struct ShoppingLine: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let ingredientID: String
    let offerID: String
    let name: String
    let packageCount: Int64
    let packageQuantity: Int64
    let unit: QuantityUnit
    let estimatedMinorUnits: Int64
    var actualMinorUnits: Int64?
    var checked: Bool
}

struct ShoppingTrip: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let planID: UUID
    let planRevision: UUID
    let storeID: String
    let budgetMinorUnits: Int64
    let priorSpendingMinorUnits: Int64
    var lines: [ShoppingLine]
    var finishedAt: Date?

    var projectedMinorUnits: Int64 { get throws {
        try lines.reduce(priorSpendingMinorUnits) { try checkedSum($0, $1.actualMinorUnits ?? $1.estimatedMinorUnits) }
    } }
    var actualToDateMinorUnits: Int64 { get throws {
        try lines.filter(\.checked).reduce(0) { try checkedSum($0, $1.actualMinorUnits ?? 0) }
    } }
    var remainingMinorUnits: Int64 { get throws { budgetMinorUnits - (try projectedMinorUnits) } }
}

struct ShoppingSummary: Codable, Equatable, Sendable, Identifiable {
    let trip: ShoppingTrip
    var id: UUID { trip.id }
    var purchasedCount: Int { trip.lines.filter(\.checked).count }
    var missingPriceCount: Int { trip.lines.filter { $0.checked && $0.actualMinorUnits == nil }.count }
    var unpurchasedCount: Int { trip.lines.filter { !$0.checked }.count }
    var knownActualMinorUnits: Int64 { get throws { try trip.actualToDateMinorUnits } }
}

struct PurchasedStock: Codable, Equatable, Sendable {
    let tripID: UUID
    let ingredientID: String
    let offerID: String
    let quantity: Int64
    let packageCount: Int64
    let actualMinorUnits: Int64?
    let estimatedMinorUnits: Int64
}

struct PlanResources: Codable, Equatable, Sendable {
    var purchases: [PurchasedStock] = []
    var cookedMeals: [CookedMealRecord]? = nil
    var pantryCredits: [PantryCredit]? = nil
    var committedMinorUnits: Int64 { purchases.reduce(0) { $0 + ($1.actualMinorUnits ?? $1.estimatedMinorUnits) } }
    var knownActualMinorUnits: Int64 { purchases.reduce(0) { $0 + ($1.actualMinorUnits ?? 0) } }
    var missingPriceCount: Int { purchases.filter { $0.actualMinorUnits == nil }.count }
    func quantity(for id: String) -> Int64 { purchases.filter { $0.ingredientID == id }.reduce(0) { $0 + $1.quantity } }
    func validate(catalog: RecipeCatalog) throws {
        guard Set((cookedMeals ?? []).map(\.id)).count == (cookedMeals ?? []).count else { throw PlanningError.invalidPlan }
        var quantities: [String: Int64] = [:]
        var spending: Int64 = 0
        for purchase in purchases {
            guard let offer = catalog.offers.first(where: { $0.id == purchase.offerID }),
                  offer.ingredientID == purchase.ingredientID, purchase.packageCount > 0,
                  purchase.estimatedMinorUnits >= 0, purchase.actualMinorUnits.map({ $0 >= 0 }) ?? true else { throw PlanningError.invalidPlan }
            let product = purchase.packageCount.multipliedReportingOverflow(by: offer.packageQuantity)
            guard !product.overflow, product.partialValue == purchase.quantity else { throw PlanningError.invalidPlan }
            quantities[purchase.ingredientID] = try checkedSum(quantities[purchase.ingredientID] ?? 0, purchase.quantity)
            spending = try checkedSum(spending, purchase.actualMinorUnits ?? purchase.estimatedMinorUnits)
        }
        let credits = pantryCredits ?? []
        guard Set(credits.map(\.id)).count == credits.count else { throw PlanningError.invalidPlan }
        var usedCredits: [UUID: Int64] = [:]
        for credit in credits {
            guard credit.originalQuantity > 0, credit.remainingQuantity >= 0, credit.remainingQuantity <= credit.originalQuantity,
                  catalog.ingredients.contains(where: { $0.id == credit.ingredientID && $0.unit == credit.unit }) else { throw PantryError.invalidQuantity }
        }
        for record in cookedMeals ?? [] {
            try record.profile.validate()
            guard record.recipe == catalog.recipes.first(where: { $0.id == record.meal.recipeID }) else { throw PlanningError.invalidPlan }
            let debits = try StockAccounting.debits(record)
            var totals: [String: Int64] = [:]
            for debit in debits {
                guard debit.quantity > 0, debit.expiryAtUse.map({ $0 >= record.completedAt }) ?? true else { throw PantryError.invalidQuantity }
                totals[debit.ingredientID] = try checkedSum(totals[debit.ingredientID] ?? 0, debit.quantity)
                if let source = debit.pantryItemID {
                    guard credits.contains(where: { $0.id == source && $0.ingredientID == debit.ingredientID }) else { throw PantryError.invalidQuantity }
                    usedCredits[source] = try checkedSum(usedCredits[source] ?? 0, debit.quantity)
                }
            }
            guard totals.count == record.recipe.ingredients.count else { throw PlanningError.invalidPlan }
            for requirement in record.recipe.ingredients {
                guard totals[requirement.ingredientID] == (try CartCalculator.scaledAmount(requirement, recipe: record.recipe, profile: record.profile)) else { throw PlanningError.invalidPlan }
            }
        }
        for credit in credits {
            guard try checkedSum(credit.remainingQuantity, usedCredits[credit.id] ?? 0) <= credit.originalQuantity else { throw PantryError.invalidQuantity }
        }
        _ = try StockAccounting.purchasedRemaining(self)
    }
}

func checkedSum(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
    guard lhs >= 0, rhs >= 0 else { throw MoneyError.invalidAmount }
    let result = lhs.addingReportingOverflow(rhs)
    guard !result.overflow else { throw MoneyError.overflow }
    return result.partialValue
}

enum ShoppingError: Error { case missingTrip, staleTrip, finishedTrip, invalidItem, noPurchases }
