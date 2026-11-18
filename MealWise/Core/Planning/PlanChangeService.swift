import Foundation

enum PlanChange: Sendable {
    case swap(mealID: UUID, recipeID: String)
    case regenerateDay(Date)
    case regenerateWeek
    case profile(PlanningProfile)
    case move(mealID: UUID, date: Date)
    case packageOffer(ingredientID: String, offerID: String)
}

enum ChangeConstraint: Sendable, Equatable {
    case feasible, overBudget, noFeasiblePlan, searchLimit, invalidInputs, noAlternative
}

extension ChangeConstraint {
    var message: String {
        switch self {
        case .feasible: "This change fits your budget."
        case .overBudget: "This comparison is over budget and cannot be accepted. Adjust your budget explicitly or choose another option."
        case .noFeasiblePlan: "No complete plan fits these choices. Try fewer meals, more time or a higher budget; hard food requirements will never be relaxed."
        case .searchLimit: "The bounded search did not find a complete plan. Try fewer meals or a higher budget."
        case .invalidInputs: "Check the selected settings and price dates, then try again."
        case .noAlternative: "No different combination was found with these choices. Your current plan is unchanged."
        }
    }
}

enum PlanChangeError: Error { case stalePreview, ineligibleRecipe, infeasible, invalidTarget }

struct CartImpact: Sendable, Identifiable {
    let id: String
    let name: String
    let oldPackages: Int64
    let newPackages: Int64
    let oldCost: Int64
    let newCost: Int64
    let oldRequired: Int64
    let newRequired: Int64
    let unit: QuantityUnit
}

struct PlanChangePreview: Sendable, Identifiable {
    let id: UUID
    let basePlanID: UUID
    let baseRevision: UUID
    let proposedPlan: WeeklyPlan?
    let constraint: ChangeConstraint
    let impacts: [CartImpact]
    let changedMealIDs: Set<UUID>
    let oldTotalMinorUnits: Int64

    var reusedIngredientCount: Int { impacts.filter { $0.oldPackages > 0 && $0.newPackages > 0 }.count }
}

protocol PlanChangeServiceProtocol: Sendable {
    func preview(_ change: PlanChange, in plan: WeeklyPlan) async throws -> PlanChangePreview
    func accept(_ preview: PlanChangePreview, expectedRevision: UUID) async throws -> WeeklyPlan
}

actor PlanChangeService: PlanChangeServiceProtocol {
    private let plans: any PlanRepositoryProtocol
    private let planner: any PlanServiceProtocol
    private let preferences: any MealPreferenceRepositoryProtocol
    private let clock: @Sendable () -> Date
    private let latestCatalog: RecipeCatalog?

    init(plans: any PlanRepositoryProtocol, planner: any PlanServiceProtocol,
         preferences: any MealPreferenceRepositoryProtocol, clock: @escaping @Sendable () -> Date = { .now }, latestCatalog: RecipeCatalog? = nil) {
        self.plans = plans; self.planner = planner; self.preferences = preferences; self.clock = clock
        self.latestCatalog = latestCatalog
    }

    func preview(_ change: PlanChange, in plan: WeeklyPlan) async throws -> PlanChangePreview {
        try Task.checkCancellation()
        try PlanValidation.validate(plan)
        guard plan.closedAt == nil else { throw PantryError.cycleClosed }
        try CatalogValidator.validate(plan.catalog, allowDevelopment: true, now: clock())
        let excluded = try await preferences.loadExcludedRecipeIDs()
        if case .move(let mealID, let date) = change {
            guard let original = plan.meals.first(where: { $0.id == mealID }),
                  let other = plan.meals.first(where: { $0.date == date && $0.slot == original.slot }),
                  original.id != other.id else { throw PlanChangeError.invalidTarget }
            guard plan.cookedRecord(for: original.id) == nil, plan.cookedRecord(for: other.id) == nil else { throw CookingError.alreadyCooked }
            let meals = plan.meals.map { meal in
                ScheduledMeal(id: meal.id, date: meal.id == original.id ? other.date : (meal.id == other.id ? original.date : meal.date),
                              slot: meal.slot, recipeID: meal.recipeID)
            }
            let priced = try CartCalculator.calculate(CartRequest(meals: meals, profile: plan.profile, catalog: plan.catalog, resources: plan.resources, offerOverrides: plan.offerOverrides, pricedAt: clock()))
            let proposed = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog, meals: meals,
                                      cart: priced.items, totalMinorUnits: priced.totalMinorUnits, resources: plan.resources, offerOverrides: plan.offerOverrides, pricedAt: clock())
            try PlanValidation.validate(proposed)
            return makePreview(base: plan, proposed: proposed, constraint: proposed.remainingMinorUnits >= 0 ? .feasible : .overBudget)
        }
        if case .packageOffer(let ingredientID, let offerID) = change {
            guard let item = plan.cart.first(where: { $0.id == ingredientID }), item.packageCount > 0,
                  let offer = plan.catalog.offers.first(where: { $0.id == offerID }),
                  offer.ingredientID == ingredientID, offer.storeID == plan.profile.storeID,
                  offerID != item.offerID else { throw PlanChangeError.invalidTarget }
            var overrides = plan.offerOverrides ?? [:]; overrides[ingredientID] = offerID
            let priced = try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog,
                                                                  resources: plan.resources, offerOverrides: overrides, pricedAt: clock()))
            let proposed = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog,
                                      meals: plan.meals, cart: priced.items, totalMinorUnits: priced.totalMinorUnits,
                                      resources: plan.resources, offerOverrides: overrides, pricedAt: clock())
            return makePreview(base: plan, proposed: proposed, constraint: proposed.remainingMinorUnits >= 0 ? .feasible : .overBudget)
        }
        if case .swap(let mealID, let recipeID) = change {
            guard plan.cookedRecord(for: mealID) == nil else { throw CookingError.alreadyCooked }
            guard let original = plan.meals.first(where: { $0.id == mealID }),
                  let recipe = plan.catalog.recipes.first(where: { $0.id == recipeID }),
                  recipeID != original.recipeID, !excluded.contains(recipeID),
                  PlanService.isEligible(recipe, slot: original.slot, profile: plan.profile, catalog: plan.catalog) else {
                throw PlanChangeError.ineligibleRecipe
            }
            let meals = plan.meals.map { meal in
                meal.id == mealID ? ScheduledMeal(id: meal.id, date: meal.date, slot: meal.slot, recipeID: recipeID) : meal
            }
            guard PlanValidation.includesRequiredMeat(meals, profile: plan.profile, catalog: plan.catalog) else {
                return makePreview(base: plan, proposed: nil, constraint: .noFeasiblePlan)
            }
            let priced = try CartCalculator.calculate(CartRequest(meals: meals, profile: plan.profile, catalog: plan.catalog, resources: plan.resources, offerOverrides: plan.offerOverrides, pricedAt: clock()))
            let proposed = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog,
                                      meals: meals, cart: priced.items, totalMinorUnits: priced.totalMinorUnits, resources: plan.resources, offerOverrides: plan.offerOverrides, pricedAt: clock())
            return makePreview(base: plan, proposed: proposed,
                               constraint: priced.totalMinorUnits <= plan.profile.budgetMinorUnits ? .feasible : .overBudget)
        }
        let profile: PlanningProfile
        let fixed: [ScheduledMeal]
        let avoid: [ScheduledMeal]
        switch change {
        case .profile(let requested):
            let cooked = plan.resources?.cookedMeals?.map(\.meal) ?? []
            guard cooked.allSatisfy({ requested.days.contains($0.date) && requested.mealSlots.contains($0.slot) }) else { throw CookingError.alreadyCooked }
            profile = requested; fixed = cooked; avoid = plan.meals.filter { plan.cookedRecord(for: $0.id) == nil }
        case .regenerateDay(let date):
            guard plan.profile.days.contains(date) else { throw PlanChangeError.invalidTarget }
            profile = plan.profile; fixed = plan.meals.filter { $0.date != date || plan.cookedRecord(for: $0.id) != nil }; avoid = plan.meals.filter { $0.date == date && plan.cookedRecord(for: $0.id) == nil }
        case .regenerateWeek: profile = plan.profile; fixed = plan.resources?.cookedMeals?.map(\.meal) ?? []; avoid = plan.meals.filter { plan.cookedRecord(for: $0.id) == nil }
        case .swap, .packageOffer, .move: throw PlanChangeError.invalidTarget
        }
        let catalog: RecipeCatalog
        if case .profile = change { catalog = expandedDevelopmentCatalog(for: plan.catalog) }
        else { catalog = plan.catalog }
        let outcome = try await planner.generate(PlanRequest(profile: profile, catalog: catalog,
                                                            excludedRecipeIDs: excluded, fixedMeals: fixed, avoidMeals: avoid, resources: plan.resources, offerOverrides: plan.offerOverrides))
        switch outcome {
        case .feasible(let generated):
            let proposed = WeeklyPlan(id: plan.id, revision: generated.revision, profile: generated.profile,
                                      catalog: generated.catalog, meals: generated.meals, cart: generated.cart,
                                      totalMinorUnits: generated.totalMinorUnits, resources: plan.resources, offerOverrides: plan.offerOverrides, pricedAt: generated.pricedAt)
            let unchanged = proposed.profile == plan.profile && proposed.meals.allSatisfy { meal in
                plan.meals.contains { $0.date == meal.date && $0.slot == meal.slot && $0.recipeID == meal.recipeID }
            }
            let isRegeneration: Bool
            switch change { case .regenerateDay, .regenerateWeek: isRegeneration = true; default: isRegeneration = false }
            return makePreview(base: plan, proposed: proposed, constraint: unchanged && isRegeneration ? .noAlternative : .feasible)
        case .noFeasiblePlan: return makePreview(base: plan, proposed: nil, constraint: .noFeasiblePlan)
        case .searchLimit: return makePreview(base: plan, proposed: nil, constraint: .searchLimit)
        case .invalidInputs: return makePreview(base: plan, proposed: nil, constraint: .invalidInputs)
        }
    }

    // Profile edits can use newly bundled meals while retaining saved package prices and IDs.
    private func expandedDevelopmentCatalog(for saved: RecipeCatalog) -> RecipeCatalog {
        guard let latestCatalog, latestCatalog.version != saved.version,
              saved.reviewStatus == .developmentApproved, latestCatalog.reviewStatus == .developmentApproved,
              saved.currencyCode == latestCatalog.currencyCode, saved.stores == latestCatalog.stores,
              saved.ingredients.allSatisfy({ old in
                  latestCatalog.ingredients.first(where: { $0.id == old.id }).map { $0.unit == old.unit } ?? true
              }) else { return saved }
        let ingredients = saved.ingredients.map { old in latestCatalog.ingredients.first { $0.id == old.id } ?? old } +
            latestCatalog.ingredients.filter { new in !saved.ingredients.contains { $0.id == new.id } }
        let recipes = saved.recipes.map { old in latestCatalog.recipes.first { $0.id == old.id } ?? old } +
            latestCatalog.recipes.filter { new in !saved.recipes.contains { $0.id == new.id } }
        let offers = saved.offers + latestCatalog.offers.filter { new in !saved.offers.contains { $0.id == new.id } }
        return RecipeCatalog(version: latestCatalog.version, reviewStatus: saved.reviewStatus,
                             currencyCode: saved.currencyCode, authorship: latestCatalog.authorship,
                             priceProvenance: saved.priceProvenance, stores: saved.stores,
                             ingredients: ingredients, offers: offers, recipes: recipes)
    }

    func accept(_ preview: PlanChangePreview, expectedRevision: UUID) async throws -> WeeklyPlan {
        try Task.checkCancellation()
        guard preview.baseRevision == expectedRevision else { throw PlanChangeError.stalePreview }
        guard preview.constraint == .feasible, let proposed = preview.proposedPlan,
              proposed.id == preview.basePlanID else { throw PlanChangeError.infeasible }
        try CatalogValidator.validate(proposed.catalog, allowDevelopment: true, now: clock())
        try PlanValidation.validate(proposed)
        let current = try CartCalculator.calculate(CartRequest(meals: proposed.meals, profile: proposed.profile, catalog: proposed.catalog,
                                                               resources: proposed.resources, offerOverrides: proposed.offerOverrides, pricedAt: clock()))
        guard current.items == proposed.cart else { throw PlanChangeError.stalePreview }
        guard proposed.totalMinorUnits <= proposed.profile.budgetMinorUnits else { throw PlanChangeError.infeasible }
        let excluded = try await preferences.loadExcludedRecipeIDs()
        guard proposed.meals.filter({ preview.changedMealIDs.contains($0.id) }).allSatisfy({ !excluded.contains($0.recipeID) }) else {
            throw PlanChangeError.ineligibleRecipe
        }
        try await plans.commit(proposed, expectedRevision: expectedRevision)
        return proposed
    }

    private func makePreview(base: WeeklyPlan, proposed: WeeklyPlan?, constraint: ChangeConstraint) -> PlanChangePreview {
        guard let proposed else {
            return PlanChangePreview(id: UUID(), basePlanID: base.id, baseRevision: base.revision, proposedPlan: nil,
                                     constraint: constraint, impacts: [], changedMealIDs: [], oldTotalMinorUnits: base.totalMinorUnits)
        }
        let impacts = Set(base.cart.map(\.id) + proposed.cart.map(\.id)).sorted().compactMap { id -> CartImpact? in
            let old = base.cart.first { $0.id == id }
            let new = proposed.cart.first { $0.id == id }
            guard let ingredient = proposed.catalog.ingredients.first(where: { $0.id == id })
                ?? base.catalog.ingredients.first(where: { $0.id == id }) else { return nil }
            return CartImpact(id: id, name: ingredient.name, oldPackages: old?.packageCount ?? 0, newPackages: new?.packageCount ?? 0,
                              oldCost: old?.costMinorUnits ?? 0, newCost: new?.costMinorUnits ?? 0,
                              oldRequired: old?.requiredQuantity ?? 0, newRequired: new?.requiredQuantity ?? 0, unit: ingredient.unit)
        }
        let changed = Set(proposed.meals.filter { meal in
            !base.meals.contains { $0.id == meal.id && $0.recipeID == meal.recipeID && $0.date == meal.date && $0.slot == meal.slot }
        }.map(\.id))
        return PlanChangePreview(id: UUID(), basePlanID: base.id, baseRevision: base.revision, proposedPlan: proposed,
                                 constraint: constraint, impacts: impacts, changedMealIDs: changed, oldTotalMinorUnits: base.totalMinorUnits)
    }
}
