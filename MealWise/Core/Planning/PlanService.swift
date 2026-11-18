import Foundation
import OSLog

actor PlanService: PlanServiceProtocol {
    private static let logger = Logger(subsystem: "ryanmerrick.MealWise", category: "Planning")
    private let nodeLimit: Int
    private let clock: @Sendable () -> Date
    private let menuProposer: (any MenuProposing)?

    init(nodeLimit: Int = 20000, menuProposer: (any MenuProposing)? = nil, clock: @escaping @Sendable () -> Date = { .now }) {
        self.nodeLimit = nodeLimit
        self.menuProposer = menuProposer
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
                                  fixedMeals: input.fixedMeals, avoidMeals: input.avoidMeals, resources: resources, offerOverrides: input.offerOverrides,
                                  recipePreferences: input.recipePreferences, pins: input.pins, allowsMenuProposals: input.allowsMenuProposals)
        try Task.checkCancellation()
        do { try request.profile.validate() } catch { return .invalidInputs }
        do {
            try CatalogValidator.validate(request.catalog, allowDevelopment: true, now: now)
        } catch { return .invalidInputs }
        let slots = request.profile.days.sorted().flatMap { day in
            MealSlot.allCases.filter { request.profile.mealSlots.contains($0) }.map { (day, $0) }
        }
        guard Set(request.recipePreferences.map(\.recipeID)).count == request.recipePreferences.count,
              Set(request.pins.map(\.id)).count == request.pins.count,
              request.pins.allSatisfy({ pin in slots.contains { $0.0 == pin.date && $0.1 == pin.slot } }) else { return .invalidInputs }
        for fixed in request.fixedMeals {
            guard slots.contains(where: { $0.0 == fixed.date && $0.1 == fixed.slot }),
                  request.fixedMeals.filter({ $0.date == fixed.date && $0.slot == fixed.slot }).count == 1 else { return .invalidInputs }
        }
        let preferences = Dictionary(uniqueKeysWithValues: request.recipePreferences.map { ($0.recipeID, $0) })
        let scores = Dictionary(uniqueKeysWithValues: request.catalog.recipes.map { recipe in
            let saved = preferences[recipe.id]
            let discovery = request.profile.onboarding?.goals.contains(.findRecipes) == true && saved == nil ? 1 : 0
            return (recipe.id, (saved?.score ?? 0) + (request.profile.onboarding?.score(recipe) ?? 0) + discovery)
        })
        let candidates = slots.map { day, slot in
            let fixed = request.fixedMeals.first { $0.date == day && $0.slot == slot }
            let avoid = request.avoidMeals.first { $0.date == day && $0.slot == slot }?.recipeID
            let pin = request.pins.first { $0.date == day && $0.slot == slot }
            return request.catalog.recipes.filter { recipe in
                let cooked = request.resources?.cookedMeals?.contains { $0.id == fixed?.id && $0.recipe.id == recipe.id } == true
                let excluded = request.excludedRecipeIDs.contains(recipe.id) || preferences[recipe.id]?.excluded == true
                return (cooked || Self.isEligible(recipe, slot: slot, profile: request.profile, catalog: request.catalog)) &&
                    (fixed == nil ? !excluded : recipe.id == fixed?.recipeID) &&
                    (pin == nil || (recipe.id == pin?.recipeID && !excluded))
            }.sorted { left, right in
                if (left.id == avoid) != (right.id == avoid) { return right.id == avoid }
                if request.profile.requiresMeat && (left.containsMeat == true) != (right.containsMeat == true) {
                    return left.containsMeat == true
                }
                let leftScore = scores[left.id] ?? 0
                let rightScore = scores[right.id] ?? 0
                if leftScore != rightScore { return leftScore > rightScore }
                return left.id < right.id
            }
        }
        guard candidates.allSatisfy({ !$0.isEmpty }) else { return .noFeasiblePlan }
        let lastMeatSlot = candidates.lastIndex { $0.contains { $0.containsMeat == true } }
        guard !request.profile.requiresMeat || lastMeatSlot != nil else { return .noFeasiblePlan }
        var search = PlanSearch(request: request, pricedAt: now, slots: slots, candidates: candidates, preferenceScores: scores, limit: nodeLimit,
                                lastRequiredMeatSlot: request.profile.requiresMeat ? lastMeatSlot : nil)
        let selectedMeals: [ScheduledMeal]
        if let proposedMeals = try await proposeMeals(using: &search) {
            selectedMeals = proposedMeals
        } else {
            Self.logger.notice("Using the local meal planner")
            try search.visit([])
            guard let best = search.best else { return search.limitReached ? .searchLimit : .noFeasiblePlan }
            selectedMeals = best.meals
        }
        var finalResources = request.resources
        if !input.confirmedStock.isEmpty, var current = finalResources {
            let forecast = try StockAccounting.forecast(meals: selectedMeals, profile: request.profile, catalog: request.catalog, resources: current, at: now)
            current.pantryCredits = current.pantryCredits?.compactMap { credit in
                guard let used = forecast.creditUse[credit.id], used > 0 else { return nil }
                return PantryCredit(id: credit.id, ingredientID: credit.ingredientID, unit: credit.unit, sourceRevision: credit.sourceRevision,
                                    originalQuantity: used, remainingQuantity: used, storage: credit.storage, expiry: credit.expiry, availabilityConfirmed: true)
            }
            finalResources = current
        }
        let finalCart = try CartCalculator.calculate(CartRequest(meals: selectedMeals, profile: request.profile, catalog: request.catalog,
                                                                resources: finalResources, offerOverrides: request.offerOverrides, pricedAt: now))
        let plan = WeeklyPlan(id: UUID(), revision: UUID(), profile: request.profile, catalog: request.catalog,
                              meals: selectedMeals, cart: finalCart.items, totalMinorUnits: finalCart.totalMinorUnits, resources: finalResources,
                              offerOverrides: request.offerOverrides, pricedAt: now)
        try PlanValidation.validate(plan)
        return .feasible(plan)
    }

    private func proposeMeals(using search: inout PlanSearch) async throws -> [ScheduledMeal]? {
        let request = search.request
        guard request.allowsMenuProposals else { return nil }
        guard let menuProposer else {
            Self.logger.notice("Skipping Gemini: no menu proposer configured")
            return nil
        }
        let slots = search.slots
        let goals = request.profile.onboarding?.goals ?? []
        let rankProposals = search.preferenceScores.values.contains { $0 != 0 } || !goals.isDisjoint(with: [.saveMoney, .wasteLess])
        let fixedBySlot = slots.map { date, slot in request.fixedMeals.first { $0.date == date && $0.slot == slot } }
        let suggestedCandidates = zip(slots, search.candidates).map { slot, recipes in
            let replacements = recipes.filter { recipe in
                !request.avoidMeals.contains { $0.date == slot.0 && $0.slot == slot.1 && $0.recipeID == recipe.id }
            }
            return replacements.isEmpty ? recipes : replacements
        }
        try request.resources?.validate(catalog: request.catalog)

        let menus: [[String]]
        do {
            menus = try await menuProposer.propose(MenuProposalInput(request: request, slots: slots.map { $0.1 },
                                                                    candidates: suggestedCandidates, preferenceScores: search.preferenceScores))
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            Self.logger.notice("Gemini proposal request failed")
            return nil
        }
        try Task.checkCancellation()
        for menu in menus.prefix(3) {
            guard menu.count == slots.count,
                  zip(menu, suggestedCandidates).allSatisfy({ id, recipes in recipes.contains { $0.id == id } }) else { continue }
            if request.profile.requiresMeat && !zip(menu, suggestedCandidates).contains(where: { id, recipes in
                recipes.contains { $0.id == id && $0.containsMeat == true }
            }) { continue }
            let meals = slots.indices.map { index in
                fixedBySlot[index] ?? ScheduledMeal(id: UUID(), date: slots[index].0, slot: slots[index].1, recipeID: menu[index])
            }
            let cart = try CartCalculator.calculate(CartRequest(meals: meals, profile: request.profile, catalog: request.catalog,
                                                                resources: request.resources, offerOverrides: request.offerOverrides, pricedAt: search.pricedAt))
            guard cart.totalMinorUnits <= request.profile.budgetMinorUnits else { continue }
            if !rankProposals {
                Self.logger.notice("Accepted a Gemini menu")
                return meals
            }
            try search.consider(meals, priced: cart)
        }
        if let best = search.best {
            Self.logger.notice("Accepted a Gemini menu after applying planning preferences")
            return best.meals
        }
        Self.logger.notice("No Gemini menu passed local validation")
        return nil
    }

    static func isEligible(_ recipe: Recipe, slot: MealSlot, profile: PlanningProfile, catalog: RecipeCatalog) -> Bool {
        guard recipe.mealSlots.contains(slot), recipe.minutes <= profile.cookingTime.rawValue else { return false }
        if recipe.containsMeat == true && !profile.allowsMeat { return false }
        if let equipment = profile.onboarding?.equipment {
            let available = Set(equipment.union(KitchenEquipment.assumedTools).map(\.rawValue))
            guard Set(recipe.equipment).isSubset(of: available) else { return false }
        }
        if profile.skill == .beginner && recipe.skill != .beginner { return false }
        if profile.skill == .comfortable && recipe.skill == .experienced { return false }
        let ingredients = recipe.ingredients.compactMap { requirement in catalog.ingredients.first { $0.id == requirement.ingredientID } }
        let allowDevelopment = catalog.reviewStatus == .developmentApproved
        guard ingredients.count == recipe.ingredients.count,
              ingredients.allSatisfy({ $0.isSafe(excluding: profile.allergies, allowDevelopment: allowDevelopment) }) else { return false }
        guard profile.preferences.isSubset(of: recipe.dietaryPreferences) else { return false }
        if profile.preferences.contains(.glutenFree) {
            guard ingredients.allSatisfy({ $0.hasAllergenInformation(allowDevelopment: allowDevelopment) && !$0.allergens.contains(.wheat) }) else { return false }
        }
        return true
    }
}

private struct PlanSearch {
    let request: PlanRequest
    let pricedAt: Date
    let slots: [(Date, MealSlot)]
    let candidates: [[Recipe]]
    let preferenceScores: [String: Int]
    let limit: Int
    let lastRequiredMeatSlot: Int?
    var nodes = 0
    var limitReached = false
    var best: (meals: [ScheduledMeal], priority: (Int, Int64, Decimal), rank: (Int, Int, Int64, Decimal))?

    mutating func visit(_ meals: [ScheduledMeal], includesMeat: Bool = false) throws {
        try Task.checkCancellation()
        if let lastRequiredMeatSlot, !includesMeat, meals.count > lastRequiredMeatSlot { return }
        guard nodes < limit else { limitReached = true; return }
        nodes += 1
        let priced = try CartCalculator.calculate(CartRequest(meals: meals, profile: request.profile, catalog: request.catalog, resources: request.resources, offerOverrides: request.offerOverrides, pricedAt: pricedAt))
        guard priced.totalMinorUnits <= request.profile.budgetMinorUnits else { return }
        if meals.count == slots.count {
            try consider(meals, priced: priced)
            return
        }
        let index = meals.count
        for recipe in candidates[index] {
            guard !limitReached else { break }
            let meal = request.fixedMeals.first { $0.date == slots[index].0 && $0.slot == slots[index].1 } ??
                ScheduledMeal(id: UUID(), date: slots[index].0, slot: slots[index].1, recipeID: recipe.id)
            try visit(meals + [meal], includesMeat: includesMeat || recipe.containsMeat == true)
        }
    }

    mutating func consider(_ meals: [ScheduledMeal], priced: PricedCart) throws {
        let repeats = meals.count - Set(meals.map(\.recipeID)).count
        let unchanged = meals.filter { meal in
            request.avoidMeals.contains { $0.date == meal.date && $0.slot == meal.slot && $0.recipeID == meal.recipeID }
        }.count
        let preference = meals.reduce(0) { $0 + (preferenceScores[$1.recipeID] ?? 0) }
        let cost = priced.totalMinorUnits
        let waste = try unusedPackageValue(priced.items, meals: meals)
        let goals = request.profile.onboarding?.goals ?? []
        let priority = (unchanged, goals.contains(.saveMoney) ? cost : 0, goals.contains(.wasteLess) ? waste : 0)
        let rank = (repeats, -preference, cost, waste)
        if best.map({ priority < $0.priority || (priority == $0.priority && rank < $0.rank) }) ?? true {
            best = (meals, priority, rank)
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
    static func includesRequiredMeat(_ meals: [ScheduledMeal], profile: PlanningProfile, catalog: RecipeCatalog) -> Bool {
        guard profile.requiresMeat else { return true }
        let scheduledRecipeIDs = Set(meals.map(\.recipeID))
        return catalog.recipes.contains { $0.containsMeat == true && scheduledRecipeIDs.contains($0.id) }
    }

    static func validate(_ plan: WeeklyPlan) throws {
        try CatalogValidator.validate(plan.catalog, allowDevelopment: true, now: .now, validatePriceFreshness: false)
        try plan.profile.validate()
        guard plan.meals.count == plan.profile.days.count * plan.profile.mealSlots.count,
              Set(plan.meals.map(\.id)).count == plan.meals.count,
              includesRequiredMeat(plan.meals, profile: plan.profile, catalog: plan.catalog) else { throw PlanningError.invalidPlan }
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
