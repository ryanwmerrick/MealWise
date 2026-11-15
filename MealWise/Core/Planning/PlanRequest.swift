import Foundation

struct PlanRequest: Sendable {
    let profile: PlanningProfile
    let catalog: RecipeCatalog
    let excludedRecipeIDs: Set<String>
    let fixedMeals: [ScheduledMeal]
    let avoidMeals: [ScheduledMeal]

    init(profile: PlanningProfile, catalog: RecipeCatalog, excludedRecipeIDs: Set<String> = [],
         fixedMeals: [ScheduledMeal] = [], avoidMeals: [ScheduledMeal] = []) {
        self.profile = profile; self.catalog = catalog; self.excludedRecipeIDs = excludedRecipeIDs
        self.fixedMeals = fixedMeals; self.avoidMeals = avoidMeals
    }
}

struct ScheduledMeal: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let slot: MealSlot
    let recipeID: String
}

struct CartItem: Codable, Equatable, Sendable, Identifiable {
    let ingredientID: String
    let offerID: String
    let requiredQuantity: Int64
    let packageCount: Int64
    let costMinorUnits: Int64
    var id: String { ingredientID }
}

struct WeeklyPlan: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let revision: UUID
    let profile: PlanningProfile
    let catalog: RecipeCatalog
    let meals: [ScheduledMeal]
    let cart: [CartItem]
    let totalMinorUnits: Int64

    var remainingMinorUnits: Int64 { profile.budgetMinorUnits - totalMinorUnits }
}

enum PlanOutcome: Sendable {
    case feasible(WeeklyPlan)
    case invalidInputs
    case noFeasiblePlan
    case searchLimit
}

enum PlanningError: Error { case invalidPlan, missingIngredient, overflow }

protocol PlanServiceProtocol: Sendable {
    func generate(_ request: PlanRequest) async throws -> PlanOutcome
}
