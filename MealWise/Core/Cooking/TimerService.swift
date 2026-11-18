import Foundation

protocol TimerServiceProtocol: Sendable {
    func start(mealID: UUID, planID: UUID, seconds: Int, expectedRecipeID: String?) async throws -> CookingTimer
    func cancel(mealID: UUID, planID: UUID, expectedRecipeID: String?) async throws
}

extension TimerServiceProtocol {
    func start(mealID: UUID, planID: UUID, seconds: Int) async throws -> CookingTimer {
        try await start(mealID: mealID, planID: planID, seconds: seconds, expectedRecipeID: nil)
    }
    func cancel(mealID: UUID, planID: UUID) async throws { try await cancel(mealID: mealID, planID: planID, expectedRecipeID: nil) }
}

actor TimerService: TimerServiceProtocol {
    private let plans: PlanRepository
    private let clock: @Sendable () -> Date
    init(plans: PlanRepository, clock: @escaping @Sendable () -> Date = { .now }) { self.plans = plans; self.clock = clock }
    func start(mealID: UUID, planID: UUID, seconds: Int, expectedRecipeID: String? = nil) async throws -> CookingTimer {
        guard (1...86400).contains(seconds) else { throw CookingError.invalidTimer }
        let timer = CookingTimer(deadline: clock().addingTimeInterval(TimeInterval(seconds)))
        _ = try await plans.editCookingProgress(mealID: mealID, planID: planID, expectedRecipeID: expectedRecipeID) { progress, _ in progress.timer = timer }
        return timer
    }
    func cancel(mealID: UUID, planID: UUID, expectedRecipeID: String? = nil) async throws {
        _ = try await plans.editCookingProgress(mealID: mealID, planID: planID, expectedRecipeID: expectedRecipeID) { progress, _ in progress.timer = nil }
    }
}
