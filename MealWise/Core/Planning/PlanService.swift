import Foundation

actor PlanService: PlanServiceProtocol {
    private let nodeLimit: Int
    private let clock: @Sendable () -> Date
    init(nodeLimit: Int = 20000, clock: @escaping @Sendable () -> Date = { .now }) {
        self.nodeLimit = nodeLimit
        self.clock = clock
    }

    func generate(_ input: PlanRequest) async throws -> PlanOutcome {
        let now = clock()
        var resources = input.resources
        if !input.confirmedStock.isEmpty {
            guard resources == nil else { return .invalidInputs }
            var credits: [PantryCredit] = []
            for item in input.confirmedStock {
                try item.validate(catalog: input.catalog)
                if item.availabilityConfirmed, item.availableQuantity > 0, item.expiry.map({ $0 >= now }) ?? true {
                    credits.append(PantryCredit(id: item.id, ingredientID: item.ingredientID, unit: item.unit, sourceRevision: item.revision,
                                                originalQuantity: item.availableQuantity, remainingQuantity: item.availableQuantity,
                                                storage: item.storage, expiry: item.expiry, availabilityConfirmed: true))
                }
            }
            resources = PlanResources(pantryCredits: credits)
        }
        let request = PlanRequest(profile: input.profile, catalog: input.catalog, excludedRecipeIDs: input.excludedRecipeIDs,
                                  fixedMeals: input.fixedMeals, avoidMeals: input.avoidMeals, resources: resources, offerOverrides: input.offerOverrides)
        try Task.checkCancellation()
        do { try request.profile.validate() } catch { return .invalidInputs }
        do {
            try CatalogValidator.validate(request.catalog, allowDevelopment: true, now: clock())
        } catch { return .invalidInputs }
        let slots = request.profile.days.sorted().flatMap { day in
            MealSlot.allCases.filter { request.profile.mealSlots.contains($0) }.map { (day, $0) }
        }
        for fixed in request.fixedMeals {
            guard slots.contains(where: { $0.0 == fixed.date && $0.1 == fixed.slot }),
                  request.fixedMeals.filter({ $0.date == fixed.date && $0.slot == fixed.slot }).count == 1 else { return .invalidInputs }
        }
        let candidates = slots.map { day, slot in
            let fixed = request.fixedMeals.first { $0.date == day && $0.slot == slot }
            let avoid = request.avoidMeals.first { $0.date == day && $0.slot == slot }?.recipeID
            return request.catalog.recipes.filter {
                (request.resources?.cookedMeals?.contains(where: { $0.id == fixed?.id && $0.recipe.id == $0.meal.recipeID }) == true || Self.isEligible($0, slot: slot, profile: request.profile, catalog: request.catalog)) &&
                (fixed == nil ? !request.excludedRecipeIDs.contains($0.id) : $0.id == fixed?.recipeID)
            }.sorted {
                if ($0.id == avoid) != ($1.id == avoid) { return $1.id == avoid }
                return $0.id < $1.id
            }
        }
        guard candidates.allSatisfy({ !$0.isEmpty }) else { return .noFeasiblePlan }
        var search = PlanSearch(request: request, pricedAt: now, slots: slots, candidates: candidates, limit: nodeLimit)
        try search.visit([])
        guard let best = search.best else { return search.limitReached ? .searchLimit : .noFeasiblePlan }
        var finalResources = request.resources
        if !input.confirmedStock.isEmpty, var current = finalResources {
            let forecast = try StockAccounting.forecast(meals: best.meals, profile: request.profile, catalog: request.catalog, resources: current, at: now)
            current.pantryCredits = current.pantryCredits?.compactMap { credit in
                guard let used = forecast.creditUse[credit.id], used > 0 else { return nil }
                return PantryCredit(id: credit.id, ingredientID: credit.ingredientID, unit: credit.unit, sourceRevision: credit.sourceRevision,
                                    originalQuantity: used, remainingQuantity: used, storage: credit.storage, expiry: credit.expiry, availabilityConfirmed: true)
            }
            finalResources = current
        }
        let finalCart = try CartCalculator.calculate(CartRequest(meals: best.meals, profile: request.profile, catalog: request.catalog,
                                                                resources: finalResources, offerOverrides: request.offerOverrides, pricedAt: now))
        let plan = WeeklyPlan(id: UUID(), revision: UUID(), profile: request.profile, catalog: request.catalog,
                              meals: best.meals, cart: finalCart.items, totalMinorUnits: finalCart.totalMinorUnits, resources: finalResources,
                              offerOverrides: request.offerOverrides, pricedAt: now)
        try PlanValidation.validate(plan)
        return .feasible(plan)
    }

    static func isEligible(_ recipe: Recipe, slot: MealSlot, profile: PlanningProfile, catalog: RecipeCatalog) -> Bool {
        guard recipe.mealSlots.contains(slot), recipe.minutes <= profile.cookingTime.rawValue else { return false }
        if profile.skill == .beginner && recipe.skill != .beginner { return false }
        if profile.skill == .comfortable && recipe.skill == .experienced { return false }
        let ingredients = recipe.ingredients.compactMap { requirement in catalog.ingredients.first { $0.id == requirement.ingredientID } }
        guard ingredients.count == recipe.ingredients.count,
              ingredients.allSatisfy({ $0.isSafe(excluding: profile.allergies) }) else { return false }
        guard profile.preferences.isSubset(of: recipe.dietaryPreferences) else { return false }
        if profile.preferences.contains(.glutenFree) {
            guard ingredients.allSatisfy({ $0.allergensVerified && !$0.allergens.contains(.wheat) }) else { return false }
        }
        return true
    }
}

private struct PlanSearch {
    let request: PlanRequest
    let pricedAt: Date
    let slots: [(Date, MealSlot)]
    let candidates: [[Recipe]]
    let limit: Int
    var nodes = 0
    var limitReached = false
    var best: (meals: [ScheduledMeal], cart: [CartItem], cost: Int64, repeats: Int, unchanged: Int, waste: Decimal)?

    mutating func visit(_ meals: [ScheduledMeal]) throws {
        try Task.checkCancellation()
        guard nodes < limit else { limitReached = true; return }
        nodes += 1
        let priced = try CartCalculator.calculate(CartRequest(meals: meals, profile: request.profile, catalog: request.catalog, resources: request.resources, offerOverrides: request.offerOverrides, pricedAt: pricedAt))
        let cart = priced.items
        let cost = priced.totalMinorUnits
        guard cost <= request.profile.budgetMinorUnits else { return }
        if meals.count == slots.count {
            let repeats = meals.count - Set(meals.map(\.recipeID)).count
            let unchanged = meals.filter { meal in
                request.avoidMeals.contains { $0.date == meal.date && $0.slot == meal.slot && $0.recipeID == meal.recipeID }
            }.count
            let waste = try unusedPackageValue(cart, meals: meals)
            if best == nil || unchanged < best!.unchanged ||
                (unchanged == best!.unchanged && repeats < best!.repeats) ||
                (repeats == best!.repeats && unchanged == best!.unchanged && cost < best!.cost) ||
                (repeats == best!.repeats && unchanged == best!.unchanged && cost == best!.cost && waste < best!.waste) {
                best = (meals, cart, cost, repeats, unchanged, waste)
            }
            return
        }
        let index = meals.count
        for recipe in candidates[index] {
            guard !limitReached else { break }
            let meal = request.fixedMeals.first { $0.date == slots[index].0 && $0.slot == slots[index].1 } ??
                ScheduledMeal(id: UUID(), date: slots[index].0, slot: slots[index].1, recipeID: recipe.id)
            try visit(meals + [meal])
        }
    }

    private func unusedPackageValue(_ cart: [CartItem], meals: [ScheduledMeal]) throws -> Decimal {
        let net = try StockAccounting.forecast(meals: meals, profile: request.profile, catalog: request.catalog, resources: request.resources, at: pricedAt).net
        return cart.reduce(Decimal(0)) { sum, item in
            guard let offer = request.catalog.offers.first(where: { $0.id == item.offerID }) else { return sum }
            let purchased = Decimal(item.packageCount) * Decimal(offer.packageQuantity)
            guard purchased > 0 else { return sum }
            return sum + Decimal(item.costMinorUnits) * (purchased - Decimal(net[item.id] ?? 0)) / purchased
        }
    }
}

enum PlanValidation {
    static func validate(_ plan: WeeklyPlan) throws {
        try CatalogValidator.validate(plan.catalog, allowDevelopment: true, now: .now, validatePriceFreshness: false)
        try plan.profile.validate()
        guard plan.meals.count == plan.profile.days.count * plan.profile.mealSlots.count,
              Set(plan.meals.map(\.id)).count == plan.meals.count else { throw PlanningError.invalidPlan }
        for record in plan.resources?.cookedMeals ?? [] {
            guard plan.meals.contains(record.meal) else { throw PlanningError.invalidPlan }
        }
        for day in plan.profile.days {
            for slot in plan.profile.mealSlots {
                let matches = plan.meals.filter { $0.date == day && $0.slot == slot }
                guard matches.count == 1,
                      let recipe = plan.catalog.recipes.first(where: { $0.id == matches[0].recipeID }),
                      (plan.cookedRecord(for: matches[0].id) != nil || PlanService.isEligible(recipe, slot: slot, profile: plan.profile, catalog: plan.catalog)) else {
                    throw PlanningError.invalidPlan
                }
            }
        }
        let cart = try CartCalculator.calculate(meals: plan.meals, profile: plan.profile, catalog: plan.catalog, resources: plan.resources, offerOverrides: plan.offerOverrides, at: plan.pricedAt ?? .distantPast)
        let total = try checkedSum(CartCalculator.total(cart), plan.resources?.committedMinorUnits ?? 0)
        guard cart == plan.cart, total == plan.totalMinorUnits, (total <= plan.profile.budgetMinorUnits || plan.resources?.purchases.isEmpty == false || plan.reviewRequired == true) else {
            throw PlanningError.invalidPlan
        }
    }
}
