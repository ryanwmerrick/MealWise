import Foundation

enum PlanRoute: Hashable {
    case meal(planID: UUID, mealID: UUID)
    case ingredientMap(planID: UUID)
    case ingredientDetail(planID: UUID, ingredientID: String)
    case remainderSuggestions(planID: UUID, ingredientID: String)
}
