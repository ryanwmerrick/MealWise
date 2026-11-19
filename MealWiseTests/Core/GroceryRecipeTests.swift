import Foundation
import Testing
import SwiftData
@testable import MealWise

struct GroceryRecipeTests {
    @MainActor
    @Test func preCategoryPlanSnapshotsStillRestore() async throws {
        let plan = try await plan()
        var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        var catalog = try #require(payload["catalog"] as? [String: Any])
        var ingredients = try #require(catalog["ingredients"] as? [[String: Any]])
        for index in ingredients.indices {
            ingredients[index].removeValue(forKey: "category")
            ingredients[index].removeValue(forKey: "storage")
        }
        catalog["ingredients"] = ingredients; payload["catalog"] = catalog
        let container = try await LocalStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(StoredDocument(key: "activePlan", payload: try JSONSerialization.data(withJSONObject: payload)))
        try context.save()
        let restored = try #require(try await PlanRepository(container: container).loadActivePlan())
        let groceries = GroceryViewModel(planID: restored.id, shopping: ShoppingService(container: container))
        await groceries.load()
        #expect(groceries.errorMessage == nil)
        #expect(groceries.sections(for: restored).first?.category == .other)
        #expect(restored.totalMinorUnits == plan.totalMinorUnits)
    }

    private func plan() async throws -> WeeklyPlan {
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: .fixture, catalog: catalog))
        guard case .feasible(let plan) = outcome else { throw PlanningError.invalidPlan }
        return plan
    }

    @Test func checklistRestoresAndRejectsUnknownItems() async throws {
        let plan = try await plan()
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = ChecklistRepository(container: container)
        let item = try #require(plan.cart.first)
        try await repository.toggle(itemID: item.id, plan: plan)
        #expect(try await ChecklistRepository(container: container).load(planID: plan.id) == [item.id])
        await #expect(throws: PlanningError.self) { try await repository.toggle(itemID: "not-in-cart", plan: plan) }
        #expect(try await repository.load(planID: plan.id) == [item.id])
    }

    @Test func recipeQuantitiesUseHouseholdPortions() async throws {
        let plan = try await plan()
        let meal = try #require(plan.meals.first)
        let detail = try PlanCostBreakdown.detail(plan: plan, mealID: meal.id)
        let recipe = try #require(plan.catalog.recipes.first { $0.id == meal.recipeID })
        #expect(detail.ingredients.count == recipe.ingredients.count)
        for requirement in recipe.ingredients {
            #expect(detail.ingredients.first { $0.id == requirement.ingredientID }?.amount == requirement.quantity * 2)
        }
        #expect(detail.steps == recipe.steps)
        #expect(detail.adultHalfPortions == 4)
    }

    @Test func everyCartPackageCostsMoneyUnderApprovedPolicy() async throws {
        let plan = try await plan()
        #expect(plan.cart.allSatisfy { $0.packageCount > 0 && $0.costMinorUnits > 0 })
        #expect(try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog)).totalMinorUnits == plan.totalMinorUnits)
    }

    @MainActor
    @Test func mealDetailUsesRequestedStableID() async throws {
        let plan = try await plan()
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = PlanRepository(container: container)
        try await repository.saveActivePlan(plan)
        let meal = try #require(plan.meals.first)
        let model = MealDetailViewModel(planID: plan.id, mealID: meal.id, plans: repository)
        await model.load()
        #expect(model.detail?.mealID == meal.id)
        let missing = MealDetailViewModel(planID: UUID(), mealID: meal.id, plans: repository)
        await missing.load()
        #expect(missing.detail == nil)
        #expect(missing.errorMessage != nil)
    }
}
