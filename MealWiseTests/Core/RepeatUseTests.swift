import Foundation
import Testing
@testable import MealWise

struct RepeatUseTests {
    private let now = Date(timeIntervalSince1970: 1794528000)

    @Test func ratingsFavorRecipesWithinHardConstraints() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        let result = try await planner.generate(PlanRequest(profile: .fixture, catalog: catalog,
            recipePreferences: [RecipePreference(recipeID: "spinach-bean-pasta", rating: .liked, favorite: true, excluded: false)]))
        guard case .feasible(let plan) = result else { Issue.record("Expected rated plan"); return }
        #expect(plan.meals.first?.recipeID == "spinach-bean-pasta")
        var allergic = PlanningProfile.fixture; allergic.allergies = [.wheat]
        let restricted = try await planner.generate(PlanRequest(profile: allergic, catalog: catalog,
            recipePreferences: [RecipePreference(recipeID: "spinach-bean-pasta", rating: .liked, favorite: true, excluded: false)]))
        guard case .feasible(let safePlan) = restricted else { Issue.record("Expected safe alternatives in the development catalog"); return }
        #expect(safePlan.meals.allSatisfy { $0.recipeID != "spinach-bean-pasta" })
        for meal in safePlan.meals {
            let recipe = try #require(catalog.recipes.first { $0.id == meal.recipeID })
            #expect(PlanService.isEligible(recipe, slot: meal.slot, profile: allergic, catalog: catalog))
        }
    }

    @Test func pinsFailForExclusionsAndImpossibleBudget() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        let pin = RecipePin(recipeID: "spinach-bean-pasta", date: PlanningProfile.fixture.days[0], slot: .dinner)
        let excluded = try await planner.generate(PlanRequest(profile: .fixture, catalog: catalog, excludedRecipeIDs: [pin.recipeID], pins: [pin]))
        guard case .noFeasiblePlan = excluded else { Issue.record("Excluded pins must explain infeasibility"); return }
        var tiny = PlanningProfile.fixture; tiny.budgetMinorUnits = 100
        let over = try await planner.generate(PlanRequest(profile: tiny, catalog: catalog, pins: [pin]))
        guard case .noFeasiblePlan = over else { Issue.record("Pins cannot override budget"); return }
        let good = try await planner.generate(PlanRequest(profile: .fixture, catalog: catalog, pins: [pin]))
        guard case .feasible(let plan) = good else { Issue.record("Expected feasible pin"); return }
        #expect(plan.meals.first?.recipeID == pin.recipeID)
    }

    @Test func nutritionCountsSlotsIncludingRepeatedRecipes() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        var profile = PlanningProfile.fixture; profile.mealSlots = [.lunch, .dinner]
        let meals = [MealSlot.lunch, .dinner].map { ScheduledMeal(id: UUID(), date: profile.days[0], slot: $0, recipeID: "chickpea-rice") }
        let cart = try CartCalculator.calculate(meals: meals, profile: profile, catalog: catalog)
        let plan = WeeklyPlan(id: UUID(), revision: UUID(), profile: profile, catalog: catalog, meals: meals, cart: cart, totalMinorUnits: try CartCalculator.total(cart))
        let summary = try WeeklyNutritionSummary(plan: plan)
        #expect(summary.meals == 2)
        let recipe = try #require(catalog.recipes.first { $0.id == "chickpea-rice" })
        #expect(summary.vegetable == (recipe.nutrition.vegetable ? 2 : 0))
        #expect(summary.protein == (recipe.nutrition.protein ? 2 : 0))
        #expect(summary.wholeGrain == (recipe.nutrition.wholeGrain ? 2 : 0))
    }

    @Test func acceptedPinsAreConsumedOnceAndStalePinsCannotBeAccepted() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let preferences = MealPreferenceRepository(plans: plans)
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let pin = RecipePin(recipeID: "spinach-bean-pasta", date: PlanningProfile.fixture.days[0], slot: .dinner)
        try await preferences.setFavorite(recipeID: pin.recipeID, favorite: true)
        try await preferences.savePin(pin)
        guard case .feasible(let plan) = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: .fixture, catalog: catalog, pins: [pin])) else { throw PlanningError.invalidPlan }
        let changedPin = RecipePin(recipeID: "chickpea-rice", date: pin.date, slot: pin.slot)
        try await preferences.setFavorite(recipeID: changedPin.recipeID, favorite: true)
        try await preferences.savePin(changedPin)
        await #expect(throws: PlanChangeError.stalePreview) { try await plans.saveActivePlan(plan) }
        #expect(try await plans.loadActivePlan() == nil)
        #expect(try await preferences.loadPins() == [changedPin])
        try await preferences.savePin(pin)
        try await plans.saveActivePlan(plan)
        #expect(try await preferences.loadPins().isEmpty)
    }

    @Test func resettingSetupRemovesPendingDatePins() async throws {
        let plans = PlanRepository(container: try await LocalStore.makeContainer(inMemory: true))
        let preferences = MealPreferenceRepository(plans: plans)
        try await preferences.setFavorite(recipeID: "chickpea-rice", favorite: true)
        try await preferences.savePin(RecipePin(recipeID: "chickpea-rice", date: now, slot: .dinner))
        try await plans.resetActivePlan()
        #expect(try await preferences.loadPins().isEmpty)
    }

    @Test func shoppingUsesInjectedClockForReceiptAndPricing() async throws {
        let plans = PlanRepository(container: try await LocalStore.makeContainer(inMemory: true))
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let plan) = try await planner.generate(PlanRequest(profile: .fixture, catalog: catalog)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(plan)
        let service = ShoppingService(plans: plans, clock: { Date(timeIntervalSince1970: 1794528000) })
        let trip = try await service.openTrip(planID: plan.id)
        let line = try #require(trip.lines.first)
        _ = try await service.setChecked(itemID: line.id, checked: true, tripID: trip.id)
        let summary = try await service.finishTrip(trip.id)
        #expect(summary.trip.finishedAt == now)
        #expect(try await plans.loadActivePlan()?.pricedAt == now)
    }

    @Test func cookedRatingsPersistWithoutChangingCookingHistory() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let preferences = MealPreferenceRepository(plans: plans)
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let plan) = try await planner.generate(PlanRequest(profile: .fixture, catalog: catalog)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(plan)
        let shopping = ShoppingService(plans: plans, clock: { Date(timeIntervalSince1970: 1794528000) })
        let trip = try await shopping.openTrip(planID: plan.id)
        for line in trip.lines { _ = try await shopping.setChecked(itemID: line.id, checked: true, tripID: trip.id) }
        _ = try await shopping.finishTrip(trip.id)
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: preferences, clock: { Date(timeIntervalSince1970: 1794528000) })
        let cooking = CookingService(plans: plans, changes: changes, clock: { Date(timeIntervalSince1970: 1794528000) })
        let meal = try #require(plan.meals.first)
        try await cooking.markCooked(mealID: meal.id, planID: plan.id)
        let frozen = try #require(try await plans.loadActivePlan()).cookedRecord(for: meal.id)
        try await preferences.rate(mealID: meal.id, rating: .liked)
        #expect(try await preferences.loadRecipePreferences().first?.favorite == true)
        #expect(try await preferences.loadRatings().first?.mealID == meal.id)
        try await preferences.rate(mealID: meal.id, rating: .disliked)
        #expect(try await preferences.loadRecipePreferences().first?.favorite == false)
        #expect(try await plans.loadActivePlan()?.cookedRecord(for: meal.id) == frozen)
    }

    @Test func preferencesPersistAndUncookedRatingIsRejected() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = MealPreferenceRepository(container: container)
        try await repository.setFavorite(recipeID: "chickpea-rice", favorite: true)
        #expect(try await repository.loadRecipePreferences().first?.favorite == true)
        await #expect(throws: (any Error).self) { try await repository.rate(mealID: UUID(), rating: .liked) }
        try await repository.setExcluded(recipeID: "chickpea-rice", excluded: true)
        #expect(try await repository.loadExcludedRecipeIDs() == ["chickpea-rice"])
    }
}
