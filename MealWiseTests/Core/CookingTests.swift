import Foundation
import Testing
@testable import MealWise

struct CookingTests {
    @Test func todayUsesInjectedCalendarAcrossMidnight() throws {
        let formatter = ISO8601DateFormatter()
        let meal = ScheduledMeal(id: UUID(), date: try #require(formatter.date(from: "2026-11-14T12:00:00Z")), slot: .dinner, recipeID: "test")
        let now = try #require(formatter.date(from: "2026-11-15T00:30:00Z"))
        var losAngeles = Calendar(identifier: .gregorian); losAngeles.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(TodaySchedule.meals([meal], on: now, calendar: losAngeles) == [meal])
        #expect(TodaySchedule.meals([meal], on: now, calendar: tokyo).isEmpty)
        #expect(TodaySchedule.meals([], on: now, calendar: losAngeles).isEmpty)
    }

    @Test func completionConsumesStockOnceAndFreezesHistory() async throws {
        let (plan, plans, service, changes) = try await fixture()
        let meal = plan.meals[0]
        try await service.markCooked(mealID: meal.id, planID: plan.id)
        let cooked = try #require(try await plans.loadActivePlan())
        let record = try #require(cooked.resources?.cookedMeals?.first)
        #expect(record.meal == meal)
        #expect(record.profile.adults == plan.profile.adults)
        try await service.markCooked(mealID: meal.id, planID: plan.id)
        #expect(try await plans.loadActivePlan() == cooked)
        await #expect(throws: CookingError.alreadyCooked) {
            try await changes.preview(.swap(mealID: meal.id, recipeID: "bean-quesadillas"), in: cooked)
        }
        let preview = try await changes.preview(.regenerateWeek, in: cooked)
        #expect(preview.proposedPlan?.meals.contains(meal) == true)
        var newProfile = cooked.profile; newProfile.adults = 1
        let adjusted = try await changes.preview(.profile(newProfile), in: cooked)
        let proposed = try #require(adjusted.proposedPlan)
        #expect(proposed.resources?.cookedMeals?.first == record)
        let detail = try PlanCostBreakdown.detail(plan: proposed, mealID: meal.id)
        #expect(detail.adultHalfPortions == plan.profile.adultHalfPortions)
        let average = await MainActor.run { WeekViewModel(plan: proposed).checkoutPerAdultPortion }
        let portions = Int64(plan.profile.adultHalfPortions + newProfile.adultHalfPortions)
        let expectedAverage = (Decimal(proposed.totalMinorUnits) * 2 / 100 / Decimal(portions)).formatted(.currency(code: "USD"))
        #expect(average == expectedAverage)
        var removedDay = cooked.profile; removedDay.days.removeAll { $0 == meal.date }
        await #expect(throws: CookingError.alreadyCooked) { try await changes.preview(.profile(removedDay), in: cooked) }
        let accepted = try await changes.accept(adjusted, expectedRevision: cooked.revision)
        let nextMeal = try #require(accepted.meals.first { $0.id != meal.id })
        await #expect(throws: CookingError.staleMeal) {
            try await service.markCooked(mealID: nextMeal.id, planID: plan.id, expectedRevision: cooked.revision)
        }
        try await plans.resetActivePlan()
        let history = try await plans.loadArchivedPlans()
        #expect(history.count == 1)
        #expect(history.first?.plan.resources?.cookedMeals?.first == record)
        try await plans.resetActivePlan()
        #expect(try await plans.loadArchivedPlans().count == 1)
    }

    @Test func missingPurchasedIngredientsCannotBeConsumed() async throws {
        let (plan, plans, service, _) = try await fixture(purchase: false)
        await #expect(throws: CookingError.insufficientStock) { try await service.markCooked(mealID: plan.meals[0].id, planID: plan.id) }
        #expect(try await plans.loadActivePlan() == plan)
    }

    @Test func stepsAndTimerSurviveCloseAndExpiry() async throws {
        let (plan, plans, service, _) = try await fixture()
        let meal = plan.meals[0]
        _ = try await service.setStep(number: 1, complete: true, mealID: meal.id, planID: plan.id, recipeID: meal.recipeID)
        #expect(try await service.loadProgress(mealID: meal.id, planID: plan.id).completedSteps == [1])
        let now = Date(timeIntervalSince1970: 1794528000)
        let timers = TimerService(plans: plans, clock: { now })
        let timer = try await timers.start(mealID: meal.id, planID: plan.id, seconds: 60)
        #expect(timer.remaining(at: now.addingTimeInterval(20)) == 40)
        #expect(timer.remaining(at: now.addingTimeInterval(120)) == 0)
        #expect(try await service.loadProgress(mealID: meal.id, planID: plan.id).timer == timer)
        await #expect(throws: CookingError.staleMeal) {
            try await timers.start(mealID: meal.id, planID: plan.id, seconds: 60, expectedRecipeID: "replacement")
        }
        await #expect(throws: CookingError.staleMeal) {
            try await timers.cancel(mealID: meal.id, planID: plan.id, expectedRecipeID: "replacement")
        }
        #expect(try await service.loadProgress(mealID: meal.id, planID: plan.id).timer == timer)
        try await timers.cancel(mealID: meal.id, planID: plan.id)
        #expect(try await service.loadProgress(mealID: meal.id, planID: plan.id).timer == nil)
    }

    @Test func movingUncookedMealReordersReservationsWithoutConsumption() async throws {
        let (plan, plans, service, changes) = try await fixture()
        let meal = plan.meals[0]
        let preview = try await service.previewMove(mealID: meal.id, to: plan.meals[1].date, planID: plan.id)
        let proposed = try #require(preview.proposedPlan)
        #expect(proposed.meals.first { $0.id == meal.id }?.date == plan.meals[1].date)
        #expect(proposed.resources?.cookedMeals?.isEmpty ?? true)
        #expect(try await plans.loadActivePlan() == plan)
        let originalNotes = try IngredientAllocationService().allocate(plan: plan).reservations(after: meal)
        let moved = try #require(proposed.meals.first { $0.id == meal.id })
        let newNotes = try IngredientAllocationService().allocate(plan: proposed).reservations(after: moved)
        #expect(!originalNotes.isEmpty)
        #expect(newNotes.isEmpty)
        let accepted = try await changes.accept(preview, expectedRevision: plan.revision)
        #expect(accepted.meals == proposed.meals)
    }

    private func fixture(purchase: Bool = true) async throws -> (WeeklyPlan, PlanRepository, CookingService, PlanChangeService) {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let plans = PlanRepository(container: container)
        let catalog = try await CatalogService(allowDevelopment: true).loadCatalog()
        let date = Date(timeIntervalSince1970: 1794528000)
        let profile = PlanningProfile(budgetMinorUnits: 7000, adults: 2, children: 0,
                                      days: [date, date.addingTimeInterval(86400)], mealSlots: [.dinner], cookingTime: .thirty,
                                      skill: .beginner, storeID: "development-grocery", allergies: [], preferences: [])
        guard case .feasible(let original) = try await PlanService().generate(PlanRequest(profile: profile, catalog: catalog)) else { throw PlanningError.invalidPlan }
        try await plans.saveActivePlan(original)
        if purchase {
            let shopping = ShoppingService(plans: plans)
            let trip = try await shopping.openTrip(planID: original.id)
            for line in trip.lines { _ = try await shopping.setChecked(itemID: line.id, checked: true, tripID: trip.id) }
            _ = try await shopping.finishTrip(trip.id)
        }
        let plan = try #require(try await plans.loadActivePlan())
        let changes = PlanChangeService(plans: plans, planner: PlanService(), preferences: MealPreferenceRepository(container: container))
        return (plan, plans, CookingService(plans: plans, changes: changes), changes)
    }
}
