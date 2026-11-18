import Foundation
import Testing
@testable import MealWise

struct PantryTests {
    private let now = Date(timeIntervalSince1970: 1794528000)

    @Test func receiptEstimateRoundsUpWithoutRewritingActual() throws {
        let catalog = try JSONDecoder().decode(RecipeCatalog.self, from: Data(contentsOf: #require(Bundle.main.url(forResource: "development-catalog", withExtension: "json"))))
        let offer = try #require(catalog.offers.first)
        let observation = ReceiptPriceObservation(id: "receipt", offerID: offer.id, packageCount: 4, actualMinorUnits: 1017, recordedAt: now)
        #expect(observation.estimatedUnitMinorUnits == 255)
        let updated = try ReceiptCatalog.apply([observation], to: catalog, at: now)
        #expect(updated.offers.first { $0.id == offer.id }?.priceMinorUnits == 255)
        #expect(updated.offers.first { $0.id == offer.id }?.validThrough == offer.validThrough)
        #expect(observation.actualMinorUnits == 1017)
        #expect(catalog.offers.first?.priceMinorUnits == offer.priceMinorUnits)
    }

    @Test func pantryEntryUsesNormalizedUnitsWithoutCurrencyParsing() throws {
        #expect(try PantryQuantityInput.parse("1.25", unit: .milligrams) == 1250)
        #expect(try PantryQuantityInput.parse("5", unit: .milliliters) == 5)
        for input in ["-1", "1e3", "NaN", "1.0001", ""] {
            #expect(throws: (any Error).self) { try PantryQuantityInput.parse(input, unit: .milligrams) }
        }
        #expect(throws: (any Error).self) { try PantryQuantityInput.parse("1.5", unit: .count) }
    }

    @Test func savingsCompareSameMealsAndRequireAvoidedPackages() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        let profile = profile()
        let meal = ScheduledMeal(id: UUID(), date: now, slot: .dinner, recipeID: "spinach-bean-pasta")
        let item = PantryItem(id: UUID(), ingredientID: "whole-wheat-pasta", quantity: 10000, unit: .milligrams,
                              storage: .shelfStable, expiry: nil, availabilityConfirmed: true, revision: UUID())
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        let request = PlanRequest(profile: profile, catalog: catalog, fixedMeals: [meal], confirmedStock: [item])
        guard case .feasible(let small) = try await planner.generate(request) else { Issue.record("Fixture failed"); return }
        #expect(try PantrySavings.estimate(plan: small) == 0)
        var large = item; large.quantity = 200000
        guard case .feasible(let stocked) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: [meal], confirmedStock: [large])) else { Issue.record("Fixture failed"); return }
        #expect(stocked.meals == small.meals)
        #expect(try PantrySavings.estimate(plan: stocked) > 0)
        #expect(stocked.resources?.pantryCredits?.first?.remainingQuantity == 160000)
        var expired = large; expired.expiry = now.addingTimeInterval(-1)
        guard case .feasible(let excluded) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: [meal], confirmedStock: [expired])) else { Issue.record("Fixture failed"); return }
        #expect(excluded.resources?.pantryCredits?.isEmpty ?? true)
        #expect(try PantrySavings.estimate(plan: excluded) == 0)
    }

    @Test func carryoverIsConfirmedOnceAndClosesHistory() async throws {
        let (plans, pantry, history, cooking, original) = try await purchasedFixture()
        try await cooking.markCooked(mealID: original.meals[0].id, planID: original.id)
        let plan = try #require(try await plans.loadActivePlan())
        let report = try WrapUpReport.make(plan: plan)
        let source = try #require(report.sources.first { $0.quantity > 1 })
        let chosen = source.quantity / 2
        let confirmation = CarryoverConfirmation(planID: plan.id, expectedRevision: plan.revision,
            items: [CarryoverLine(sourceID: source.id, quantity: chosen, storage: source.storage, expiry: nil, availabilityConfirmed: true)])
        try await pantry.confirmCarryover(confirmation)
        try await pantry.confirmCarryover(confirmation)
        let items = try await pantry.loadItems()
        #expect(items.count == 1)
        #expect(items.first?.quantity == chosen)
        let cycles = try await history.loadCycles()
        #expect(cycles.count == 1)
        #expect(cycles.first?.plan.resources?.cookedMeals?.count == 1)
        let closed = try #require(try await plans.loadActivePlan())
        #expect(closed.closedAt != nil)
        await #expect(throws: PantryError.cycleClosed) { try await cooking.markCooked(mealID: plan.meals[1].id, planID: plan.id) }
        #expect(report.knownActualMinorUnits == 0)
        #expect(report.missingPriceCount > 0)
    }

    @MainActor
    @Test func reservationCancellationAndRemovalPreserveHistory() async throws {
        let (plans, pantry, _, _, original) = try await purchasedFixture()
        let report = try WrapUpReport.make(plan: original)
        let source = try #require(report.sources.first { $0.ingredientID == "whole-wheat-pasta" })
        try await pantry.confirmCarryover(CarryoverConfirmation(planID: original.id, expectedRevision: original.revision,
            items: [CarryoverLine(sourceID: source.id, quantity: source.quantity, storage: .shelfStable, expiry: nil, availabilityConfirmed: true)]))
        let closed = try #require(try await plans.loadActivePlan())
        let stock = try await pantry.loadItems()
        let catalog = original.catalog
        var nextProfile = profile(); nextProfile.days = [now.addingTimeInterval(7 * 86400)]
        let nextMeal = ScheduledMeal(id: UUID(), date: nextProfile.days[0], slot: .dinner, recipeID: "spinach-bean-pasta")
        guard case .feasible(let next) = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: nextProfile, catalog: catalog, fixedMeals: [nextMeal], confirmedStock: stock)) else { Issue.record("Fixture failed"); return }
        let task = Task { try await plans.startNextCycle(next, expectedPreviousRevision: closed.revision, now: now) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await pantry.loadItems().first?.availableQuantity == source.quantity)
        try await plans.startNextCycle(next, expectedPreviousRevision: closed.revision, now: now)
        let reserved = try #require(try await pantry.loadItems().first)
        #expect(reserved.availableQuantity < reserved.quantity)
        let wrongIngredient = PantryItem(id: reserved.id, ingredientID: "quick-brown-rice", quantity: reserved.quantity, unit: .milligrams,
                                        storage: reserved.storage, expiry: reserved.expiry, availabilityConfirmed: true, revision: reserved.revision)
        await #expect(throws: PantryError.invalidQuantity) { try await pantry.save(wrongIngredient, expectedRevision: reserved.revision) }
        #expect(try await pantry.loadItems().first == reserved)
        try await pantry.remove(id: reserved.id, expectedRevision: reserved.revision)
        let updated = try #require(try await plans.loadActivePlan())
        #expect(updated.revision != next.revision)
        #expect(updated.cart.first { $0.id == "whole-wheat-pasta" }?.packageCount == 1)
        await #expect(throws: PantryError.staleStock) { try await plans.startNextCycle(next, expectedPreviousRevision: closed.revision, now: now) }
    }

    @Test func cookingPantryStockAndEditingExpiryPreserveConsumedHistory() async throws {
        let (plans, pantry, _, _, original) = try await purchasedFixture()
        let source = try #require(try WrapUpReport.make(plan: original).sources.first { $0.ingredientID == "whole-wheat-pasta" })
        let expiry = now.addingTimeInterval(12 * 86400)
        try await pantry.confirmCarryover(CarryoverConfirmation(planID: original.id, expectedRevision: original.revision,
            items: [CarryoverLine(sourceID: source.id, quantity: source.quantity, storage: .shelfStable, expiry: expiry, availabilityConfirmed: true)]))
        let closed = try #require(try await plans.loadActivePlan())
        var nextProfile = profile(); nextProfile.days = [now.addingTimeInterval(7 * 86400), now.addingTimeInterval(8 * 86400)]
        let meals = nextProfile.days.map { ScheduledMeal(id: UUID(), date: $0, slot: .dinner, recipeID: "spinach-bean-pasta") }
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let next) = try await planner.generate(PlanRequest(profile: nextProfile, catalog: original.catalog, fixedMeals: meals, confirmedStock: try await pantry.loadItems())) else { throw PlanningError.invalidPlan }
        try await plans.startNextCycle(next, expectedPreviousRevision: closed.revision, now: now)
        let shopping = ShoppingService(plans: plans)
        let trip = try await shopping.openTrip(planID: next.id)
        for line in trip.lines { _ = try await shopping.setChecked(itemID: line.id, checked: true, tripID: trip.id) }
        _ = try await shopping.finishTrip(trip.id)
        let container = try await LocalStore.makeContainer(inMemory: true)
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: MealPreferenceRepository(container: container), clock: { Date(timeIntervalSince1970: 1794528000) })
        let cooking = CookingService(plans: plans, changes: changes, clock: { Date(timeIntervalSince1970: 1794528000 + 7 * 86400) })
        try await cooking.markCooked(mealID: meals[0].id, planID: next.id)
        let cooked = try #require(try await plans.loadActivePlan())
        let record = try #require(cooked.resources?.cookedMeals?.first)
        let debit = try #require(record.stockDebits?.first { $0.ingredientID == "whole-wheat-pasta" })
        #expect(debit.pantryItemID != nil)
        #expect(debit.quantity == 160000)
        var item = try #require(try await pantry.loadItems().first)
        #expect(item.quantity == source.quantity - 160000)
        #expect(item.reservations[next.id.uuidString] == 160000)
        item.expiry = now.addingTimeInterval(6 * 86400)
        try await pantry.save(item, expectedRevision: item.revision)
        let updated = try #require(try await plans.loadActivePlan())
        #expect(updated.resources?.cookedMeals?.first == record)
        #expect(updated.cart.first { $0.id == "whole-wheat-pasta" }?.packageCount == 1)
        let late = CookingService(plans: plans, changes: changes, clock: { Date(timeIntervalSince1970: 1794528000 + 8 * 86400) })
        await #expect(throws: CookingError.insufficientStock) { try await late.markCooked(mealID: meals[1].id, planID: next.id) }
    }

    private func profile() -> PlanningProfile {
        PlanningProfile(budgetMinorUnits: 7000, adults: 2, children: 0, days: [now], mealSlots: [.dinner], cookingTime: .thirty,
                        skill: .beginner, storeID: "development-grocery", allergies: [], preferences: [])
    }
    private func purchasedFixture() async throws -> (PlanRepository, PantryRepository, HistoryRepository, CookingService, WeeklyPlan) {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let catalog = try await CatalogService(allowDevelopment: true, now: now).loadCatalog()
        var profile = profile(); profile.days.append(now.addingTimeInterval(86400))
        let meals = profile.days.map { ScheduledMeal(id: UUID(), date: $0, slot: .dinner, recipeID: "spinach-bean-pasta") }
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let plan) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: meals)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(plan)
        let shopping = ShoppingService(plans: plans)
        let trip = try await shopping.openTrip(planID: plan.id)
        for line in trip.lines { _ = try await shopping.setChecked(itemID: line.id, checked: true, tripID: trip.id) }
        _ = try await shopping.finishTrip(trip.id)
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: MealPreferenceRepository(container: container), clock: { Date(timeIntervalSince1970: 1794528000) })
        return (plans, PantryRepository(plans: plans, catalog: catalog, clock: { Date(timeIntervalSince1970: 1794528000) }), HistoryRepository(plans: plans),
                CookingService(plans: plans, changes: changes, clock: { Date(timeIntervalSince1970: 1794528000) }), try #require(try await plans.loadActivePlan()))
    }
}
