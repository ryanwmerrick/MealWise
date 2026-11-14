import Combine
import Foundation

@MainActor
final class IngredientViewModel: ObservableObject {
    @Published private(set) var report: IngredientAllocationReport?
    @Published private(set) var plan: WeeklyPlan?
    @Published private(set) var errorMessage: String?
    private let planID: UUID
    private let plans: any PlanRepositoryProtocol
    private let allocator: any IngredientAllocationServiceProtocol

    init(planID: UUID, plans: any PlanRepositoryProtocol, allocator: any IngredientAllocationServiceProtocol = IngredientAllocationService()) {
        self.planID = planID; self.plans = plans; self.allocator = allocator
    }

    func load() async {
        do {
            guard let plan = try await plans.loadActivePlan(), plan.id == planID else { throw PlanningError.invalidPlan }
            let report = try allocator.allocate(plan: plan)
            try Task.checkCancellation()
            self.plan = plan; self.report = report; errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Ingredient usage could not be loaded. Return to your week or retry." }
    }
}
