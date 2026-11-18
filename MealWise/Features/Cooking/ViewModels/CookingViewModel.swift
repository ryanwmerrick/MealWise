import Combine
import Foundation

@MainActor
final class CookingViewModel: ObservableObject {
    @Published private(set) var plan: WeeklyPlan?
    @Published private(set) var detail: MealDetail?
    @Published private(set) var progress: CookingProgress?
    @Published private(set) var notes: [ReservationNote] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var hasStock = false
    let planID: UUID
    let mealID: UUID
    private let services: AppServices
    init(planID: UUID, mealID: UUID, services: AppServices) { self.planID = planID; self.mealID = mealID; self.services = services }
    var isCooked: Bool { plan?.cookedRecord(for: mealID) != nil }
    func load() async {
        isWorking = true; defer { isWorking = false }
        do {
            guard let plan = try await services.plans.loadActivePlan(), plan.id == planID,
                  let meal = plan.meals.first(where: { $0.id == mealID }) else { throw CookingError.staleMeal }
            let detail = try PlanCostBreakdown.detail(plan: plan, mealID: mealID)
            let progress = try await services.cooking.loadProgress(mealID: mealID, planID: planID)
            let notes = try IngredientAllocationService().allocate(plan: plan).reservations(after: meal)
            let hasStock: Bool
            do {
                if plan.cookedRecord(for: mealID) == nil, let recipe = plan.catalog.recipes.first(where: { $0.id == meal.recipeID }) {
                    _ = try StockAccounting.allocateConsumption(recipe: recipe, profile: plan.profile, resources: plan.resources ?? PlanResources(), at: .now)
                }
                hasStock = plan.closedAt == nil
            } catch CookingError.insufficientStock { hasStock = false }
            try Task.checkCancellation()
            self.plan = plan; self.detail = detail; self.progress = progress; self.notes = notes; self.hasStock = hasStock; errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "This cooking session could not be opened. Return to your current plan and retry." }
    }
    func toggleStep(_ number: Int) async {
        guard let progress, !isWorking, !isCooked else { return }
        isWorking = true; defer { isWorking = false }
        do {
            self.progress = try await services.cooking.setStep(number: number, complete: !progress.completedSteps.contains(number),
                                                              mealID: mealID, planID: planID, recipeID: progress.recipeID)
            errorMessage = nil
        } catch { errorMessage = "Your step could not be saved. Close and reopen the current meal before continuing." }
    }
    func startTimer(minutes: Int) async {
        guard !isWorking, !isCooked else { return }
        isWorking = true; defer { isWorking = false }
        do {
            _ = try await services.timers.start(mealID: mealID, planID: planID, seconds: minutes * 60, expectedRecipeID: progress?.recipeID)
            progress = try await services.cooking.loadProgress(mealID: mealID, planID: planID); errorMessage = nil
        } catch { errorMessage = "The timer could not be saved. Reopen this meal and retry." }
    }
    func cancelTimer() async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try await services.timers.cancel(mealID: mealID, planID: planID, expectedRecipeID: progress?.recipeID)
            progress = try await services.cooking.loadProgress(mealID: mealID, planID: planID); errorMessage = nil
        } catch { errorMessage = "The timer change could not be saved. Reopen this meal and retry." }
    }
    func complete() async -> Bool {
        guard let plan, hasStock, !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        do { try await services.cooking.markCooked(mealID: mealID, planID: planID, expectedRevision: plan.revision); return true }
        catch CookingError.insufficientStock { errorMessage = "There are not enough recorded purchased ingredients. Record your shopping purchases first."; return false }
        catch { errorMessage = "This meal changed or completion could not be saved. Reopen it from your current plan before confirming."; return false }
    }
}
