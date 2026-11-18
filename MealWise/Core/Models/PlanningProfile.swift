import Foundation

enum ProfileError: Error { case invalidBudget, invalidHousehold, invalidSchedule, unsupportedStore }
enum MealSlot: String, Codable, CaseIterable, Sendable { case breakfast, lunch, dinner }
enum CookingTime: Int, Codable, CaseIterable, Sendable { case fifteen = 15, thirty = 30, fortyFive = 45, flexible = 1440 }
enum CookingSkill: String, Codable, CaseIterable, Sendable { case beginner, comfortable, experienced }
enum Allergen: String, Codable, CaseIterable, Sendable { case milk, egg, fish, shellfish, treeNut, peanut, wheat, soy, sesame }
enum DietPreference: String, Codable, CaseIterable, Sendable { case vegetarian, vegan, glutenFree }

struct PlanningProfile: Codable, Equatable, Sendable {
    var budgetMinorUnits: Int64
    var adults: Int
    var children: Int
    var days: [Date]
    var mealSlots: Set<MealSlot>
    var cookingTime: CookingTime
    var skill: CookingSkill
    var storeID: String
    var allergies: Set<Allergen>
    var preferences: Set<DietPreference>

    var onboarding: OnboardingPreferences? = nil

    var adultHalfPortions: Int { adults * 2 + children }

    func validate(calendar: Calendar = .current) throws {
        guard budgetMinorUnits > 0 else { throw ProfileError.invalidBudget }
        guard adults > 0, adults <= 12, children >= 0, children <= 11, adults + children <= 12 else {
            throw ProfileError.invalidHousehold
        }
        guard (1...7).contains(days.count), !mealSlots.isEmpty else { throw ProfileError.invalidSchedule }
        let normalized = days.map { calendar.startOfDay(for: $0) }.sorted()
        guard Set(normalized).count == normalized.count,
              let first = normalized.first, let last = normalized.last,
              let span = calendar.dateComponents([.day], from: first, to: last).day,
              span < 7 else { throw ProfileError.invalidSchedule }
        guard storeID == "development-grocery" else { throw ProfileError.unsupportedStore }
    }
}
