import Foundation

extension Int64 {
    var currency: String { (Decimal(self) / 100).formatted(.currency(code: "USD")) }
}

extension Quantity {
    var display: String {
        QuantityFormatting.display(amount: canonicalAmount, unit: unit)
    }
}

enum QuantityFormatting {
    static func display(amount: Int64, unit: QuantityUnit) -> String {
        switch unit {
        case .milligrams: String(localized: "\((Decimal(amount) / 1000).formatted(.number)) g")
        case .milliliters: String(localized: "\(amount.formatted()) mL")
        case .count: String(localized: "\(amount.formatted()) items")
        default: amount.formatted()
        }
    }
}

extension MealSlot {
    var title: String {
        switch self { case .breakfast: "Breakfast"; case .lunch: "Lunch"; case .dinner: "Dinner" }
    }
}

extension CookingTime {
    var title: String {
        switch self { case .fifteen: "15 minutes or less"; case .thirty: "About 30 minutes"; case .fortyFive: "Up to 45 minutes"; case .flexible: "Flexible" }
    }
}

extension CookingSkill {
    var title: String {
        switch self { case .beginner: "Beginner"; case .comfortable: "Comfortable"; case .experienced: "Experienced" }
    }
}

extension Allergen {
    var title: String {
        switch self {
        case .milk: "Milk"; case .egg: "Eggs"; case .fish: "Fish"; case .shellfish: "Shellfish"
        case .treeNut: "Tree nuts"; case .peanut: "Peanuts"; case .wheat: "Wheat"; case .soy: "Soy"; case .sesame: "Sesame"
        }
    }
}

extension DietPreference {
    var title: String {
        switch self { case .vegetarian: "Vegetarian"; case .vegan: "Vegan"; case .glutenFree: "Gluten-free" }
    }
}
