import Combine
import Foundation

@MainActor
final class MealDetailViewModel: ObservableObject {
    @Published private(set) var detail: MealDetail?
    @Published private(set) var plan: WeeklyPlan?
    @Published private(set) var errorMessage: String?
    @Published private(set) var reservations: [ReservationNote] = []
    private let planID: UUID
    private let mealID: UUID
    private let plans: any PlanRepositoryProtocol

    init(planID: UUID, mealID: UUID, plans: any PlanRepositoryProtocol) {
        self.planID = planID; self.mealID = mealID; self.plans = plans
    }

    func load() async {
        errorMessage = nil
        detail = nil
        plan = nil
        do {
            guard let plan = try await plans.loadActivePlan(), plan.id == planID else { throw PlanningError.invalidPlan }
            let detail = try PlanCostBreakdown.detail(plan: plan, mealID: mealID)
            guard let meal = plan.meals.first(where: { $0.id == mealID }) else { throw PlanningError.invalidPlan }
            let reservations = try IngredientAllocationService().allocate(plan: plan).reservations(after: meal)
            try Task.checkCancellation()
            self.plan = plan; self.detail = detail; self.reservations = reservations
        } catch is CancellationError { return }
        catch { errorMessage = "This meal could not be opened. Return to your current week or retry." }
    }
}
