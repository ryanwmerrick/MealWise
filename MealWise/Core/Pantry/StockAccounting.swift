import Foundation

struct StockDemand: Sendable {
    let ingredientID: String
    let quantity: Int64
    let date: Date
}

struct StockForecast: Sendable {
    var total: [String: Int64] = [:]
    var net: [String: Int64] = [:]
    var creditUse: [UUID: Int64] = [:]
}

enum StockAccounting {
    static func debits(_ record: CookedMealRecord) throws -> [StockDebit] {
        if let debits = record.stockDebits { return debits }
        return try record.recipe.ingredients.map {
            StockDebit(ingredientID: $0.ingredientID, quantity: try CartCalculator.scaledAmount($0, recipe: record.recipe, profile: record.profile), pantryItemID: nil, expiryAtUse: nil)
        }
    }

    static func purchasedRemaining(_ resources: PlanResources) throws -> [String: Int64] {
        var result: [String: Int64] = [:]
        for purchase in resources.purchases { result[purchase.ingredientID] = try checkedSum(result[purchase.ingredientID] ?? 0, purchase.quantity) }
        for record in resources.cookedMeals ?? [] {
            for debit in try debits(record) where debit.pantryItemID == nil {
                guard (result[debit.ingredientID] ?? 0) >= debit.quantity else { throw CookingError.insufficientStock }
                result[debit.ingredientID, default: 0] -= debit.quantity
            }
        }
        for (ingredient, quantity) in resources.usedOutsidePlan ?? [:] {
            guard quantity > 0, quantity <= result[ingredient, default: 0] else { throw PantryError.invalidQuantity }
            result[ingredient, default: 0] -= quantity
        }
        return result
    }

    static func forecast(meals: [ScheduledMeal], profile: PlanningProfile, catalog: RecipeCatalog, resources: PlanResources?,
                         at date: Date, applyPantry: Bool = true) throws -> StockForecast {
        let resources = resources ?? PlanResources()
        try resources.validate(catalog: catalog)
        var output = StockForecast()
        var demands: [StockDemand] = []
        for meal in meals {
            guard let recipe = catalog.recipes.first(where: { $0.id == meal.recipeID }) else { throw PlanningError.invalidPlan }
            let cooked = resources.cookedMeals?.first { $0.id == meal.id }
            for requirement in recipe.ingredients {
                let amount = try CartCalculator.scaledAmount(requirement, recipe: recipe, profile: cooked?.profile ?? profile)
                output.total[requirement.ingredientID] = try checkedSum(output.total[requirement.ingredientID] ?? 0, amount)
                if cooked == nil { demands.append(StockDemand(ingredientID: requirement.ingredientID, quantity: amount, date: max(date, meal.date))) }
            }
            if !applyPantry, let cooked {
                for debit in try debits(cooked) where debit.pantryItemID != nil {
                    demands.append(StockDemand(ingredientID: debit.ingredientID, quantity: debit.quantity, date: cooked.completedAt))
                }
            }
        }
        var purchased = try purchasedRemaining(resources)
        var credits = resources.pantryCredits ?? []
        credits.sort { ($0.expiry ?? .distantFuture) < ($1.expiry ?? .distantFuture) }
        for demand in demands.sorted(by: { $0.date < $1.date }) {
            var needed = demand.quantity
            if applyPantry {
                for index in credits.indices where credits[index].ingredientID == demand.ingredientID && credits[index].availabilityConfirmed &&
                    (credits[index].expiry.map { $0 >= demand.date } ?? true) {
                    let used = min(needed, credits[index].remainingQuantity)
                    needed -= used; credits[index].remainingQuantity -= used
                    output.creditUse[credits[index].id] = try checkedSum(output.creditUse[credits[index].id] ?? 0, used)
                }
            }
            let bought = min(needed, purchased[demand.ingredientID] ?? 0)
            purchased[demand.ingredientID, default: 0] -= bought; needed -= bought
            output.net[demand.ingredientID] = try checkedSum(output.net[demand.ingredientID] ?? 0, needed)
        }
        return output
    }

    static func allocateConsumption(recipe: Recipe, profile: PlanningProfile, resources: PlanResources, at date: Date) throws -> (PlanResources, [StockDebit]) {
        var resources = resources
        var credits = resources.pantryCredits ?? []
        let order = credits.indices.sorted { (credits[$0].expiry ?? .distantFuture) < (credits[$1].expiry ?? .distantFuture) }
        var purchased = try purchasedRemaining(resources)
        var debits: [StockDebit] = []
        for requirement in recipe.ingredients {
            var needed = try CartCalculator.scaledAmount(requirement, recipe: recipe, profile: profile)
            for index in order where credits[index].ingredientID == requirement.ingredientID && credits[index].availabilityConfirmed &&
                (credits[index].expiry.map { $0 >= date } ?? true) {
                let used = min(needed, credits[index].remainingQuantity)
                if used > 0 {
                    debits.append(StockDebit(ingredientID: requirement.ingredientID, quantity: used, pantryItemID: credits[index].id, expiryAtUse: credits[index].expiry))
                    credits[index].remainingQuantity -= used; needed -= used
                }
            }
            if needed > 0 {
                guard (purchased[requirement.ingredientID] ?? 0) >= needed else { throw CookingError.insufficientStock }
                purchased[requirement.ingredientID, default: 0] -= needed
                debits.append(StockDebit(ingredientID: requirement.ingredientID, quantity: needed, pantryItemID: nil, expiryAtUse: nil))
            }
        }
        if resources.pantryCredits != nil { resources.pantryCredits = credits }
        return (resources, debits)
    }

    static func sources(plan: WeeklyPlan) throws -> [CarryoverSource] {
        let resources = plan.resources ?? PlanResources()
        var sources: [CarryoverSource] = []
        for (id, quantity) in try purchasedRemaining(resources) where quantity > 0 {
            guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == id }) else { throw PlanningError.missingIngredient }
            sources.append(CarryoverSource(id: "purchase-" + id, ingredientID: id, quantity: quantity, unit: ingredient.unit,
                                           storage: ingredient.storage, expiry: nil, pantryItemID: nil))
        }
        for credit in resources.pantryCredits ?? [] where credit.remainingQuantity > 0 {
            sources.append(CarryoverSource(id: "pantry-" + credit.id.uuidString, ingredientID: credit.ingredientID,
                                           quantity: credit.remainingQuantity, unit: credit.unit, storage: credit.storage, expiry: credit.expiry, pantryItemID: credit.id))
        }
        return sources.sorted { $0.id < $1.id }
    }

    static func receivedQuantity(resources: PlanResources?, ingredientID: String, at date: Date) throws -> Int64 {
        guard let resources else { return 0 }
        var quantity = try purchasedRemaining(resources)[ingredientID] ?? 0
        for record in resources.cookedMeals ?? [] {
            for debit in try debits(record) where debit.ingredientID == ingredientID { quantity = try checkedSum(quantity, debit.quantity) }
        }
        for credit in resources.pantryCredits ?? [] where credit.ingredientID == ingredientID && credit.availabilityConfirmed && (credit.expiry.map { $0 >= date } ?? true) {
            quantity = try checkedSum(quantity, credit.remainingQuantity)
        }
        return quantity
    }
}

enum PantrySavings {
    static func estimate(plan: WeeklyPlan) throws -> Int64 {
        let without = try CartCalculator.calculate(meals: plan.meals, profile: plan.profile, catalog: plan.catalog,
                                                   resources: plan.resources, offerOverrides: plan.offerOverrides, at: plan.pricedAt ?? .distantPast, applyPantry: false)
        return max(0, try CartCalculator.total(without) - CartCalculator.total(plan.cart))
    }
}
