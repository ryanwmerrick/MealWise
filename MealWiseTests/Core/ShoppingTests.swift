import Foundation
import Testing
@testable import MealWise

struct ShoppingTests {
    @Test func malformedAndNegativePricesAreRejected() {
        for text in ["-1", "1.001", "NaN", "1e3", "", "$3"] {
            #expect(throws: (any Error).self) { try Money.parse(text) }
        }
    }

    @Test func correctedUncheckedLineStaysInFullForecast() throws {
        let line = ShoppingLine(id: UUID(), ingredientID: "beans", offerID: "can", name: "Beans", packageCount: 2,
                                packageQuantity: 240000, unit: .milligrams, estimatedMinorUnits: 896,
                                actualMinorUnits: 1016, checked: false)
        let other = ShoppingLine(id: UUID(), ingredientID: "other", offerID: "other", name: "Other", packageCount: 1,
                                 packageQuantity: 1, unit: .count, estimatedMinorUnits: 5534, actualMinorUnits: nil, checked: false)
        let trip = ShoppingTrip(id: UUID(), planID: UUID(), planRevision: UUID(), storeID: "development-grocery",
                                budgetMinorUnits: 7000, priorSpendingMinorUnits: 0, lines: [line, other], finishedAt: nil)
        #expect(try JSONDecoder().decode(ShoppingTrip.self, from: JSONEncoder().encode(trip)) == trip)
        #expect(try trip.projectedMinorUnits == 6550)
        #expect(try trip.actualToDateMinorUnits == 0)
        #expect(try trip.remainingMinorUnits == 450)
        var checked = trip
        checked.lines[0].checked = true
        #expect(try checked.actualToDateMinorUnits == 1016)
        checked.lines[0].actualMinorUnits = 8000
        #expect(try checked.remainingMinorUnits < 0)
    }

    @Test func packageSubstitutionPreservesFoodAndRejectsStaleReceipt() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let original = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        let offers = try #require(json["offers"] as? [[String: Any]])
        json["offers"] = offers + offers.map { offer in
            var alternate = offer
            alternate["id"] = (offer["id"] as! String) + "-alternate"
            alternate["priceMinorUnits"] = (offer["priceMinorUnits"] as! Int) + 100
            return alternate
        }
        let catalog = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        let profile = PlanningProfile(budgetMinorUnits: 7000, adults: 2, children: 0,
                                      days: [Date(timeIntervalSince1970: 1794528000)], mealSlots: [.dinner], cookingTime: .thirty,
                                      skill: .beginner, storeID: "development-grocery", allergies: [], preferences: [])
        guard case .feasible(let plan) = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: catalog)) else { Issue.record("Fixture failed"); return }
        try await plans.saveActivePlan(plan)
        let service = ShoppingService(plans: plans, clock: { Date(timeIntervalSince1970: 1794528000) })
        let trip = try await service.openTrip(planID: plan.id)
        let line = try #require(trip.lines.first)
        _ = try await service.selectStore(.aldi, tripID: trip.id)
        _ = try await service.updatePrice(itemID: line.id, actualPrice: Money(minorUnits: 8000), tripID: trip.id)
        let options = try await service.cheaperSubstitutes(itemID: line.id, tripID: trip.id)
        let option = try #require(options.first)
        #expect(option.preview.proposedPlan?.meals == plan.meals)
        #expect(option.projectedMinorUnits <= 7000)
        _ = try await service.setChecked(itemID: line.id, checked: true, tripID: trip.id)
        await #expect(throws: ShoppingError.staleTrip) { try await service.acceptSubstitute(option) }
        let fresh = try #require(try await service.cheaperSubstitutes(itemID: line.id, tripID: trip.id).first)
        let changed = try await service.acceptSubstitute(fresh)
        #expect(changed.lines.first?.actualMinorUnits == nil)
        #expect(changed.lines.first?.checked == false)
        #expect(changed.lines.first?.offerID.hasSuffix("-alternate") == true)
        #expect(changed.startedAt == trip.startedAt)
        #expect(changed.selectedStore == .aldi)
        #expect(try await plans.loadActivePlan()?.meals == plan.meals)
    }

    @MainActor
    @Test func missingReceiptPricesStayUnknownAndCancellationPreservesStock() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let profile = PlanningProfile(budgetMinorUnits: 7000, adults: 2, children: 0,
                                      days: [Date(timeIntervalSince1970: 1794528000)], mealSlots: [.dinner], cookingTime: .thirty,
                                      skill: .beginner, storeID: "development-grocery", allergies: [], preferences: [])
        guard case .feasible(let plan) = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: catalog)) else { Issue.record("Fixture failed"); return }
        try await plans.saveActivePlan(plan)
        let service = ShoppingService(plans: plans, clock: { Date(timeIntervalSince1970: 1794528000) })
        let trip = try await service.openTrip(planID: plan.id)
        let line = try #require(trip.lines.first)
        _ = try await service.setChecked(itemID: line.id, checked: true, tripID: trip.id)
        let task = Task { try await service.finishTrip(trip.id) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await plans.loadActivePlan() == plan)
        #expect(try await service.history(planID: plan.id).isEmpty)
        let summary = try await service.finishTrip(trip.id)
        #expect(summary.missingPriceCount == 1)
        #expect(try summary.knownActualMinorUnits == 0)
        #expect(try await plans.loadActivePlan()?.totalMinorUnits == plan.totalMinorUnits)
        let updated = try #require(try await plans.loadActivePlan())
        let changes = PlanChangeService(plans: plans, planner: PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }), preferences: MealPreferenceRepository(container: container), clock: { Date(timeIntervalSince1970: 1794528000) })
        let stale = try await changes.preview(.swap(mealID: plan.meals[0].id, recipeID: "bean-quesadillas"), in: plan)
        await #expect(throws: PlanChangeError.stalePreview) { try await changes.accept(stale, expectedRevision: plan.revision) }
        #expect(try await plans.loadActivePlan() == updated)
    }

    @Test func partialTripFinishIsIdempotentAndSurvivesReopen() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let profile = PlanningProfile(budgetMinorUnits: 7000, adults: 2, children: 0,
                                      days: [Date(timeIntervalSince1970: 1794528000)], mealSlots: [.dinner], cookingTime: .thirty,
                                      skill: .beginner, storeID: "development-grocery", allergies: [], preferences: [])
        let planner = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        guard case .feasible(let plan) = try await planner.generate(PlanRequest(profile: profile, catalog: catalog)) else { Issue.record("Fixture failed"); return }
        try await plans.saveActivePlan(plan)
        let service = ShoppingService(container: container, clock: { Date(timeIntervalSince1970: 1794528000) })
        let forecast = try await service.cart(planID: plan.id)
        #expect(!forecast.isActive)
        #expect(try forecast.trip.projectedMinorUnits == plan.totalMinorUnits)
        #expect(try await !service.cart(planID: plan.id).isActive)
        let trip = try await service.openTrip(planID: plan.id)
        #expect(trip.startedAt == Date(timeIntervalSince1970: 1794528000))
        _ = try await service.selectStore(.aldi, tripID: trip.id)
        let line = try #require(trip.lines.first)
        #expect(try await service.cheaperSubstitutes(itemID: line.id, tripID: trip.id).isEmpty)
        _ = try await service.setChecked(itemID: line.id, checked: true, tripID: trip.id)
        let pending = try #require(trip.lines.dropFirst().first)
        _ = try await service.updatePrice(itemID: pending.id, actualPrice: Money(minorUnits: 1016), tripID: trip.id)
        let price = try Money(minorUnits: 8000)
        _ = try await service.updatePrice(itemID: line.id, actualPrice: price, tripID: trip.id)
        _ = try await service.setChecked(itemID: line.id, checked: false, tripID: trip.id)
        let reloaded = try await service.openTrip(planID: plan.id)
        #expect(reloaded.startedAt == trip.startedAt)
        #expect(reloaded.selectedStore == .aldi)
        #expect(try await service.cart(planID: plan.id).trip == reloaded)
        #expect(reloaded.lines.first?.actualMinorUnits == 8000)
        #expect(try reloaded.actualToDateMinorUnits == 0)
        #expect(try reloaded.projectedMinorUnits > 7000)
        _ = try await service.setChecked(itemID: line.id, checked: true, tripID: trip.id)
        let summary = try await service.finishTrip(trip.id)
        #expect(summary.purchasedCount == 1)
        #expect(summary.missingPriceCount == 0)
        #expect(try summary.knownActualMinorUnits == 8000)
        #expect(summary.unpurchasedCount == trip.lines.count - 1)
        let reopened = ShoppingService(container: container, clock: { Date(timeIntervalSince1970: 1794528000) })
        #expect(try await reopened.finishTrip(trip.id) == summary)
        let purchased = try #require(try await plans.loadActivePlan())
        #expect(purchased.resources?.purchases.count == 1)
        #expect(purchased.totalMinorUnits > purchased.profile.budgetMinorUnits)
        #expect(purchased.cart.first { $0.id == line.ingredientID }?.packageCount == 0)
        #expect(try await reopened.history(planID: plan.id).count == 1)
        let preferences = MealPreferenceRepository(container: container)
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: preferences, clock: { Date(timeIntervalSince1970: 1794528000) })
        let preview = try await changes.preview(.regenerateWeek, in: purchased)
        if let proposed = preview.proposedPlan {
            #expect(proposed.resources == purchased.resources)
            #expect(proposed.totalMinorUnits >= purchased.resources!.committedMinorUnits)
        }
        #expect(try await reopened.history(planID: plan.id).first == summary)
        #expect(summary.trip.selectedStore == .aldi)
        let remainingForecast = try await reopened.cart(planID: plan.id)
        #expect(!remainingForecast.isActive)
        #expect(remainingForecast.trip.priorSpendingMinorUnits == 8000)
        #expect(remainingForecast.trip.lines.first { $0.ingredientID == pending.ingredientID }?.actualMinorUnits == 1016)
        let next = try await reopened.openTrip(planID: plan.id)
        #expect(!next.lines.contains { $0.ingredientID == line.ingredientID })
        #expect(next.lines.first { $0.ingredientID == pending.ingredientID }?.actualMinorUnits == 1016)
        await #expect(throws: ShoppingError.noPurchases) { try await reopened.finishTrip(next.id) }
        await #expect(throws: ShoppingError.missingTrip) {
            try await reopened.updatePrice(itemID: line.id, actualPrice: Money(minorUnits: 100), tripID: trip.id)
        }
    }
}
