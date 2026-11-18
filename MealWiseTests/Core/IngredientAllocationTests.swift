import Foundation
import Testing
@testable import MealWise

struct IngredientAllocationTests {
    @Test func sameDayReservationsFollowMealSlots() throws {
        let date = Date(timeIntervalSince1970: 1794528000)
        let breakfast = ScheduledMeal(id: UUID(), date: date, slot: .breakfast, recipeID: "breakfast")
        let lunch = ScheduledMeal(id: UUID(), date: date, slot: .lunch, recipeID: "lunch")
        let dinner = ScheduledMeal(id: UUID(), date: date, slot: .dinner, recipeID: "dinner")
        let item = IngredientAllocation(id: "rice", name: "Rice", unit: .milligrams, purchasedQuantity: 1000,
                                        remainingQuantity: 400, packageCount: 1, priceMinorUnits: 100,
                                        allocations: [MealAllocation(mealID: breakfast.id, date: date, slot: .breakfast, recipeTitle: "Breakfast", quantity: 100),
                                                      MealAllocation(mealID: lunch.id, date: date, slot: .lunch, recipeTitle: "Lunch", quantity: 200),
                                                      MealAllocation(mealID: dinner.id, date: date, slot: .dinner, recipeTitle: "Dinner", quantity: 300)],
                                        status: .carryOver, storage: .shelfStable)
        let report = IngredientAllocationReport(items: [item])
        #expect(report.reservations(after: breakfast).first?.quantity == 500)
        #expect(report.reservations(after: lunch).first?.quantity == 300)
        #expect(report.reservations(after: dinner).isEmpty)
    }

    private func plan(days: Int = 1, recipeID: String? = nil) async throws -> WeeklyPlan {
        var profile = PlanningProfile.fixture
        profile.days = (0..<days).map { profile.days[0].addingTimeInterval(Double($0) * 86400) }
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let fixed = recipeID.map { [ScheduledMeal(id: UUID(), date: profile.days[0], slot: .dinner, recipeID: $0)] } ?? []
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: catalog, fixedMeals: fixed))
        guard case .feasible(let plan) = outcome else { throw PlanningError.invalidPlan }
        return plan
    }

    @Test func purchasedEqualsAllocatedPlusRemaining() async throws {
        let plan = try await plan(days: 3)
        let report = try IngredientAllocationService().allocate(plan: plan)
        #expect(report.items.count == plan.cart.count)
        for item in report.items {
            #expect(item.purchasedQuantity == item.allocations.reduce(0) { $0 + $1.quantity } + item.remainingQuantity)
            #expect(item.remainingQuantity >= 0)
        }
    }

    @Test func multiPackageBeansAndStaplesRemainHonest() async throws {
        let report = try await IngredientAllocationService().allocate(plan: plan(recipeID: "spinach-bean-pasta"))
        let beans = try #require(report.items.first { $0.id == "white-beans" })
        #expect(beans.purchasedQuantity == 480000)
        #expect(beans.remainingQuantity == 180000)
        #expect(beans.status == .needsAttention)
        let pasta = try #require(report.items.first { $0.id == "whole-wheat-pasta" })
        #expect(pasta.remainingQuantity == 290000)
        #expect(pasta.status == .carryOver)
    }

    @Test func allocationChronologyDoesNotDependOnArrayOrder() async throws {
        let plan = try await plan(days: 3)
        let reordered = WeeklyPlan(id: plan.id, revision: plan.revision, profile: plan.profile, catalog: plan.catalog,
                                  meals: plan.meals.reversed(), cart: plan.cart, totalMinorUnits: plan.totalMinorUnits)
        let report = try IngredientAllocationService().allocate(plan: reordered)
        for item in report.items { #expect(item.allocations.map(\.date) == item.allocations.map(\.date).sorted()) }
    }

    @Test func saveNotesReserveOnlyLaterMeals() async throws {
        let plan = try await plan(days: 3)
        let report = try IngredientAllocationService().allocate(plan: plan)
        let first = try #require(plan.meals.first)
        let last = try #require(plan.meals.last)
        #expect(!report.reservations(after: first).isEmpty)
        #expect(report.reservations(after: last).isEmpty)
    }
}
