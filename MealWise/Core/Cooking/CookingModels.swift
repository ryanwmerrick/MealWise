import Foundation

struct CookedMealRecord: Codable, Equatable, Sendable, Identifiable {
    let meal: ScheduledMeal
    let profile: PlanningProfile
    let recipe: Recipe
    let completedAt: Date
    var stockDebits: [StockDebit]? = nil
    var id: UUID { meal.id }
}

struct CookingTimer: Codable, Equatable, Sendable {
    let deadline: Date
    func remaining(at now: Date) -> Int { max(0, Int(ceil(deadline.timeIntervalSince(now)))) }
}

struct CookingProgress: Codable, Equatable, Sendable {
    let mealID: UUID
    let recipeID: String
    var completedSteps: Set<Int> = []
    var timer: CookingTimer?
}

enum CookingError: Error { case alreadyCooked, insufficientStock, staleMeal, invalidStep, invalidTimer }

enum TodaySchedule {
    static func meals(_ meals: [ScheduledMeal], on date: Date, calendar: Calendar) -> [ScheduledMeal] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.slot.order < $1.slot.order }
    }
}

extension WeeklyPlan {
    func cookedRecord(for mealID: UUID) -> CookedMealRecord? { resources?.cookedMeals?.first { $0.id == mealID } }
    func portionProfile(for mealID: UUID) -> PlanningProfile { cookedRecord(for: mealID)?.profile ?? profile }
}
