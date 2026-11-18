import Foundation
import Synchronization
import SwiftData
import Testing
@testable import MealWise

@MainActor struct ReviewRegressionTests {
    private let start = Date(timeIntervalSince1970: 1794528000)

    @Test func expiredPantryRepricesOnReadAndRebuildsEmptyShoppingDraft() async throws {
        let clock = Mutex(start)
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container, clock: { clock.withLock { $0 } })
        let catalog = try await CatalogService(allowDevelopment: true, now: start).loadCatalog()
        let pantry = PantryRepository(plans: plans, catalog: catalog, clock: { clock.withLock { $0 } })
        let recipe = try #require(catalog.recipes.first { $0.id == "spinach-bean-pasta" })
        var stock: [PantryItem] = []
        for requirement in recipe.ingredients {
            let item = PantryItem(id: UUID(), ingredientID: requirement.ingredientID, quantity: requirement.quantity,
                unit: requirement.unit, storage: nil, expiry: start.addingTimeInterval(60), availabilityConfirmed: true, revision: UUID())
            try await pantry.save(item, expectedRevision: nil)
        }
        stock = try await pantry.loadItems()
        var profile = PlanningProfile.fixture; profile.adults = recipe.baseAdultPortions; profile.children = 0; profile.budgetMinorUnits = 100
        let meal = ScheduledMeal(id: UUID(), date: profile.days[0], slot: .dinner, recipeID: recipe.id)
        let planner = PlanService(clock: { clock.withLock { $0 } })
        guard case .feasible(let original) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: [meal], confirmedStock: stock)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(original)
        let shopping = ShoppingService(plans: plans, clock: { clock.withLock { $0 } })
        #expect(try await shopping.openTrip(planID: original.id).lines.isEmpty)
        clock.withLock { $0 = start.addingTimeInterval(120) }
        let refreshed = try #require(try await plans.loadActivePlan())
        #expect(refreshed.revision != original.revision)
        #expect(refreshed.cart.contains { $0.packageCount > 0 })
        #expect(try await shopping.openTrip(planID: original.id).lines.isEmpty == false)
        #expect(refreshed.resources == original.resources)
        #expect(refreshed.reviewRequired == true)
        #expect(refreshed.totalMinorUnits > refreshed.profile.budgetMinorUnits)
        #expect(try await plans.loadActivePlan()?.revision == refreshed.revision)
        try await pantry.confirmCarryover(CarryoverConfirmation(planID: refreshed.id, expectedRevision: refreshed.revision, items: []))
        let closed = try #require(try await plans.loadActivePlan())
        clock.withLock { $0 = start.addingTimeInterval(86400) }
        #expect(try await plans.loadActivePlan() == closed)
        #expect(try await HistoryRepository(plans: plans).loadCycles().first?.plan == closed)
    }

    @Test func cookedMealDoesNotAbortRemainingMealSuggestions() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container, clock: { Date(timeIntervalSince1970: 1794528000) })
        let catalog = try await CatalogService(allowDevelopment: true, now: start).loadCatalog()
        var profile = PlanningProfile.fixture; profile.days.append(start.addingTimeInterval(86400))
        let meals = [ScheduledMeal(id: UUID(), date: profile.days[0], slot: .dinner, recipeID: "chickpea-rice"),
                     ScheduledMeal(id: UUID(), date: profile.days[1], slot: .dinner, recipeID: "spinach-bean-pasta")]
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let original) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: meals)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(original)
        let services = services(plans: plans, container: container, catalog: catalog, planner: planner)
        let trip = try await services.shopping.openTrip(planID: original.id)
        for line in trip.lines { _ = try await services.shopping.setChecked(itemID: line.id, checked: true, tripID: trip.id) }
        _ = try await services.shopping.finishTrip(trip.id)
        try await services.cooking.markCooked(mealID: meals[0].id, planID: original.id)
        let plan = try #require(try await plans.loadActivePlan())
        let model = RemainderSuggestionViewModel(plan: plan, ingredientID: "onion", services: services)
        await model.load()
        #expect(model.errorMessage == nil)
        #expect(!model.options.isEmpty)
        #expect(model.options.allSatisfy { $0.meal.id == meals[1].id })
    }

    private func services(plans: PlanRepository, container: SwiftData.ModelContainer, catalog: RecipeCatalog, planner: PlanService) -> AppServices {
        let clock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1794528000) }
        let preferences = MealPreferenceRepository(plans: plans)
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: preferences, clock: clock)
        return AppServices(catalog: catalog, profiles: ProfileRepository(container: container), plans: plans, planner: planner,
            checklist: ChecklistRepository(container: container), preferences: preferences, shopping: ShoppingService(plans: plans, clock: clock),
            cooking: CookingService(plans: plans, changes: changes, clock: clock), timers: TimerService(plans: plans, clock: clock),
            pantry: PantryRepository(plans: plans, catalog: catalog, clock: clock), history: HistoryRepository(plans: plans),
            cycles: NextCycleService(plans: plans, clock: clock), changes: changes)
    }
}
