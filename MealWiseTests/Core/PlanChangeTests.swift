import Foundation
import Testing
@testable import MealWise

struct PlanChangeTests {
    @Test func editingLegacyPlanUsesExpandedCatalogWithoutChangingSavedPrices() async throws {
        let now = Date(timeIntervalSince1970: 1794528000)
        let latest = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(latest)) as? [String: Any])
        json["version"] = "legacy-development"
        json["recipes"] = Array(try #require(json["recipes"] as? [[String: Any]]).prefix(12))
        var ingredients = Array(try #require(json["ingredients"] as? [[String: Any]]).prefix(19))
        for index in ingredients.indices { ingredients[index].removeValue(forKey: "developmentAllergensReviewed") }
        json["ingredients"] = ingredients
        var offers = Array(try #require(json["offers"] as? [[String: Any]]).prefix(19))
        offers[0]["priceMinorUnits"] = 321
        json["offers"] = offers
        let legacy = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        let (plan, plans, preferences, _) = try await setup(override: legacy)
        let service = PlanChangeService(plans: plans, planner: PlanService(clock: { now }),
                                        preferences: preferences, clock: { now }, latestCatalog: latest)
        var profile = plan.profile
        profile.cookingTime = .fifteen
        profile.allergies = Set(Allergen.allCases)
        profile.preferences = Set(DietPreference.allCases)
        let preview = try await service.preview(.profile(profile), in: plan)
        #expect(preview.constraint == .feasible)
        let proposed = try #require(preview.proposedPlan)
        #expect(proposed.catalog.recipes.count == 33)
        #expect(proposed.catalog.offers.first?.priceMinorUnits == 321)
        #expect(try await plans.loadActivePlan() == plan)
        let accepted = try await service.accept(preview, expectedRevision: plan.revision)
        #expect(accepted.profile.allergies == Set(Allergen.allCases))
        #expect(try await plans.loadActivePlan() == accepted)
    }

    @Test func lowerConsumptionCostCanRequireMoreCheckoutSpending() async throws {
        let original = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var template = try #require((json["recipes"] as? [[String: Any]])?.first)
        template["mealSlots"] = ["dinner"]
        template["id"] = "old-package"
        template["ingredients"] = [["ingredientID": "black-beans", "quantity": 100000, "unit": "milligrams"]]
        var replacement = template
        replacement["id"] = "new-package"
        replacement["ingredients"] = [["ingredientID": "cinnamon", "quantity": 1000, "unit": "milligrams"]]
        json["recipes"] = [template, replacement]
        let catalog = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        let (plan, _, _, service) = try await setup(override: catalog)
        let meal = try #require(plan.meals.first)
        #expect(meal.recipeID == "old-package")
        let preview = try await service.preview(.swap(mealID: meal.id, recipeID: "new-package"), in: plan)
        let proposed = try #require(preview.proposedPlan)
        #expect(proposed.totalMinorUnits > plan.totalMinorUnits)
        #expect(try PlanCostBreakdown.detail(plan: proposed, mealID: meal.id).ingredientCost < PlanCostBreakdown.detail(plan: plan, mealID: meal.id).ingredientCost)
    }

    @MainActor
    @Test func cancelledAcceptancePreservesCommittedPlan() async throws {
        let (plan, plans, _, service) = try await setup()
        let meal = try #require(plan.meals.first)
        let preview = try await service.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: plan)
        let acceptance = Task { try await service.accept(preview, expectedRevision: plan.revision) }
        acceptance.cancel()
        await #expect(throws: CancellationError.self) { try await acceptance.value }
        #expect(try await plans.loadActivePlan() == plan)
    }

    @Test func invalidCommitPreservesPlanAndProfile() async throws {
        let (plan, plans, _, _) = try await setup()
        var profile = plan.profile; profile.budgetMinorUnits = 5500
        let invalid = WeeklyPlan(id: plan.id, revision: UUID(), profile: profile, catalog: plan.catalog,
                                 meals: plan.meals, cart: plan.cart, totalMinorUnits: plan.totalMinorUnits + 1)
        await #expect(throws: PlanningError.self) { try await plans.commit(invalid, expectedRevision: plan.revision) }
        #expect(try await plans.loadActivePlan() == plan)
    }
    @MainActor
    @Test func editingBudgetDuringSearchRejectsLatePreview() async throws {
        let (plan, _, _, service) = try await setup()
        var profile = plan.profile; profile.budgetMinorUnits = 5500
        let preview = try await service.preview(.profile(profile), in: plan)
        let delayed = DelayedPlanChangeService(result: preview)
        let model = PlanChangeViewModel(plan: plan, changes: delayed)
        model.budgetText = "55"
        let request = Task { await model.prepareBudget() }
        await delayed.waitUntilStarted()
        model.budgetText = "40"
        await delayed.release()
        await request.value
        #expect(model.preview == nil)
    }
    @Test func dayRegenerationFindsAlternativeWhenAllRecipesAlreadyUsed() async throws {
        let (plan, _, _, service) = try await setup(days: 4)
        #expect(Set(plan.meals.map(\.recipeID)).count == 4)
        let day = plan.profile.days[0]
        let original = try #require(plan.meals.first { $0.date == day })
        let preview = try await service.preview(.regenerateDay(day), in: plan)
        #expect(preview.constraint == .feasible)
        #expect(preview.proposedPlan?.meals.first { $0.date == day }?.recipeID != original.recipeID)
    }

    @MainActor
    @Test func changingBudgetInvalidatesPreviousPreview() async throws {
        let (plan, plans, _, service) = try await setup()
        let model = PlanChangeViewModel(plan: plan, changes: service)
        model.budgetText = "55"
        await model.prepareBudget()
        #expect(model.preview?.constraint == .feasible)
        model.budgetText = "40"
        #expect(model.preview == nil)
        #expect(await model.accept() == nil)
        #expect(try await plans.loadActivePlan() == plan)
    }

    @Test func overBudgetComparisonCannotBecomeActive() async throws {
        let (original, plans, _, service) = try await setup()
        var profile = original.profile
        profile.budgetMinorUnits = original.totalMinorUnits
        let plan = WeeklyPlan(id: original.id, revision: original.revision, profile: profile, catalog: original.catalog,
                              meals: original.meals, cart: original.cart, totalMinorUnits: original.totalMinorUnits)
        try await plans.saveActivePlan(plan)
        let meal = try #require(plan.meals.first)
        let preview = try await service.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: plan)
        #expect(preview.constraint == .overBudget)
        #expect(preview.proposedPlan?.totalMinorUnits == 1223)
        await #expect(throws: PlanChangeError.self) { try await service.accept(preview, expectedRevision: plan.revision) }
        #expect(try await plans.loadActivePlan() == plan)
    }
    private func setup(days: Int = 1, override: RecipeCatalog? = nil) async throws -> (WeeklyPlan, PlanRepository, MealPreferenceRepository, PlanChangeService) {
        var profile = PlanningProfile.fixture
        profile.days = (0..<days).map { profile.days[0].addingTimeInterval(Double($0) * 86400) }
        let catalog: RecipeCatalog
        if let override { catalog = override }
        else { catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog() }
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let plan) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog)) else { throw PlanningError.invalidPlan }
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let preferences = MealPreferenceRepository(container: container)
        try await plans.saveActivePlan(plan)
        return (plan, plans, preferences, PlanChangeService(plans: plans, planner: planner, preferences: preferences, clock: { Date(timeIntervalSince1970: 1794528000) }))
    }

    @Test func swapRepricesWholeCartAndRemovesLastUse() async throws {
        let (plan, plans, _, service) = try await setup()
        let meal = try #require(plan.meals.first)
        let preview = try await service.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: plan)
        #expect(preview.constraint == .feasible)
        let proposed = try #require(preview.proposedPlan)
        #expect(!proposed.cart.contains { $0.ingredientID == "white-beans" })
        #expect(proposed.cart.contains { $0.ingredientID == "corn-tortillas" })
        #expect(proposed.totalMinorUnits == 1223)
        #expect(try await plans.loadActivePlan() == plan)
        let accepted = try await service.accept(preview, expectedRevision: plan.revision)
        #expect(accepted == proposed)
        #expect(try await plans.loadActivePlan() == proposed)
    }

    @Test func stalePreviewCannotOverwriteAcceptedChange() async throws {
        let (plan, plans, _, service) = try await setup()
        let meal = try #require(plan.meals.first)
        let first = try await service.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: plan)
        let stale = try await service.preview(.swap(mealID: meal.id, recipeID: "chickpea-rice"), in: plan)
        let accepted = try await service.accept(first, expectedRevision: plan.revision)
        await #expect(throws: PlanChangeError.self) { try await service.accept(stale, expectedRevision: plan.revision) }
        #expect(try await plans.loadActivePlan() == accepted)
    }

    @Test func infeasibleBudgetPreviewDoesNotMutatePlan() async throws {
        let (plan, plans, _, service) = try await setup()
        var profile = plan.profile
        profile.budgetMinorUnits = 100
        let preview = try await service.preview(.profile(profile), in: plan)
        #expect(preview.constraint == .noFeasiblePlan)
        #expect(preview.impacts.isEmpty)
        await #expect(throws: PlanChangeError.self) { try await service.accept(preview, expectedRevision: plan.revision) }
        #expect(try await plans.loadActivePlan() == plan)
    }

    @Test func dayRegenerationPreservesOtherMeals() async throws {
        let (plan, _, _, service) = try await setup(days: 3)
        let day = plan.profile.days[1]
        let preview = try await service.preview(.regenerateDay(day), in: plan)
        let proposed = try #require(preview.proposedPlan)
        #expect(proposed.meals.filter { $0.date != day } == plan.meals.filter { $0.date != day })
    }

    @Test func blockedRecipesPersistAndCannotBeSelected() async throws {
        let (plan, _, preferences, service) = try await setup()
        try await preferences.setExcluded(recipeID: "bean-quesadillas", excluded: true)
        #expect(try await preferences.loadExcludedRecipeIDs() == ["bean-quesadillas"])
        let meal = try #require(plan.meals.first)
        await #expect(throws: PlanChangeError.self) {
            try await service.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: plan)
        }
    }
}

private actor DelayedPlanChangeService: PlanChangeServiceProtocol {
    private let result: PlanChangePreview
    private var pending: CheckedContinuation<PlanChangePreview, Never>?
    private var started = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    init(result: PlanChangePreview) { self.result = result }
    func preview(_ change: PlanChange, in plan: WeeklyPlan) async -> PlanChangePreview {
        started = true; startedWaiter?.resume(); startedWaiter = nil
        return await withCheckedContinuation { pending = $0 }
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }
    func release() { pending?.resume(returning: result); pending = nil }
    func accept(_ preview: PlanChangePreview, expectedRevision: UUID) async throws -> WeeklyPlan { throw PlanChangeError.infeasible }
}
