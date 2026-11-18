import Foundation

struct WeeklyNutritionSummary: Sendable {
    let meals: Int
    let vegetable: Int
    let protein: Int
    let wholeGrain: Int
    init(plan: WeeklyPlan) throws {
        let flags = try plan.meals.map { meal in
            guard let recipe = plan.cookedRecord(for: meal.id)?.recipe ?? plan.catalog.recipes.first(where: { $0.id == meal.recipeID }) else { throw PlanningError.invalidPlan }
            return recipe.nutrition
        }
        meals = flags.count
        vegetable = flags.filter(\.vegetable).count
        protein = flags.filter(\.protein).count
        wholeGrain = flags.filter(\.wholeGrain).count
    }
}
