import Foundation

struct CartRequest: Sendable {
    let meals: [ScheduledMeal]
    let profile: PlanningProfile
    let catalog: RecipeCatalog
    var resources: PlanResources? = nil
    var offerOverrides: [String: String]? = nil
    var pricedAt: Date = .distantPast
}

struct PricedCart: Sendable {
    let items: [CartItem]
    let totalMinorUnits: Int64
}

extension CartCalculator {
    static func calculate(_ request: CartRequest) throws -> PricedCart {
        let items = try calculate(meals: request.meals, profile: request.profile, catalog: request.catalog, resources: request.resources, offerOverrides: request.offerOverrides, at: request.pricedAt)
        return try PricedCart(items: items, totalMinorUnits: checkedSum(total(items), request.resources?.committedMinorUnits ?? 0))
    }
}

struct MealIngredient: Sendable, Identifiable {
    let id: String
    let name: String
    let amount: Int64
    let unit: QuantityUnit
}

struct MealDetail: Sendable {
    let mealID: UUID
    let recipeID: String
    let title: String
    let minutes: Int
    let skill: CookingSkill
    let adultHalfPortions: Int
    let ingredients: [MealIngredient]
    let steps: [RecipeStep]
    let nutrition: NutritionFlags
    let ingredientCost: Decimal
    let linkedMeals: [ScheduledMeal]
}

enum PlanCostBreakdown {
    static func detail(plan: WeeklyPlan, mealID: UUID) throws -> MealDetail {
        guard let meal = plan.meals.first(where: { $0.id == mealID }),
              let recipe = plan.catalog.recipes.first(where: { $0.id == meal.recipeID }) else { throw PlanningError.invalidPlan }
        var cost = Decimal(0)
        let ingredients = try recipe.ingredients.map { requirement in
            guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == requirement.ingredientID }),
                  let cart = plan.cart.first(where: { $0.ingredientID == ingredient.id }),
                  let offer = plan.catalog.offers.first(where: { $0.id == cart.offerID }) else { throw PlanningError.missingIngredient }
            let amount = try CartCalculator.scaledAmount(requirement, recipe: recipe, profile: plan.portionProfile(for: mealID))
            cost += Decimal(amount) * Decimal(offer.priceMinorUnits) / Decimal(offer.packageQuantity) / 100
            return MealIngredient(id: ingredient.id, name: ingredient.name, amount: amount, unit: ingredient.unit)
        }
        let ingredientIDs = Set(ingredients.map(\.id))
        let linked = plan.meals.filter { other in
            other.id != mealID && plan.catalog.recipes.first(where: { $0.id == other.recipeID })?.ingredients.contains(where: { ingredientIDs.contains($0.ingredientID) }) == true
        }
        return MealDetail(mealID: meal.id, recipeID: recipe.id, title: recipe.title, minutes: recipe.minutes, skill: recipe.skill,
                          adultHalfPortions: plan.portionProfile(for: mealID).adultHalfPortions, ingredients: ingredients,
                          steps: recipe.steps, nutrition: recipe.nutrition, ingredientCost: cost, linkedMeals: linked)
    }
}
