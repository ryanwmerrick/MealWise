import Foundation

enum PlanningGoal: String, Codable, CaseIterable, Sendable {
    case saveMoney, eatHealthier, findRecipes, saveTime, wasteLess
}

enum CookingStyle: String, Codable, CaseIterable, Sendable {
    case quickAndEasy, onePan, familyFavorites, classics
}

enum KitchenEquipment: String, Codable, CaseIterable, Sendable {
    case stove, saucepan, skillet, knife, cuttingBoard = "cutting board"
    case oven, microwave, airFryer = "air fryer", slowCooker = "slow cooker", blender

    static let assumedTools: Set<Self> = [.saucepan, .skillet, .knife, .cuttingBoard]
    static let basics: Set<Self> = assumedTools.union([.stove])
    static var appliances: [Self] { allCases.filter { !assumedTools.contains($0) } }
}

enum GroceryPreference: String, Codable, CaseIterable, Sendable {
    case aldi, walmart, target, costco, kroger, traderJoes, wholeFoods, publix, lidl, other
}

enum AdditionalDietPreference: String, Codable, CaseIterable, Sendable {
    case pescatarian, mediterranean, paleo, halal, kosher
    case lowCarb = "Low carb"
    case dairyFree = "Dairy free"
    case highProtein = "High protein"
}

enum DetailedFoodAllergy: String, Codable, CaseIterable, Sendable {
    case almond, brazilNut = "Brazil nut", cashew, hazelnut, macadamia, pecan, pistachio, walnut
    case clam, crab, lobster, mussel, oyster, scallop, shrimp, squid
    case cod, halibut, salmon, tilapia, trout, tuna

    var group: Allergen {
        switch self {
        case .almond, .brazilNut, .cashew, .hazelnut, .macadamia, .pecan, .pistachio, .walnut: .treeNut
        case .clam, .crab, .lobster, .mussel, .oyster, .scallop, .shrimp, .squid: .shellfish
        case .cod, .halibut, .salmon, .tilapia, .trout, .tuna: .fish
        }
    }
}

struct OnboardingPreferences: Codable, Equatable, Sendable {
    var goals: Set<PlanningGoal> = []
    var equipment: Set<KitchenEquipment> = KitchenEquipment.basics
    var styles: Set<CookingStyle> = []
    var stores: Set<GroceryPreference> = []
    var keto = false
    var additionalDiets: Set<AdditionalDietPreference>? = nil
    var detailedAllergies: Set<DetailedFoodAllergy>? = nil
    var wholeAllergyGroups: Set<Allergen>? = nil

    func score(_ recipe: Recipe) -> Int {
        var score = 0
        if goals.contains(.eatHealthier) {
            score += [recipe.nutrition.vegetable, recipe.nutrition.protein, recipe.nutrition.wholeGrain].filter { $0 }.count
        }
        if (goals.contains(.saveTime) || styles.contains(.quickAndEasy)) && recipe.minutes <= 15 { score += 1 }
        if let matches = recipe.cookingStyles {
            score += styles.intersection(matches).count
        }
        return score
    }
}
