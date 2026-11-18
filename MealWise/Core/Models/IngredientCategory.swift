import Foundation

enum IngredientCategory: String, Codable, Sendable, CaseIterable {
    case produce, frozen, meatAndDairy, pantry, other

    var title: String {
        switch self {
        case .produce: "Produce"
        case .frozen: "Frozen"
        case .meatAndDairy: "Meat & dairy"
        case .pantry: "Pantry"
        case .other: "Other"
        }
    }
}
