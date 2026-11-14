import Combine
import Foundation

@MainActor
final class WeekViewModel: ObservableObject {
    let plan: WeeklyPlan
    init(plan: WeeklyPlan) { self.plan = plan }

    var progress: Double { Double(plan.totalMinorUnits) / Double(plan.profile.budgetMinorUnits) }
    var perDay: String {
        (Decimal(plan.totalMinorUnits) / 100 / Decimal(plan.profile.days.count)).formatted(.currency(code: "USD"))
    }
    var checkoutPerAdultPortion: String {
        (Decimal(plan.totalMinorUnits) * 2 / 100 / Decimal(plan.profile.adultHalfPortions) / Decimal(plan.meals.count))
            .formatted(.currency(code: "USD"))
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
        guard let recipe = recipe(for: meal) else { return "" }
        let amount = recipe.ingredients.reduce(Decimal(0)) { sum, requirement in
            guard let cartItem = plan.cart.first(where: { $0.ingredientID == requirement.ingredientID }),
                  let offer = plan.catalog.offers.first(where: { $0.id == cartItem.offerID }),
                  offer.packageQuantity > 0 else { return sum }
            let scaled = Decimal(requirement.quantity) * Decimal(plan.profile.adultHalfPortions) / Decimal(recipe.baseAdultPortions * 2)
            return sum + scaled * Decimal(offer.priceMinorUnits) / Decimal(offer.packageQuantity)
        }
        let servingScale = perServing ? Decimal(2) / Decimal(plan.profile.adultHalfPortions) : 1
        return (amount * servingScale / 100).formatted(.currency(code: "USD"))
    }
}
