import Foundation

enum CartCalculator {
    static func scaledAmount(_ requirement: RecipeRequirement, recipe: Recipe, profile: PlanningProfile) throws -> Int64 {
        guard recipe.baseAdultPortions > 0, recipe.baseAdultPortions <= 12 else { throw PlanningError.invalidPlan }
        let product = requirement.quantity.multipliedReportingOverflow(by: Int64(profile.adultHalfPortions))
        guard !product.overflow else { throw PlanningError.overflow }
        let denominator = Int64(recipe.baseAdultPortions) * 2
        return product.partialValue / denominator + (product.partialValue % denominator == 0 ? 0 : 1)
    }

    static func calculate(meals: [ScheduledMeal], profile: PlanningProfile, catalog: RecipeCatalog, resources: PlanResources? = nil,
                          offerOverrides: [String: String]? = nil, at date: Date = .distantPast, applyPantry: Bool = true) throws -> [CartItem] {
        let forecast = try StockAccounting.forecast(meals: meals, profile: profile, catalog: catalog, resources: resources, at: date, applyPantry: applyPantry)
        let ids = Set(Array(forecast.total.keys) + (resources?.purchases.map(\.ingredientID) ?? []) + (resources?.pantryCredits?.map(\.ingredientID) ?? []))
        return try ids.sorted().map { id in
            guard let ingredient = catalog.ingredients.first(where: { $0.id == id }) else { throw PlanningError.missingIngredient }
            let quantity = try Quantity(amount: forecast.net[id] ?? 0, unit: ingredient.unit)
            let offers = catalog.offers.filter { $0.ingredientID == id && $0.storeID == profile.storeID && (offerOverrides?[id] == nil || offerOverrides?[id] == $0.id) }
            var best: (offer: PackageOffer, cost: Int64)?
            for offer in offers.sorted(by: { $0.id < $1.id }) {
                let cost = try offer.purchaseCost(for: quantity).minorUnits
                if best == nil || cost < best!.cost { best = (offer, cost) }
            }
            guard let best else { throw PlanningError.missingIngredient }
            return try CartItem(ingredientID: id, offerID: best.offer.id, requiredQuantity: forecast.total[id] ?? 0,
                                packageCount: best.offer.packageCount(for: quantity), costMinorUnits: best.cost)
        }
    }

    static func total(_ cart: [CartItem]) throws -> Int64 {
        try cart.reduce(Int64(0)) { sum, item in
            guard item.costMinorUnits >= 0 else { throw PlanningError.invalidPlan }
            let result = sum.addingReportingOverflow(item.costMinorUnits)
            guard !result.overflow else { throw PlanningError.overflow }
            return result.partialValue
        }
    }
}
