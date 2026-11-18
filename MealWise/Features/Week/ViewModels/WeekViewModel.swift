import Combine
import Foundation

@MainActor
final class WeekViewModel: ObservableObject {
    let plan: WeeklyPlan
    var attentionCount: Int? {
        do { return try IngredientAllocationService().allocate(plan: plan).items.filter { $0.status == .needsAttention }.count }
        catch { return nil }
    }
    init(plan: WeeklyPlan) { self.plan = plan }

    var progress: Double { Double(plan.totalMinorUnits) / Double(plan.profile.budgetMinorUnits) }
    var perDay: String {
        (Decimal(plan.totalMinorUnits) / 100 / Decimal(plan.profile.days.count)).formatted(.currency(code: "USD"))
    }
    var checkoutPerAdultPortion: String {
        let halfPortions = plan.meals.reduce(0) { $0 + plan.portionProfile(for: $1.id).adultHalfPortions }
        return (Decimal(plan.totalMinorUnits) * 2 / 100 / Decimal(halfPortions)).formatted(.currency(code: "USD"))
    }

    func recipe(for meal: ScheduledMeal) -> Recipe? { plan.catalog.recipes.first { $0.id == meal.recipeID } }

    func sharedIngredientCount(for meal: ScheduledMeal) -> Int {
        guard let recipe = recipe(for: meal) else { return 0 }
        let otherIngredients = Set(plan.meals.filter { $0.id != meal.id }.flatMap { other in
            self.recipe(for: other)?.ingredients.map(\.ingredientID) ?? []
        })
        return recipe.ingredients.filter { otherIngredients.contains($0.ingredientID) }.count
    }

    func consumptionCost(for meal: ScheduledMeal, perServing: Bool = false) -> String {
        do {
            let detail = try PlanCostBreakdown.detail(plan: plan, mealID: meal.id)
            let servingScale = perServing ? Decimal(2) / Decimal(detail.adultHalfPortions) : 1
            return (detail.ingredientCost * servingScale).formatted(.currency(code: "USD"))
        } catch {
            return String(localized: "Unavailable")
        }
    }
}
