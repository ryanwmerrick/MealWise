import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    let plan: WeeklyPlan
    private let calendar: Calendar
    private let clock: @Sendable () -> Date
    init(plan: WeeklyPlan, calendar: Calendar = .autoupdatingCurrent, clock: @escaping @Sendable () -> Date = { .now }) {
        self.plan = plan; self.calendar = calendar; self.clock = clock
    }
    func meals(on date: Date? = nil) -> [ScheduledMeal] { TodaySchedule.meals(plan.meals, on: date ?? clock(), calendar: calendar) }
    func recipe(for meal: ScheduledMeal) -> Recipe? { plan.catalog.recipes.first { $0.id == meal.recipeID } }
    func estimatedCost(for meal: ScheduledMeal) -> String? {
        guard let detail = try? PlanCostBreakdown.detail(plan: plan, mealID: meal.id) else { return nil }
        return detail.ingredientCost.formatted(.currency(code: "USD"))
    }
    func isCooked(_ meal: ScheduledMeal) -> Bool { plan.cookedRecord(for: meal.id) != nil }
    func moveTargets(for meal: ScheduledMeal) -> [ScheduledMeal] {
        plan.meals.filter { $0.id != meal.id && $0.slot == meal.slot && !isCooked($0) }.sorted { $0.date < $1.date }
    }
}
