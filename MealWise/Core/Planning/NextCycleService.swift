import Foundation

protocol NextCycleServiceProtocol: Sendable {
    func accept(_ plan: WeeklyPlan, expectedPreviousRevision: UUID) async throws
}

actor NextCycleService: NextCycleServiceProtocol {
    private let plans: PlanRepository
    private let clock: @Sendable () -> Date
    init(plans: PlanRepository, clock: @escaping @Sendable () -> Date = { .now }) { self.plans = plans; self.clock = clock }
    func accept(_ plan: WeeklyPlan, expectedPreviousRevision: UUID) async throws {
        try await plans.startNextCycle(plan, expectedPreviousRevision: expectedPreviousRevision, now: clock())
    }
}
