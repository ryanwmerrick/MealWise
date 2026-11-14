import Foundation

enum ContentReview: String, Codable, Sendable { case draft, developmentApproved, launchReviewed }

struct NutritionFlags: Codable, Equatable, Sendable {
    let vegetable: Bool
    let protein: Bool
    let wholeGrain: Bool
}

struct RecipeRequirement: Codable, Equatable, Sendable {
    let ingredientID: String
    let quantity: Int64
    let unit: QuantityUnit
}

struct RecipeStep: Codable, Equatable, Sendable, Identifiable {
    let number: Int
    let instruction: String
    var id: Int { number }
}

struct Recipe: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let mealSlots: [MealSlot]
    let baseAdultPortions: Int
    let minutes: Int
    let skill: CookingSkill
    let reviewStatus: ContentReview
    let ingredients: [RecipeRequirement]
    let steps: [RecipeStep]
    let equipment: [String]
    let nutrition: NutritionFlags
    let dietaryPreferences: Set<DietPreference>
}

struct Ingredient: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let allergens: Set<Allergen>
    let allergensVerified: Bool
    let reviewStatus: ContentReview
    let nutrition: NutritionFlags
    let unit: QuantityUnit
    var category: IngredientCategory? = nil
    var storage: StorageKind? = nil

    func isSafe(excluding excluded: Set<Allergen>) -> Bool {
        excluded.isEmpty || (allergensVerified && allergens.isDisjoint(with: excluded))
    }
}
