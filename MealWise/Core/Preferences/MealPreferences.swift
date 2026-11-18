import Foundation

enum MealRating: String, Codable, Sendable { case liked, disliked }

struct RecipePreference: Codable, Equatable, Sendable, Identifiable {
    let recipeID: String
    var rating: MealRating?
    var favorite: Bool
    var excluded: Bool
    var id: String { recipeID }
    var score: Int { (rating == .disliked ? -1 : 0) + (favorite || rating == .liked ? 1 : 0) }
}

struct RecipePin: Codable, Equatable, Sendable, Identifiable {
    let recipeID: String
    let date: Date
    let slot: MealSlot
    var id: String { "\(date.timeIntervalSince1970)-\(slot.rawValue)" }
}

struct MealRatingRecord: Codable, Equatable, Sendable {
    let mealID: UUID
    let recipeID: String
    let rating: MealRating
}
