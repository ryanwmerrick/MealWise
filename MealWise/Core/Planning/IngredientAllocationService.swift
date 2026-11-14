import Foundation

enum AllocationStatus: Sendable { case fullyUsed, carryOver, needsAttention }

struct MealAllocation: Sendable, Identifiable {
    let mealID: UUID
    let date: Date
    let slot: MealSlot
    let recipeTitle: String
    let quantity: Int64
    var id: UUID { mealID }
}

struct IngredientAllocation: Sendable, Identifiable {
    let id: String
    let name: String
    let unit: QuantityUnit
    let purchasedQuantity: Int64
    let remainingQuantity: Int64
    let packageCount: Int64
    let priceMinorUnits: Int64
    let allocations: [MealAllocation]
    let status: AllocationStatus
    let storage: StorageKind?

    var usedQuantity: Int64 { purchasedQuantity - remainingQuantity }
}

struct ReservationNote: Sendable, Identifiable {
    let id: String
    let name: String
    let quantity: Int64
    let unit: QuantityUnit
    let mealCount: Int
}

struct IngredientAllocationReport: Sendable {
    let items: [IngredientAllocation]

    func reservations(after meal: ScheduledMeal) -> [ReservationNote] {
        items.compactMap { item in
            let later = item.allocations.filter {
                $0.date > meal.date || ($0.date == meal.date && $0.slot.order > meal.slot.order)
            }
            guard item.allocations.contains(where: { $0.mealID == meal.id }), !later.isEmpty else { return nil }
            // The service already checked that the full allocation sum fits in Int64.
            return ReservationNote(id: item.id, name: item.name, quantity: later.reduce(0) { $0 + $1.quantity },
                                   unit: item.unit, mealCount: later.count)
        }
    }
}

protocol IngredientAllocationServiceProtocol: Sendable {
    func allocate(plan: WeeklyPlan) throws -> IngredientAllocationReport
}

struct IngredientAllocationService: IngredientAllocationServiceProtocol {
    func allocate(plan: WeeklyPlan) throws -> IngredientAllocationReport {
        try PlanValidation.validate(plan)
        let ordered = plan.meals.sorted { $0.date == $1.date ? $0.slot.order < $1.slot.order : $0.date < $1.date }
        let items = try plan.cart.map { cart in
            guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == cart.ingredientID }),
                  let offer = plan.catalog.offers.first(where: { $0.id == cart.offerID }) else { throw PlanningError.missingIngredient }
            let purchased = cart.packageCount.multipliedReportingOverflow(by: offer.packageQuantity)
            guard !purchased.overflow else { throw PlanningError.overflow }
            let allocations = try ordered.compactMap { meal -> MealAllocation? in
                guard let recipe = plan.catalog.recipes.first(where: { $0.id == meal.recipeID }),
                      let requirement = recipe.ingredients.first(where: { $0.ingredientID == ingredient.id }) else { return nil }
                guard requirement.unit == ingredient.unit else { throw QuantityError.incompatibleUnits }
                return try MealAllocation(mealID: meal.id, date: meal.date, slot: meal.slot, recipeTitle: recipe.title,
                                          quantity: CartCalculator.scaledAmount(requirement, recipe: recipe, profile: plan.profile))
            }
            let allocated = try allocations.reduce(Int64(0)) { sum, allocation in
                let next = sum.addingReportingOverflow(allocation.quantity)
                guard !next.overflow else { throw PlanningError.overflow }
                return next.partialValue
            }
            guard allocated == cart.requiredQuantity, purchased.partialValue >= allocated else { throw PlanningError.invalidPlan }
            let remaining = purchased.partialValue - allocated
            let status: AllocationStatus = remaining == 0 ? .fullyUsed : (ingredient.storage == .shelfStable ? .carryOver : .needsAttention)
            return IngredientAllocation(id: ingredient.id, name: ingredient.name, unit: ingredient.unit,
                                        purchasedQuantity: purchased.partialValue, remainingQuantity: remaining,
                                        packageCount: cart.packageCount, priceMinorUnits: cart.costMinorUnits,
                                        allocations: allocations, status: status, storage: ingredient.storage)
        }
        return IngredientAllocationReport(items: items)
    }
}

extension MealSlot {
    var order: Int {
        switch self { case .breakfast: 0; case .lunch: 1; case .dinner: 2 }
    }
}
